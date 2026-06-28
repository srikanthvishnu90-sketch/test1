#!/usr/bin/env python3
# ============================================================================
# eval/cost_report.py  — DEV-ONLY ai_audit_log cost report, grouped by feature
# and day. NOT imported by the app / never in a production code path.
#
# ai_audit_log is SERVICE-ROLE-ONLY (RLS), so reading it needs the service key.
#
# RUN NOW, NO SUPABASE NEEDED (proves the grouping/printing path):
#   python3 eval/cost_report.py --selftest
#
# RUN AGAINST REAL DATA:
#   export SUPABASE_SERVICE_ROLE_KEY="<service role key>"
#   export SUPABASE_URL=...   # optional override
#   python3 eval/cost_report.py
#
# Stdlib only — no pip installs.
# ============================================================================
import os, sys, json, urllib.request, collections

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://tseszaprvtvqrkfpditu.supabase.co")
SVC = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")


def _http_get(url, headers):
    req = urllib.request.Request(url, headers=headers, method="GET")
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


def fetch_rows():
    if not SVC:
        sys.exit("ai_audit_log is service-role-only. Set SUPABASE_SERVICE_ROLE_KEY to read it.")
    hdr = {"apikey": SVC, "Authorization": f"Bearer {SVC}"}
    url = (f"{SUPABASE_URL}/rest/v1/ai_audit_log"
           "?select=created_at,feature,model,tokens_in,tokens_out,est_cost_usd"
           "&order=created_at.desc&limit=10000")
    return _http_get(url, hdr)


def report(rows):
    agg = collections.defaultdict(lambda: {"calls": 0, "tin": 0, "tout": 0, "cost": 0.0})
    for r in rows:
        day = (r.get("created_at") or "")[:10]
        feat = r.get("feature") or "unknown"
        a = agg[(day, feat)]
        a["calls"] += 1
        a["tin"] += int(r.get("tokens_in") or 0)
        a["tout"] += int(r.get("tokens_out") or 0)
        a["cost"] += float(r.get("est_cost_usd") or 0)

    print(f"\nai_audit_log — cost by feature & day   (rows: {len(rows)})\n")
    print(f"{'day':12} {'feature':20} {'calls':>6} {'tokens_in':>10} {'tokens_out':>11} {'est_usd':>10}")
    print("-" * 74)
    tot = {"calls": 0, "tin": 0, "tout": 0, "cost": 0.0}
    for (day, feat) in sorted(agg.keys(), reverse=True):
        a = agg[(day, feat)]
        print(f"{day:12} {feat[:20]:20} {a['calls']:>6} {a['tin']:>10} {a['tout']:>11} {a['cost']:>10.4f}")
        tot["calls"] += a["calls"]; tot["tin"] += a["tin"]; tot["tout"] += a["tout"]; tot["cost"] += a["cost"]
    print("-" * 74)
    print(f"{'TOTAL':12} {'':20} {tot['calls']:>6} {tot['tin']:>10} {tot['tout']:>11} {tot['cost']:>10.4f}\n")


def selftest():
    rows = [
        {"created_at": "2026-06-28T10:00:00Z", "feature": "smoke-test", "model": "claude-haiku-4-5-20251001",
         "tokens_in": 30, "tokens_out": 8, "est_cost_usd": 0.00007},
        {"created_at": "2026-06-28T11:00:00Z", "feature": "smoke-test", "model": "claude-sonnet-4-6",
         "tokens_in": 40, "tokens_out": 20, "est_cost_usd": 0.00042},
        {"created_at": "2026-06-28T12:00:00Z", "feature": "listing-summary", "model": "claude-sonnet-4-6",
         "tokens_in": 900, "tokens_out": 220, "est_cost_usd": 0.0060},
        {"created_at": "2026-06-27T09:00:00Z", "feature": "listing-summary", "model": "claude-sonnet-4-6",
         "tokens_in": 850, "tokens_out": 200, "est_cost_usd": 0.0056},
    ]
    report(rows)
    print("[selftest] OK — grouping + totals printed with no Supabase.")


def main():
    if "--selftest" in sys.argv:
        return selftest()
    report(fetch_rows())


if __name__ == "__main__":
    main()
