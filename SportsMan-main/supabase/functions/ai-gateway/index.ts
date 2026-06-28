// ============================================================================
// ai-gateway  (Supabase Edge Function)
// ============================================================================
// The single chokepoint for all AI in Sporve. Wraps the Anthropic Messages API:
//   • Model routing by TASK (clients never pick the model):
//       parse | classify | extract  -> claude-haiku-4-5-20251001
//       draft | summarize | reason   -> claude-sonnet-4-6
//       claude-opus-4-8 is reserved — only a SERVICE-ROLE caller may force it via
//       modelOverride. A user JWT can never escalate to Opus.
//   • Prompt caching on the (stable) system prompt.
//   • Per-call capture of tokens, estimated USD cost, and latency.
//   • Exactly ONE ai_audit_log row per call (success or handled error), written
//     with the service-role client. Stores HASHES + sizes only — never the full
//     prompt/response, PII, or secrets.
//   • Hard per-call max_tokens ceiling (MAX_TOKENS_CEILING, default 4096).
//   • ANTHROPIC_API_KEY from secrets; never hardcoded, never returned.
//
// Public internal API (HTTP body = the runAI args):
//   runAI({ task, system?, messages, tools?, actorId?, actorRole?, feature,
//           maxTokens?, modelOverride? })
// Auth: a signed-in user (actor derived from their JWT; override ignored) OR the
// service role (trusts actorId/actorRole + may set modelOverride).
// ============================================================================

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

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const MAX_TOKENS_CEILING = Number(Deno.env.get("MAX_TOKENS_CEILING") ?? 4096);

const MODELS = {
  haiku: "claude-haiku-4-5-20251001",
  sonnet: "claude-sonnet-4-6",
  opus: "claude-opus-4-8",
};

// Per-1M-token USD pricing (in / cache-read / cache-write / out).
const PRICING: Record<string, { in: number; cacheRead: number; cacheWrite: number; out: number }> = {
  "claude-haiku-4-5-20251001": { in: 1.0, cacheRead: 0.1, cacheWrite: 1.25, out: 5.0 },
  "claude-sonnet-4-6":         { in: 3.0, cacheRead: 0.3, cacheWrite: 3.75, out: 15.0 },
  "claude-opus-4-8":           { in: 5.0, cacheRead: 0.5, cacheWrite: 6.25, out: 25.0 },
};

const HAIKU_TASKS = new Set(["parse", "classify", "extract"]);
const SONNET_TASKS = new Set(["draft", "summarize", "reason"]);

function routeModel(task: string, modelOverride: string | undefined, isService: boolean): string {
  // Only the service role may force a specific model (incl. Opus).
  if (modelOverride && isService) return modelOverride;
  const t = (task ?? "").toLowerCase();
  if (HAIKU_TASKS.has(t)) return MODELS.haiku;
  if (SONNET_TASKS.has(t)) return MODELS.sonnet;
  return MODELS.sonnet; // safe default for unknown tasks (never Opus implicitly)
}

function estCost(model: string, inUncached: number, cacheRead: number, cacheWrite: number, out: number): number {
  const p = PRICING[model];
  if (!p) return 0;
  const c = (inUncached / 1e6) * p.in
    + (cacheRead / 1e6) * p.cacheRead
    + (cacheWrite / 1e6) * p.cacheWrite
    + (out / 1e6) * p.out;
  return Math.round(c * 1e6) / 1e6; // 6dp, matches numeric(12,6)
}

