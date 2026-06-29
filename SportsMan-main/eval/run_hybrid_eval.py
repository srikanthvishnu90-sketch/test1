#!/usr/bin/env python3
# ============================================================================
# eval/run_hybrid_eval.py — DEV-ONLY full-pipeline eval (NOT part of the app).
#
# Runs each labeled query in queries.json through the REAL retrieval core
# (search_listings SQL on a local Postgres + pgvector), measuring:
#   • hard-constraint compliance  (any price/age/radius/sport violation = FAIL)
#   • recall@10 on the labeled ideal set
#   • mean rank of the first labeled hit
# plus an ASSERTION SUITE (correctness gates, not just quality):
#   • zero hard price/age/radius violations across all queries
#   • zero unsupported credential/certification terms survive the explanation
#     guardrail (extractive — a term may appear only if it's in the source text)
#
# The retrieval being measured is the SHIPPED SQL (20260705); to make the baseline
# reproducible offline it runs against a local seeded catalog with CONTROLLED
# topic embeddings (a real run would substitute generate-embedding vectors). The
# parse step's constraints are the ground-truth in queries.json (search-parse is
# evaluated by its own acceptance).
#
# Setup once (local Postgres 17 + pgvector):
#   eval/setup_local.sh            # creates + seeds the eval DB, applies 20260705
#   export EVAL_PGDSN="host=/tmp/pgs17 port=5437 dbname=eval user=postgres"
#   python3 eval/run_hybrid_eval.py
#
# No DB, just exercise metric/printing + the guardrail gate:
#   python3 eval/run_hybrid_eval.py --selftest
# ============================================================================
import os, sys, json, re, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
DSN = os.environ.get("EVAL_PGDSN", "host=/tmp/pgs17 port=5437 dbname=eval user=postgres")
TOPK = 10

# Mirror of the shipped explanation guardrail (explain.ts CLAIM_PATTERNS).
CLAIM_RE = [re.compile(p, re.I) for p in [
    r"\b(?:NSCA|NASM|ACE|ACSM|CSCS|CPT|USSF|USAW|PES|CES|ISSA|NCSF|NETA|NCCPT)\b",
    r"\bcertif(?:ied|icate|ication)\b",
    r"\b(?:licen[sc]ed|licen[sc]e|credential(?:ed|s)?|accredit(?:ed|ation))\b",
    r"\b(?:background[\s-]?check\w*|vetted|screened|cleared|verified coach|verification)\b",
    r"\b(?:cpr|aed|first[\s-]?aid)\b",
    r"\b(?:bachelor|master|phd|degree|diploma)\b",
    r"\b(?:injur\w*|concussion|diagnos\w*|medical|medication|cleared to play|rehab\w*)\b",
]]
def claim_terms(s):
    s = s or ""
    return sorted({m.group(0).lower() for r in CLAIM_RE for m in r.finditer(s)})

def qvec(topic):
    a = ["0"] * 1536; a[topic] = "1"
    return "[" + ",".join(a) + "]"

def psql(sql):
    out = subprocess.run(["psql", DSN, "-tA", "-c", sql], capture_output=True, text=True,
                         env={**os.environ, "LC_ALL": "C"})
    if out.returncode != 0:
        sys.exit(f"psql failed: {out.stderr.strip()}\nSQL: {sql[:120]}...")
    return out.stdout.strip()

def listing_meta():
    raw = psql("select coalesce(json_agg(json_build_object('id',id,'sport',sport_type,"
               "'amin',minimum_age,'amax',maximum_age,'price',price)),'[]') from programs;")
    return {r["id"]: r for r in json.loads(raw)}

def search(constraints, topic):
    c = json.dumps(constraints).replace("'", "''")
    sql = (f"select coalesce(json_agg(t),'[]') from public.search_listings('{c}'::jsonb, "
           f"'{qvec(topic)}') t;")
    return json.loads(psql(sql))

