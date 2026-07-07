# plumb — open in VSCode

A personal instrument for accurate academic self-knowledge. Next.js (App Router)
+ TypeScript, ports-and-adapters. Runs with in-memory adapters and **no keys**.

## Run it (3 steps)

1. **Open the folder in VSCode** — `File → Open Folder…` → select this `plumb/` folder.
2. **Install deps** (needs Node 20+ and pnpm — `npm i -g pnpm` if you don't have it):
   ```bash
   pnpm install
   ```
3. **Start the dev server:**
   ```bash
   pnpm dev
   ```
   Open http://localhost:3000.

## Optional keys

Everything runs with zero keys (in-memory adapters). To enable the LLM / email /
database / crisis-cipher features, copy the template and fill in what you have:

```bash
cp .env.example .env.local
```

`.env.local` is gitignored and is **not** included in this archive — no secrets ship here.

## Useful commands

- `pnpm check` — typecheck + lint + unit tests (must pass before committing)
- `pnpm e2e`   — Playwright end-to-end tests
- `pnpm build` — production build

## Where things are

- `src/domain`     — pure business logic (no framework imports)
- `src/adapters`   — persistence / LLM / email implementations
- `src/app`        — Next.js routes + UI components
- `CLAUDE.md`      — full project context and guardrails
