// ============================================================================
// lifecycle-process  (Supabase Edge Function) — the CONTENT + CONTROL worker
// ============================================================================
// Invoked by pg_cron (service role) on a short interval. Picks up DUE 'pending'
// outbound_messages and acts per the coach's lifecycle_message_prefs.mode for
// that event_type:
//   • off   -> status='skipped' (no content).
//   • draft -> generate personalized content via ai-gateway (haiku for short
//              logistics reminders, sonnet for richer follow-ups), strip claims,
//              store content, status='drafted'. NOTHING sends — the coach
//              approves later (lifecycle-approve / approval queue).
//   • auto  -> ONLY logistics types. Fill a FIXED template with thin
//              personalization (child first name, date/time, place), status
//              'approved', then send via the notifications/inbox channel,
//              status='sent'. HARD GUARDRAIL: the auto path never calls the model
//              and never emits free-form content — if a clean logistics template
//              can't be built it FALLS BACK to draft (a human approves).
//
// Tone via buildCoachVoiceProfile; guardrails identical to P3 (no credential /
// medical / safety claims). Every model call is logged to ai_audit_log
// (feature="lifecycle") inside ai-gateway. This worker authenticates to the
// gateway with the service role and attributes the call to the coach.
//
// post_session here is a logistics/feedback nudge to the parent, DISTINCT from
// the P2 progress update; a coach who uses P2 can set post_session='off'.
// ============================================================================

import { createClient } from "npm:@supabase/supabase-js@2";
import { buildCoachVoiceProfile } from "../_shared/coach_voice.ts";
import {
  resolveAction,
  modelForEvent,
  autoOrFallback,
  enforceLifecycleDraft,
} from "./policy.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GATEWAY_FN = Deno.env.get("GATEWAY_FUNCTION_NAME") ?? "ai-gateway";
const BATCH = Number(Deno.env.get("LIFECYCLE_BATCH") ?? 25);

const EVENT_GUIDANCE: Record<string, string> = {
  booking_confirmed: "a brief, warm confirmation that the session is booked.",
  reminder_24h: "a short, friendly reminder that a session is coming up.",
  post_session: "a brief, warm check-in after a session — a logistics/feedback nudge (e.g. how did it go, anything to flag for next time). This is NOT a progress report; do not summarize skills or progress.",
  no_show_followup: "a gentle, non-judgmental check-in after a missed session, offering to reschedule.",
  rebook_nudge: "a warm, low-pressure invitation to book another session, since it's been a while.",
};

const SYSTEM = [
  "You write a SHORT message a youth-sports coach could send to a parent. Output ONLY the message body — no preamble, no signature, plain language.",
  "HARD RULES (non-negotiable):",
  "- NO certifications, credentials, licenses, accreditations, or degrees.",
  "- NO medical or safety claims (injuries, diagnoses, 'cleared to play', recovery, etc.).",
  "- Truthful over flattering. Never invent facts about the child, sessions, schedules, prices, or availability beyond what is given.",
  "- This is a DRAFT the coach will review and edit; do not claim anything is already done.",
  "- Tone anchors are the coach's OWN past writing — match warmth/voice ONLY, never copy their facts.",
].join("\n");

type Admin = ReturnType<typeof createClient>;

/** Resolve the coach's profile id (notification recipient author) + display name. */
async function resolveProvider(admin: Admin, providerId: string) {
  const { data } = await admin.from("providers")
    .select("owner_id, business_name").eq("id", providerId).maybeSingle();
  return {
    ownerId: (data as { owner_id?: string } | null)?.owner_id ?? null,
    businessName: (data as { business_name?: string } | null)?.business_name ?? null,
  };
}

/** Logistics vars + guardian for a row (child first name, date/time/place, guardian id). */
async function resolveContext(admin: Admin, row: Record<string, unknown>) {
  let childFirstName = "";
  let guardianId: string | null = null;
  if (row.child_id) {
    const { data: child } = await admin.from("athletes")
      .select("first_name, parent_id").eq("id", row.child_id as string).maybeSingle();
    childFirstName = (child as { first_name?: string } | null)?.first_name ?? "";
    guardianId = (child as { parent_id?: string } | null)?.parent_id ?? null;
  }
  let dateText = "", timeText = "", place = "";
  if (row.booking_id) {
    const { data: b } = await admin.from("bookings")
      .select("session_id, athlete_first_name").eq("id", row.booking_id as string).maybeSingle();
    if (!childFirstName) childFirstName = (b as { athlete_first_name?: string } | null)?.athlete_first_name ?? "";
    const sessionId = (b as { session_id?: string } | null)?.session_id ?? null;
    if (sessionId) {
      const { data: s } = await admin.from("sessions")
        .select("start_date, start_time, address").eq("id", sessionId).maybeSingle();
      const sd = s as { start_date?: string; start_time?: string; address?: string } | null;
      dateText = sd?.start_date ?? "";
      timeText = sd?.start_time ?? "";
      place = sd?.address ?? "";
    }
  }
  return { childFirstName, guardianId, dateText, timeText, place };
}

/** Deliver a finalized body to the child's guardian via the notifications channel. */
async function deliver(admin: Admin, guardianId: string, childFirstName: string, body: string) {
  const title = childFirstName ? `Message from your coach about ${childFirstName}` : "Message from your coach";
  const { error } = await admin.from("notifications")
    .insert([{ user_id: guardianId, title, message: body.slice(0, 280) }]);
  return !error;
}

