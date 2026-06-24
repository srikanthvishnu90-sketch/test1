// ============================================================================
// stripe-connect-onboarding  (Supabase Edge Function)
// ============================================================================
// REVIEW COPY — paste into the Supabase dashboard after review; deploying is
// manual. Fixes the payout write-back bug: previously stripe_account_id was only
// written on first creation (or not at all) and stripe_charges_enabled was never
// refreshed on the return trip, so the providers row stayed NULL/false.
//
// This version, on EVERY invoke:
//   1. Authenticates the caller (JWT) and finds their provider row.
//   2. Creates an Express account if none exists, and ALWAYS writes
//      stripe_account_id back to the provider row.
//   3. RETRIEVES the account from Stripe and ALWAYS writes
//      stripe_charges_enabled = account.charges_enabled.
//   4. Returns an onboarding URL only while the account still needs onboarding.
//
// All DB writes use the SERVICE-ROLE client so RLS can never block the write.
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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    // ── 1. Authenticate the caller and resolve their provider row ───────────
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader) return json({ error: "Missing Authorization header" }, 401);

    // User-scoped client (validates the JWT and identifies the caller).
    const userClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData?.user) {
      return json({ error: "Not authenticated" }, 401);
    }
    const uid = userData.user.id;
    const email = userData.user.email ?? undefined;

    // Service-role client: bypasses RLS for the write-back. NEVER exposed to the
    // client — it lives only in this server-side function.
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: provider, error: provErr } = await admin
      .from("providers")
      .select("id, owner_id, stripe_account_id")
      .eq("owner_id", uid)
      .maybeSingle();
    if (provErr) return json({ error: provErr.message }, 400);
    if (!provider) {
      return json({ error: "No provider profile for this user" }, 404);
    }

    // ── 2. Ensure a Stripe account exists; ALWAYS persist its id ────────────
    let accountId: string | null = provider.stripe_account_id ?? null;

    if (!accountId) {
      const account = await stripe.accounts.create({
        type: "express",
        email,
        capabilities: {
          card_payments: { requested: true },
          transfers: { requested: true },
        },
        metadata: { provider_id: provider.id, owner_id: uid },
      });
      accountId = account.id;
      // Write-back on creation (the bug: this step was missing/conditional).
      const { error: idErr } = await admin
        .from("providers")
        .update({ stripe_account_id: accountId })
        .eq("id", provider.id);
      if (idErr) return json({ error: idErr.message }, 400);
    }

    // ── 3. Retrieve the account and ALWAYS write charges_enabled back ───────
    const account = await stripe.accounts.retrieve(accountId);
    const chargesEnabled = account.charges_enabled === true;

    const { error: chErr } = await admin
      .from("providers")
      .update({
        stripe_account_id: accountId, // idempotent; keeps the row authoritative
        stripe_charges_enabled: chargesEnabled,
      })
      .eq("id", provider.id);
    if (chErr) return json({ error: chErr.message }, 400);

    // ── 4. Onboarding URL only while the account still needs onboarding ─────
    const needsOnboarding =
      !chargesEnabled || account.details_submitted !== true;

    let onboardingUrl: string | undefined;
    if (needsOnboarding) {
      const body = await req.json().catch(() => ({}));
      const returnUrl: string =
        (body?.returnUrl as string) ?? new URL(req.url).origin;
      const link = await stripe.accountLinks.create({
        account: accountId,
        refresh_url: returnUrl,
        return_url: returnUrl,
        type: "account_onboarding",
      });
      onboardingUrl = link.url;
    }

    return json({ accountId, chargesEnabled, onboardingUrl });
  } catch (e) {
    console.error("stripe-connect-onboarding error:", e);
    return json({ error: (e as Error).message ?? "Unexpected error" }, 500);
  }
});
