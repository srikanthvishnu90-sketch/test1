// ============================================================================
// stripe-create-checkout  (Supabase Edge Function) — Phase B #1a
// ============================================================================
// Creates a Stripe Checkout Session for an UNPAID booking and returns its URL.
// This is the payment moment the booking flow ("Confirm & Pay") invokes.
//
// Marketplace model: DESTINATION CHARGE on Connect. The platform is merchant of
// record; the session transfers the net to the provider's connected account and
// keeps an application fee (PLATFORM_FEE_BPS, default 10%). The booking is the
// source of truth for the amount — never trust a client-sent price.
//
// Flow:
//   1. Authenticate the caller (JWT) and load THEIR booking (service role).
//   2. Guard: caller owns it, it's still unpaid, and the booking's provider has
//      an onboarded Connect account that can accept charges.
//   3. Create the Checkout Session (amount from booking.final_price), tagging it
//      with booking_id in metadata + client_reference_id so the webhook (#1b)
//      can flip payment_status -> 'paid' regardless of which event arrives.
//   4. Persist stripe_checkout_session_id on the booking and return the URL.
//
// verify_jwt: ON (the parent's session authorizes the charge).
// ============================================================================

import Stripe from "npm:stripe@14.21.0";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2024-06-20",
  httpClient: Stripe.createFetchHttpClient(),
});

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
// Platform fee in basis points (1000 = 10%). Configurable per environment.
const PLATFORM_FEE_BPS = Number(Deno.env.get("PLATFORM_FEE_BPS") ?? 1000);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    // ── 1. Authenticate the caller ──────────────────────────────────────────
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader) return json({ error: "Missing Authorization header" }, 401);

    const userClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData?.user) {
      return json({ error: "Not authenticated" }, 401);
    }
    const uid = userData.user.id;

    const body = await req.json().catch(() => ({}));
    const bookingId: string | null =
      typeof body?.bookingId === "string" ? body.bookingId : null;
    if (!bookingId) return json({ error: "bookingId is required" }, 400);
    const successUrl: string =
      (body?.successUrl as string) ?? new URL(req.url).origin;
    const cancelUrl: string =
      (body?.cancelUrl as string) ?? new URL(req.url).origin;

    // ── 2. Load the booking + its provider (service role) and guard ─────────
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: booking, error: bErr } = await admin
      .from("bookings")
      .select(
        "id, searcher_id, final_price, currency, payment_status, selected_tier, " +
          "programs(title, provider_id, providers(stripe_account_id, stripe_charges_enabled))",
      )
      .eq("id", bookingId)
      .maybeSingle();
    if (bErr) return json({ error: bErr.message }, 400);
    if (!booking) return json({ error: "Booking not found" }, 404);

    // Ownership: only the parent who created the booking may pay for it.
    if (booking.searcher_id !== uid) {
      return json({ error: "Not your booking" }, 403);
    }
    // Idempotency: never create a second session for an already-paid booking.
    if (booking.payment_status === "paid") {
      return json({ error: "This booking is already paid." }, 409);
    }

    const program = (booking as Record<string, unknown>).programs as
      | Record<string, unknown>
      | null;
    const provider = (program?.providers ?? null) as
      | { stripe_account_id?: string | null; stripe_charges_enabled?: boolean }
      | null;
    const destination = provider?.stripe_account_id ?? null;
    if (!destination || provider?.stripe_charges_enabled !== true) {
      return json(
        { error: "This coach can't accept payments yet. Please try later." },
        409,
      );
    }

    const amount = Math.round(Number(booking.final_price) * 100);
    if (!Number.isFinite(amount) || amount <= 0) {
      return json({ error: "This booking has no payable amount." }, 400);
    }
    const currency = String(booking.currency ?? "USD").toLowerCase();
    const feeAmount = Math.round((amount * PLATFORM_FEE_BPS) / 10000);
    const title =
      (program?.title as string | undefined)?.trim() || "Sporve session";
    const tier = (booking.selected_tier as string | null) ?? null;

    // ── 3. Create the Checkout Session (destination charge) ─────────────────
    const session = await stripe.checkout.sessions.create({
      mode: "payment",
      success_url: successUrl,
      cancel_url: cancelUrl,
      client_reference_id: bookingId,
      metadata: { booking_id: bookingId },
      line_items: [
        {
          quantity: 1,
          price_data: {
            currency,
            unit_amount: amount,
            product_data: { name: tier ? `${title} — ${tier}` : title },
          },
        },
      ],
      payment_intent_data: {
        application_fee_amount: feeAmount,
        transfer_data: { destination },
        metadata: { booking_id: bookingId },
      },
    });

    // ── 4. Persist the session id; the webhook reads it back to confirm ─────
    const { error: upErr } = await admin
      .from("bookings")
      .update({ stripe_checkout_session_id: session.id })
      .eq("id", bookingId);
    if (upErr) return json({ error: upErr.message }, 400);

    return json({ checkoutUrl: session.url, sessionId: session.id });
  } catch (e) {
    console.error("stripe-create-checkout error:", e);
    return json({ error: (e as Error).message ?? "Unexpected error" }, 500);
  }
});