/** Generate a drafted body via the gateway (service role, attributed to coach). */
async function generateDraft(
  admin: Admin, row: Record<string, unknown>, ownerId: string | null, childFirstName: string,
): Promise<{ body: string; removed: string[]; model: string | null; audit_id: string | null } | { error: string }> {
  const eventType = row.event_type as string;
  const samples = await buildCoachVoiceProfile(admin, row.provider_id as string);
  const parts: string[] = [
    `Write ${EVENT_GUIDANCE[eventType] ?? "a short, warm message."}`,
    `Child's first name: ${childFirstName || "(not given)"}`,
  ];
  if (samples.length) {
    parts.push("", "Tone anchors — match the coach's voice ONLY, never copy their facts:",
      ...samples.map((s) => `- ${s}`));
  }
  const gResp = await fetch(`${SUPABASE_URL}/functions/v1/${GATEWAY_FN}`, {
    method: "POST",
    headers: { "apikey": SERVICE_ROLE_KEY, "Authorization": `Bearer ${SERVICE_ROLE_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      task: "draft",
      feature: "lifecycle",
      system: SYSTEM,
      messages: [{ role: "user", content: [{ type: "text", text: parts.join("\n") }] }],
      modelOverride: modelForEvent(eventType), // service role may pin the model
      actorId: ownerId,
      actorRole: "provider",
      maxTokens: 500,
    }),
  });
  const g = await gResp.json();
  if (!gResp.ok) return { error: g?.error ?? `ai-gateway error (${gResp.status})` };
  const { body, removed } = enforceLifecycleDraft(g?.text ?? "");
  return { body, removed, model: g?.model ?? null, audit_id: g?.audit?.id ?? null };
}

// True when the bearer is a service_role JWT. The platform's verify_jwt already
// validated the signature at the edge; we additionally require the role claim.
function isServiceRoleJwt(token: string): boolean {
  try {
    const seg = token.split(".")[1];
    if (!seg) return false;
    const json = atob(seg.replace(/-/g, "+").replace(/_/g, "/"));
    return JSON.parse(json)?.role === "service_role";
  } catch {
    return false;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    // Server-only: invoked by pg_cron with a service_role JWT. Accept that claim
    // OR an exact match of the injected secret key (covers both key systems).
    const bearer = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    if (bearer !== SERVICE_ROLE_KEY && !isServiceRoleJwt(bearer)) {
      return json({ error: "Forbidden (service role only)." }, 403);
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: rows, error } = await admin.from("outbound_messages")
      .select("*")
      .eq("status", "pending")
      .or(`scheduled_for.is.null,scheduled_for.lte.${new Date().toISOString()}`)
      .order("created_at", { ascending: true })
      .limit(BATCH);
    if (error) return json({ error: error.message }, 500);

    const summary = { processed: 0, skipped: 0, drafted: 0, autoSent: 0, fellBackToDraft: 0, failed: 0 };

    for (const row of rows ?? []) {
      const eventType = row.event_type as string;
      const providerId = row.provider_id as string;

      // ATOMIC CLAIM: flip pending -> processing for THIS row only. If another
      // (overlapping) tick already claimed it, the update matches 0 rows and we
      // skip — this is the single guard against double-draft / double-send.
      const { data: claimed } = await admin.from("outbound_messages")
        .update({ status: "processing" })
        .eq("id", row.id).eq("status", "pending")
        .select("id").maybeSingle();
      if (!claimed) continue;
      summary.processed++;

      // Effective mode for this coach + event (default 'draft' when no pref row).
      const { data: pref } = await admin.from("lifecycle_message_prefs")
        .select("mode").eq("provider_id", providerId).eq("event_type", eventType).maybeSingle();
      const mode = (pref as { mode?: string } | null)?.mode ?? "draft";
      let action = resolveAction(mode, eventType);

      if (action === "skip") {
        await admin.from("outbound_messages").update({ status: "skipped" }).eq("id", row.id);
        summary.skipped++;
        continue;
      }

      const { ownerId } = await resolveProvider(admin, providerId);
      const ctx = await resolveContext(admin, row);

      // AUTO (logistics only): fixed template, no model. Fall back to draft if a
      // clean logistics template can't be built OR there's no guardian to deliver
      // to (the hard guardrail — a human approves instead of auto-sending).
      if (action === "auto") {
        const tpl = autoOrFallback(eventType, ctx);
        if (!tpl || !ctx.guardianId) {
          action = "draft";
          summary.fellBackToDraft++;
        } else {
          const sent = await deliver(admin, ctx.guardianId, ctx.childFirstName, tpl);
          await admin.from("outbound_messages").update({
            content: { body: tpl, auto: true, template: true },
            status: sent ? "sent" : "approved",
            approved_at: new Date().toISOString(),
            sent_at: sent ? new Date().toISOString() : null,
          }).eq("id", row.id);
          if (sent) summary.autoSent++; else summary.failed++;
          continue;
        }
      }

      // DRAFT: generate, store, surface for approval. Nothing sends.
      const gen = await generateDraft(admin, row, ownerId, ctx.childFirstName);
      if ("error" in gen) {
        // release the claim so a later tick can retry (see follow-up: add an
        // attempts cap to avoid unbounded retries on a permanently-bad row).
        await admin.from("outbound_messages").update({ status: "pending" }).eq("id", row.id);
        summary.failed++;
        continue;
      }
      await admin.from("outbound_messages").update({
        content: { body: gen.body, model: gen.model, removed: gen.removed, auto: false },
        status: "drafted",
      }).eq("id", row.id);
      summary.drafted++;
    }

    return json({ ok: true, ...summary });
  } catch (e) {
    console.error("lifecycle-process error:", e);
    return json({ error: (e as Error).message ?? "Unexpected error" }, 500);
  }
});
