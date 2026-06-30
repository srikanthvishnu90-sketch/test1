// ============================================================================
// stripe-webhook  (Supabase Edge Function) — Phase B #1b
// ============================================================================
// The server-side confirmation that closes the payment loop. Stripe POSTs events
// here; we verify the signature, then update the booking:
//   • checkout.session.completed (paid)  -> payment_status='paid', status='confirmed'
//   • charge.refunded                    -> payment_status='refunded'
//   • checkout.session.expired           -> (no change; booking stays unpaid)
//
// The booking is matched by booking_id carried in metadata / client_reference_id
// (set by stripe-create-checkout, #1a). Writes use the service-role client and
// are idempotent (the WHERE clause guards re-delivery).
//
// CRITICAL deploy settings:
//   • verify_jwt = false  — Stripe cannot send a Supabase JWT; auth IS the
//     signature check below. Deploy with `--no-verify-jwt`.
//   • STRIPE_WEBHOOK_SECRET must be the signing secret of THIS endpoint
//     (Stripe Dashboard → Developers → Webhooks → your endpoint → Signing secret).
// ============================================================================

import Stripe from "npm:stripe@14.21.0";
import { createClient } from "npm:@supabase/supabase-js@2";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2024-06-20",
  httpClient: Stripe.createFetchHttpClient(),
});
const cryptoProvider = Stripe.createSubtleCryptoProvider();

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;

const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
  auth: { persistSession: false, autoRefreshToken: false },
});

// Resolve the booking id from a Checkout Session (metadata first, then the
// client_reference_id fallback set at creation).
function bookingIdFromSession(s: Stripe.Checkout.Session): string | null {
  return (s.metadata?.booking_id as string | undefined) ??
    (s.client_reference_id ?? null);
}

async function markPaid(bookingId: string) {
  // Idempotent: only flips an unpaid booking, so re-delivery is a no-op.
  const { error } = await admin
    .from("bookings")
    .update({ payment_status: "paid", status: "confirmed" })
    .eq("id", bookingId)
    .neq("payment_status", "paid");
  if (error) console.error("markPaid failed", bookingId, error.message);
}

async function markRefunded(bookingId: string) {
  const { error } = await admin
    .from("bookings")
    .update({ payment_status: "refunded" })
    .eq("id", bookingId);
  if (error) console.error("markRefunded failed", bookingId, error.message);
}

Deno.serve(async (req) => {
  const sig = req.headers.get("stripe-signature");
  if (!sig) return new Response("Missing stripe-signature", { status: 400 });

  // Raw body is REQUIRED for signature verification — never parse before this.
  const payload = await req.text();

  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(
      payload,
      sig,
      WEBHOOK_SECRET,
      undefined,
      cryptoProvider,
    );
  } catch (e) {
    console.error("Signature verification failed:", (e as Error).message);
    return new Response("Invalid signature", { status: 400 });
  }

  try {
    switch (event.type) {
      case "checkout.session.completed": {
        const s = event.data.object as Stripe.Checkout.Session;
        // Only confirm a genuinely-paid session.
        if (s.payment_status === "paid" || s.status === "complete") {
          const id = bookingIdFromSession(s);
          if (id) await markPaid(id);
        }
        break;
      }
      case "checkout.session.async_payment_succeeded": {
        const s = event.data.object as Stripe.Checkout.Session;
        const id = bookingIdFromSession(s);
        if (id) await markPaid(id);
        break;
      }
      case "charge.refunded": {
        const charge = event.data.object as Stripe.Charge;
        // Booking id rides on the PaymentIntent metadata set at checkout.
        let id = (charge.metadata?.booking_id as string | undefined) ?? null;
        if (!id && charge.payment_intent) {
          const pi = await stripe.paymentIntents.retrieve(
            typeof charge.payment_intent === "string"
              ? charge.payment_intent
              : charge.payment_intent.id,
          );
          id = (pi.metadata?.booking_id as string | undefined) ?? null;
        }
        if (id) await markRefunded(id);
        break;
      }
      default:
        // Unhandled events are acknowledged so Stripe stops retrying.
        break;
    }
  } catch (e) {
    console.error("webhook handler error:", (e as Error).message);
    // 500 lets Stripe retry a transient DB failure.
    return new Response("handler error", { status: 500 });
  }

  return new Response(JSON.stringify({ received: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
