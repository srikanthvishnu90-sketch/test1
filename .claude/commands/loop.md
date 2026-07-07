---
description: Build → pnpm check → critique → fix loop for a single plumb task.
---

# loop

Run one plumb task to completion under the project's build standard. Read
[CLAUDE.md](../../CLAUDE.md) first — its guardrails, product-safety rules, and
domain glossary govern everything below.

## The loop

1. **Scope.** State exactly what this task builds — nothing more (no gold-plating).
   Name the files you will touch and the invariants involved.
2. **Build.** Implement the smallest correct version. Domain logic stays pure
   (`src/domain`, no framework imports); external services go behind ports with
   in-memory adapters. Every piece of non-trivial logic ships with unit tests.
3. **Check.** Run `pnpm check` (typecheck + lint + test). It must pass. Resolve
   every warning — a warning is a defect until proven otherwise.
4. **Critique.** Invoke the `critic` agent on the diff. It enforces the CLAUDE.md
   guardrails and product-safety rules (task-focused feedback, no green/red accuracy
   semantics, no gamified rewards, controllable/specific attributions, AI = labor).
5. **Fix.** Address every finding. Re-run `pnpm check`. Repeat 4–5 until the critic
   is satisfied and the loop is green.
6. **Report.** Summarize what was built, which invariants are now enforced, and any
   new dependency (with justification).

Never widen scope mid-loop. If a task reveals new work, note it and stop — a new
task, a new loop.
