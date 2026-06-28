# /eval — DEV-ONLY AI evaluation harness

**Not part of the app or any production code path.** Nothing here is imported by
`lib/`; the Flutter build does not include it. These are local Python scripts
(stdlib only — no installs) for measuring listing semantic search and AI cost.

## Files
- `queries.json` — ~10 seed `{query, expected_listing_ids, notes}` entries + a
  comment block (`_comment`) explaining how to grow to 50 labeled queries.
- `run_eval.py` — embeds each query via `generate-embedding`, ranks listing
  embeddings by cosine similarity, prints **recall@10** and **mean rank**.
  (Targets embedding similarity directly today; will be extended to hybrid search.)
- `cost_report.py` — summarizes `ai_audit_log` grouped by **feature** and **day**
  (calls, tokens, est USD). Reads the service-role-only table → needs the service key.

## Run now, no Supabase (self-test the metric/printing path)
```
python3 eval/run_eval.py --selftest
python3 eval/cost_report.py --selftest
```

## Run against real data (after migration + backfill + functions deployed)
```
# A signed-in user JWT (or the service-role key) lets the eval call generate-embedding:
export EVAL_BEARER="<jwt-or-service-role-key>"
python3 eval/run_eval.py

# Cost report needs the service role (ai_audit_log is service-role-only by RLS):
export SUPABASE_SERVICE_ROLE_KEY="<service-role-key>"
python3 eval/cost_report.py
```
Optional overrides: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `EMBED_FUNCTION_NAME`
(set the last if you deployed `generate-embedding` under a different slug).

## Notes
- Label `expected_listing_ids` from real rows
  (`select id, title, sport_type, skill_level, age_group from programs;`).
- Recall is scored only over queries that have `expected_listing_ids`.
- Never label on price/location/availability/certs/background-check — those are
  structured/deterministic, not semantic (hard rule).
