# Deploying the Sporve web demo

The demo is the **real app** running against the live Supabase backend + Edge
Functions, on **Stripe test mode** (test cards, real end-to-end flow, no live
money). No live-mode work is required to demo.

## 1. Build

```
flutter build web --release --dart-define-from-file=env.json
```

Output goes to `build/web/`. Keep `env.json` on **test** Stripe keys. The
Firebase push keys are optional — leave them blank to ship without push.

> `web/_redirects` (Netlify) and `web/vercel.json` (Vercel) are copied into
> `build/web` automatically so client-side routes resolve (SPA rewrite → all
> paths serve `index.html`).

## 2. Deploy the prebuilt folder

Pick one host. Both deploy the already-built `build/web` (no server build step,
so the host never needs Flutter installed).

### Vercel (recommended — simplest)
```
npm i -g vercel        # once
cd build/web
vercel --prod          # first run: log in + accept defaults
```

### Netlify
```
npm i -g netlify-cli   # once
netlify deploy --prod --dir build/web
```

### Firebase Hosting (if you already set up Firebase for push)
```
npm i -g firebase-tools   # once
firebase init hosting     # once — set public dir to build/web, SPA = yes
firebase deploy --only hosting
```

## 3. After deploy

- Open the URL, sign up / log in, and try the search bar or the **Find your
  coach** button (the ⟡ auto-awesome icon next to filters).
- The Chicago demo market is seeded (20 verified providers, 4 sports) so search
  and match both return ranked, explained, safety-gated coaches.

## Optional: semantic search (when an OpenAI key is available)

Search works today on keyword + rating. To enable vector/semantic ranking:
1. Add `OPENAI_API_KEY` to Supabase → Edge Functions → Secrets.
2. Invoke `backfill-embeddings` once to embed the seeded listings.
No code changes — it's already wired (`text-embedding-3-small`, 1536-dim).
