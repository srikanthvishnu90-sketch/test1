# Implementing your Anthropic API key

Your Anthropic key is a **server secret**. It must **never** go in `env.json`, Dart,
or any web/Flutter code — the web build is downloadable in the browser and would
leak the key (and let anyone spend on your account). It lives only inside the
`ai-chat` Edge Function's environment, exactly like the Stripe secret key.

There is **one place** you paste the key for each environment:

---

## A) The deployed app (production) — the page to paste into

1. Get a key: <https://console.anthropic.com> → **Settings → API Keys → Create Key**
   (it starts with `sk-ant-…`).
2. Open the **Supabase dashboard** → your project → **Edge Functions** → **Secrets**
   (also reachable via **Project Settings → Edge Functions → Secrets**).
3. Click **Add secret**:
   - **Name:** `ANTHROPIC_API_KEY`
   - **Value:** paste your `sk-ant-…` key
   - **Save.**
4. Deploy the function (paste [`supabase/functions/ai-chat/index.ts`](../supabase/functions/ai-chat/index.ts)
   into a new `ai-chat` function in the dashboard, or `supabase functions deploy ai-chat`).

That's it — the function reads the key via `Deno.env.get("ANTHROPIC_API_KEY")`.

> Prefer the CLI? One command does the same as steps 2–3:
> `supabase secrets set ANTHROPIC_API_KEY=sk-ant-...`

---

## B) Local development — the file to paste into

Paste your key into **[`supabase/functions/.env`](../supabase/functions/.env)**
(after the `=`), then run:

```
supabase functions serve ai-chat --env-file supabase/functions/.env
```

`supabase/functions/.env` is **gitignored** — it is never committed.

---

## How the app will call it (server-side, key stays hidden)

From Flutter, through the existing invoke pattern (the user's JWT is attached
automatically) — wire this into a repository method when the AI feature is built:

```dart
final res = await Supabase.instance.client.functions.invoke(
  'ai-chat',
  body: {'prompt': 'Suggest a warm-up for a U12 soccer session.'},
);
final text = (res.data as Map)['text'] as String?;
```

Request body accepts either `{"prompt": "..."}` or
`{"messages": [...], "system": "...", "maxTokens": 1024}`.
The function returns `{"text": "...", "stop_reason": ..., "usage": ...}` on success,
or `{"error": "..."}` on failure. Model: `claude-opus-4-8`.

## Verify it works

```
curl -i -X POST "$SUPABASE_URL/functions/v1/ai-chat" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer <a-signed-in-user-JWT>" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Say hello in one short sentence."}'
```

A `200` with a `"text"` field means the key is implemented correctly. A `500`
saying `ANTHROPIC_API_KEY is not set` means the secret hasn't been added yet.
