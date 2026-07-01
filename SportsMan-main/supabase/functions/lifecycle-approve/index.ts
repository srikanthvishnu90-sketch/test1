// ============================================================================
// lifecycle-approve  (Supabase Edge Function) — the coach's explicit SEND
// ============================================================================
// A drafted lifecycle message NEVER sends on its own. The coach reviews it in the
// approval queue, optionally edits the body, and explicitly approves — this
// function then approves + delivers it. (outbound_messages is SELECT-only for
// clients, so approve+send must happen server-side, like parent-update-send.)
//
// Authorization: caller must own the provider on the row. State guard: only a
// 'drafted' row may be approved. Final claim guardrail is applied to the body so
// no credential/medical/safety claim can reach a parent even if hand-typed.
//
// Input: { id: string, body?: string }   // body = coach's edited text (optional)
// ============================================================================

import { createClient } from "npm:@supabase/supabase-js@2";
import { enforceLifecycleDraft } from "../lifecycle-process/policy.ts";
import { deliverPush } from "../_shared/push.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader) return json({ error: "Missing Authorization header" }, 401);
    const userClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: u, error: uErr } = await userClient.auth.getUser();
    if (uErr || !u?.user) return json({ error: "Not authenticated" }, 401);
    const uid = u.user.id;

    const body = await req.json().catch(() => ({}));
    const id: string = typeof body?.id === "string" ? body.id : "";
    if (!id) return json({ error: "id is required." }, 400);
    const editedBody: string | null = typeof body?.body === "string" ? body.body : null;

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: row, error: rErr } = await admin.from("outbound_messages")
      .select("id, provider_id, child_id, status, content").eq("id", id).maybeSingle();
    if (rErr) return json({ error: rErr.message }, 400);
    if (!row) return json({ error: "Message not found." }, 404);

    // AUTHORIZATION: caller must own the provider on this row.
    const { data: prov } = await admin.from("providers")
      .select("id").eq("id", row.provider_id).eq("owner_id", uid).maybeSingle();
    if (!prov) return json({ error: "Not authorized to approve this message." }, 403);

    if (row.status === "sent") return json({ ok: true, alreadySent: true, status: "sent" });
    if (row.status !== "drafted") {
      return json({ error: `Only a drafted message can be approved (status='${row.status}').` }, 409);
    }

    // Final guardrail: strip any credential/medical/safety claim from the body
    // that will actually be delivered (defense in depth, even on hand-typed edits).
    const sourceBody = editedBody ?? (row.content as { body?: string } | null)?.body ?? "";
    const { body: cleanBody, removed } = enforceLifecycleDraft(sourceBody);
    if (!cleanBody.trim()) {
      return json({ error: "Message body is empty after validation; nothing to send." }, 422);
    }

    // Resolve the verified guardian and deliver via the notifications channel.
    let guardianId: string | null = null;
    let childFirstName = "";
    if (row.child_id) {
      const { data: child } = await admin.from("athletes")
        .select("first_name, parent_id").eq("id", row.child_id).maybeSingle();
      guardianId = (child as { parent_id?: string } | null)?.parent_id ?? null;
      childFirstName = (child as { first_name?: string } | null)?.first_name ?? "";
    }
    if (!guardianId) return json({ error: "No verified guardian to deliver to." }, 422);

    const title = childFirstName ? `Message from your coach about ${childFirstName}` : "Message from your coach";
    const { error: notifErr } = await admin.from("notifications")
      .insert([{ user_id: guardianId, title, message: cleanBody.slice(0, 280) }]);
    if (notifErr) return json({ error: `Could not deliver: ${notifErr.message}` }, 500);

    // Best-effort push (the inbox row already delivered).
    await deliverPush(admin, guardianId, title, cleanBody.slice(0, 280));

    const { data: updated, error: updErr } = await admin.from("outbound_messages")
      .update({
        content: { ...(row.content as Record<string, unknown> ?? {}), body: cleanBody, removed },
        status: "sent",
        approved_by: uid,
        approved_at: new Date().toISOString(),
        sent_at: new Date().toISOString(),
      })
      .eq("id", id)
      .select("id, status, sent_at")
      .single();
    if (updErr) return json({ error: updErr.message }, 500);

    return json({ ok: true, status: updated.status, sent_at: updated.sent_at, removed });
  } catch (e) {
    console.error("lifecycle-approve error:", e);
    return json({ error: (e as Error).message ?? "Unexpected error" }, 500);
  }
});