async function sha256Hex(s: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

type RunAIArgs = {
  task: string;
  system?: string;
  messages: { role: string; content: unknown }[];
  tools?: unknown[];
  actorId?: string | null;
  actorRole?: string | null;
  feature: string;
  maxTokens?: number;
  modelOverride?: string;
  isService: boolean;
};

async function runAI(args: RunAIArgs) {
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const model = routeModel(args.task, args.modelOverride, args.isService);
  const maxTokens = Math.min(
    Math.max(1, Number(args.maxTokens ?? 1024)),
    MAX_TOKENS_CEILING, // hard ceiling — requests can't exceed it
  );

  // Prompt caching on the stable system prompt.
  const system = args.system
    ? [{ type: "text", text: args.system, cache_control: { type: "ephemeral" } }]
    : undefined;

  const reqBody: Record<string, unknown> = {
    model,
    max_tokens: maxTokens,
    messages: args.messages,
    ...(system ? { system } : {}),
    ...(args.tools ? { tools: args.tools } : {}),
  };

  const t0 = Date.now();
  let ok = false;
  let errMsg: string | null = null;
  let text = "";
  let usage: Record<string, number> = {};
  try {
    const resp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": ANTHROPIC_API_KEY!,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify(reqBody),
    });
    const data = await resp.json();
    if (!resp.ok) {
      errMsg = data?.error?.message ?? `Anthropic API error ${resp.status}`;
    } else {
      ok = true;
      usage = data?.usage ?? {};
      text = Array.isArray(data?.content)
        ? data.content.filter((b: { type: string }) => b.type === "text")
            .map((b: { text: string }) => b.text).join("")
        : "";
    }
  } catch (e) {
    errMsg = (e as Error).message ?? "request failed";
  }
  const latency_ms = Date.now() - t0;

  const inUncached = usage.input_tokens ?? 0;
  const cacheRead = usage.cache_read_input_tokens ?? 0;
  const cacheWrite = usage.cache_creation_input_tokens ?? 0;
  const tokensOut = usage.output_tokens ?? 0;
  const tokensIn = inUncached + cacheRead + cacheWrite; // total prompt tokens
  const est_cost_usd = estCost(model, inUncached, cacheRead, cacheWrite, tokensOut);

  // Audit summaries: HASHES + sizes only. No raw prompt/response text persisted.
  const inputSerialized = JSON.stringify({ system: args.system ?? null, messages: args.messages });
  const inputHash = await sha256Hex(inputSerialized);
  const outputHash = ok ? await sha256Hex(text) : null;

  const row = {
    feature: args.feature ?? "unknown",
    model,
    actor_id: args.actorId ?? null,
    actor_role: args.actorRole ?? null,
    input_summary: `task=${args.task}; chars=${inputSerialized.length}; sha256=${inputHash.slice(0, 16)}`,
    output_summary: ok
      ? `chars=${text.length}; sha256=${outputHash!.slice(0, 16)}`
      : `error: ${(errMsg ?? "").slice(0, 400)}`,
    tokens_in: tokensIn,
    tokens_out: tokensOut,
    est_cost_usd,
    latency_ms,
  };

  // Exactly one audit row per call. Return the persisted row as proof.
  const { data: audit, error: auditErr } = await admin
    .from("ai_audit_log").insert(row).select().single();
  if (auditErr) console.error("ai_audit_log insert failed:", auditErr.message);

  if (!ok) {
    return { error: errMsg, model, task: args.task, latency_ms, audit: audit ?? null };
  }
  return {
    text,
    model,
    task: args.task,
    usage: { tokens_in: tokensIn, tokens_out: tokensOut, cache_read: cacheRead, cache_write: cacheWrite },
    est_cost_usd,
    latency_ms,
    audit: audit ?? null,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    if (!ANTHROPIC_API_KEY) {
      return json({ error: "ANTHROPIC_API_KEY is not set on this function." }, 500);
    }
    const authHeader = req.headers.get("Authorization") ?? "";
    const bearer = authHeader.replace(/^Bearer\s+/i, "");
    if (!bearer) return json({ error: "Missing Authorization header" }, 401);
    const isService = bearer === SERVICE_ROLE_KEY;

    let actorId: string | null = null;
    let actorRole: string | null = null;
    if (!isService) {
      const userClient = createClient(SUPABASE_URL, ANON_KEY, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: u, error } = await userClient.auth.getUser();
      if (error || !u?.user) return json({ error: "Not authenticated" }, 401);
      // Actor comes from the validated JWT — client-supplied actor is ignored.
      actorId = u.user.id;
      actorRole = (u.user.user_metadata?.role as string | undefined) ?? "authenticated";
    }

    const body = await req.json().catch(() => ({}));
    if (typeof body?.task !== "string") return json({ error: "`task` (string) is required." }, 400);
    if (!Array.isArray(body?.messages)) return json({ error: "`messages` (array) is required." }, 400);
    if (typeof body?.feature !== "string") return json({ error: "`feature` (string) is required." }, 400);

    const result = await runAI({
      task: body.task,
      system: typeof body.system === "string" ? body.system : undefined,
      messages: body.messages,
      tools: Array.isArray(body.tools) ? body.tools : undefined,
      // service role may attribute the call to an actor; user calls are self-attributed
      actorId: isService ? (body.actorId ?? null) : actorId,
      actorRole: isService ? (body.actorRole ?? null) : actorRole,
      feature: body.feature,
      maxTokens: body.maxTokens,
      modelOverride: isService ? body.modelOverride : undefined, // Opus escalation = service only
      isService,
    });

    return json(result, "error" in result && result.error ? 502 : 200);
  } catch (e) {
    console.error("ai-gateway error:", e);
    return json({ error: (e as Error).message ?? "Unexpected error" }, 500);
  }
});