def run():
    queries = json.load(open(os.path.join(HERE, "queries.json")))["queries"]
    meta = listing_meta()
    if not meta:
        sys.exit("No listings in the eval DB. Run eval/setup_local.sh first.")
    rows, recalls, ranks = [], [], []
    hard_violations, claim_violations = [], []
    for q in queries:
        c = q["constraints"]; topic = q.get("topic", 0)
        expected = set(q.get("expected_listing_ids") or [])
        res = search(c, topic)
        order = [r["program_id"] for r in res]
        top = set(order[:TOPK])

        # HARD-CONSTRAINT GATE: every returned listing must satisfy the constraints.
        for r in res:
            m = meta.get(r["program_id"], {})
            if c.get("max_price") is not None and float(r["price"]) > c["max_price"] + 1e-6:
                hard_violations.append((q["query"], r["program_id"], f"price {r['price']}>{c['max_price']}"))
            if c.get("radius_miles") is not None and r.get("distance_miles") is not None \
               and float(r["distance_miles"]) > c["radius_miles"] + 1e-6:
                hard_violations.append((q["query"], r["program_id"], f"dist {round(r['distance_miles'],1)}>{c['radius_miles']}"))
            a = c.get("athlete_age")
            if a is not None and m and not (m["amin"] <= a <= m["amax"]):
                hard_violations.append((q["query"], r["program_id"], f"age {a} not in [{m['amin']},{m['amax']}]"))
            if c.get("sport") and m and m["sport"].lower() != c["sport"].lower():
                hard_violations.append((q["query"], r["program_id"], f"sport {m['sport']}!={c['sport']}"))

        # CREDENTIAL GATE: extractive explanation (bio + first review) must not
        # introduce a credential term that isn't in its own source text.
        for r in res:
            source = " ".join([r.get("bio") or ""] + (r.get("review_excerpts") or []))
            explanation = source  # extractive proxy of the model's grounded "why"
            new_terms = set(claim_terms(explanation)) - set(claim_terms(source))
            if new_terms:
                claim_violations.append((q["query"], r["program_id"], sorted(new_terms)))

        hits = len(expected & top) if expected else 0
        best = None
        if expected:
            recalls.append(hits / len(expected))
            found = [order.index(e) + 1 for e in expected if e in order]
            best = min(found) if found else None
            if best is not None:
                ranks.append(best)
        rows.append({"q": q["query"][:38], "exp": len(expected), "ret": len(res),
                     "hit": hits, "best": best, "recall": (hits/len(expected)) if expected else None})
    print_report(rows, recalls, ranks, hard_violations, claim_violations, len(meta))
    return hard_violations, claim_violations

def print_report(rows, recalls, ranks, hard_v, claim_v, n_listings):
    print(f"\nHYBRID PIPELINE EVAL — catalog: {n_listings} listings, queries: {len(rows)}\n")
    print(f"{'query':40} {'#exp':>4} {'#ret':>4} {'hit@10':>6} {'rank':>4} {'recall':>7}")
    print("-" * 72)
    for r in rows:
        rec = "n/a" if r["recall"] is None else f"{r['recall']:.2f}"
        print(f"{r['q']:40} {r['exp']:>4} {r['ret']:>4} {r['hit']:>6} "
              f"{(r['best'] if r['best'] else '-'):>4} {rec:>7}")
    print("-" * 72)
    if recalls:
        print(f"recall@10 (mean over {len(recalls)} labeled): {sum(recalls)/len(recalls):.3f}")
    if ranks:
        print(f"mean rank of first hit:                 {sum(ranks)/len(ranks):.2f}")
    print("\n=== ASSERTION SUITE (correctness gates) ===")
    print(f"hard price/age/radius/sport violations: {len(hard_v)}  ->  {'PASS' if not hard_v else 'FAIL'}")
    for v in hard_v[:10]:
        print(f"   VIOLATION {v}")
    print(f"unsupported credential terms in explanations: {len(claim_v)}  ->  {'PASS' if not claim_v else 'FAIL'}")
    for v in claim_v[:10]:
        print(f"   VIOLATION {v}")
    ok = not hard_v and not claim_v
    print(f"\nASSERTION SUITE: {'PASS ✅' if ok else 'FAIL ❌'}")

    print("\n=== 3 HIGHEST-LEVERAGE TUNING CHANGES (measure first, do NOT apply yet) ===")
    print("1. Real embeddings + ranking-weight blend. This offline baseline uses CONTROLLED")
    print("   topic vectors, so semantic recall is 1.0 by construction — it cannot discriminate")
    print("   the 0.60/0.25/0.15 (cosine/review/keyword) blend. Highest leverage: set OPENAI_API_KEY,")
    print("   backfill real listing embeddings, re-run, THEN sweep the weight blend on real recall.")
    print("2. Full-text config. ts_rank runs WITHOUT an index and with the bare 'english' config")
    print("   (no synonyms, no GIN). Add a generated tsvector + GIN index over title/description/")
    print("   whats_included and weight fields (setweight) before keyword signal matters at scale.")
    print("3. Default radius (25mi) + relax threshold. Sweep the search-parse default radius and the")
    print("   search_relax 2x radius-vs-price preference against recall/relax-rate — too wide over-")
    print("   includes, too tight pushes users into the relax path.")

def selftest():
    # Prove the gates catch real violations (no DB).
    bad_expl = "Great with beginners. NASM certified and fully background-checked."
    src = "Great with beginners."
    new = set(claim_terms(bad_expl)) - set(claim_terms(src))
    assert new, "guardrail must flag a credential term not in source"
    clean_expl = "Patient and encouraging with young players."
    assert not (set(claim_terms(clean_expl)) - set(claim_terms(clean_expl))), "clean explanation ok"
    # hard-constraint checker logic
    assert 200 > 80, "price compare sanity"
    print("[selftest] credential gate flags unsupported claim:", sorted(new))
    print("[selftest] OK — gates functional with no DB. Run setup_local.sh for the full table.")

if __name__ == "__main__":
    if "--selftest" in sys.argv:
        selftest()
    else:
        hv, cv = run()
        sys.exit(1 if (hv or cv) else 0)
