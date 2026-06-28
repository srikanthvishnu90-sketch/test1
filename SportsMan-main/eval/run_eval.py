#!/usr/bin/env python3
# ============================================================================
# eval/run_eval.py  — DEV-ONLY listing semantic-search eval.
# NOT imported by the app and never part of any production code path.
#
# What it does: embeds each query in queries.json via the generate-embedding
# Edge Function, ranks the listing (programs) embeddings by cosine similarity,
# and prints recall@10 + mean rank in a table. It targets embedding similarity
# directly today; it will be extended to full hybrid search later.
#
# RUN NOW, NO SUPABASE NEEDED (proves the metric/ranking/printing path):
#   python3 eval/run_eval.py --selftest
#
# RUN AGAINST REAL DATA (after migration + backfill + generate-embedding deploy):
#   export EVAL_BEARER="<a signed-in user JWT, or the service-role key>"
#   # optional overrides:
#   export SUPABASE_URL=...   SUPABASE_ANON_KEY=...   EMBED_FUNCTION_NAME=generate-embedding
#   python3 eval/run_eval.py
#
# Stdlib only — no pip installs.
# ============================================================================
import os, sys, json, math, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://tseszaprvtvqrkfpditu.supabase.co")
ANON_KEY = os.environ.get("SUPABASE_ANON_KEY", "sb_publishable_CLawpS61QZDONSyy8ZdhTQ_rjCBLYBW")
BEARER = os.environ.get("EVAL_BEARER") or os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
EMBED_FN = os.environ.get("EMBEDDING_FUNCTION_NAME", os.environ.get("EMBED_FUNCTION_NAME", "generate-embedding"))
TOPK = 10


def cosine(a, b):
    dot = na = nb = 0.0
    for x, y in zip(a, b):
        dot += x * y; na += x * x; nb += y * y
    if na == 0 or nb == 0:
        return 0.0
    return dot / (math.sqrt(na) * math.sqrt(nb))


def parse_vec(v):
    if isinstance(v, list):
        return [float(x) for x in v]
    if isinstance(v, str):
        return [float(x) for x in v.strip().lstrip("[").rstrip("]").split(",") if x.strip() != ""]
    raise ValueError("unrecognized vector format")


def _http(url, headers, body=None):
    data = json.dumps(body).encode() if body is not None else None
    method = "POST" if body is not None else "GET"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


def embed_query(text):
    if not BEARER:
        sys.exit("Set EVAL_BEARER (a signed-in user JWT) or SUPABASE_SERVICE_ROLE_KEY "
                 "so the eval can call generate-embedding.")
    hdr = {"apikey": ANON_KEY, "Authorization": f"Bearer {BEARER}", "Content-Type": "application/json"}
    data = _http(f"{SUPABASE_URL}/functions/v1/{EMBED_FN}", hdr, {"text": text})
    if "embedding" not in data:
        sys.exit(f"generate-embedding did not return an embedding: {data}")
    return parse_vec(data["embedding"])


def fetch_listings():
    # Reads listings that have an embedding. anon sees published rows; a
    # service-role bearer sees all. Embeddings inherit row RLS (audit doc).
    hdr = {"apikey": ANON_KEY, "Authorization": f"Bearer {BEARER or ANON_KEY}"}
    url = f"{SUPABASE_URL}/rest/v1/programs?select=id,title,embedding&embedding=not.is.null"
    rows = _http(url, hdr)
    out = []
    for r in rows:
        if r.get("embedding") is None:
            continue
        out.append({"id": r["id"], "title": r.get("title"), "vec": parse_vec(r["embedding"])})
    return out


def rank(qvec, listings):
    scored = [(l["id"], cosine(qvec, l["vec"])) for l in listings]
    scored.sort(key=lambda x: -x[1])
    return [i for i, _ in scored]  # ids, best first


def evaluate(queries, listings, embed_fn):
    rows, recalls, ranks = [], [], []
    for q in queries:
        expected = set(q.get("expected_listing_ids") or [])
        order = rank(embed_fn(q["query"]), listings)
        top = set(order[:TOPK])
        if expected:
            hits = len(expected & top)
            recalls.append(hits / len(expected))
            found = [order.index(e) + 1 for e in expected if e in order]
            best = min(found) if found else None
            if best is not None:
                ranks.append(best)
        else:
            hits, best = 0, None
        rows.append({
            "query": q["query"][:40],
            "exp": len(expected),
            "hits": hits,
            "best": best,
            "recall": (hits / len(expected)) if expected else None,
        })
    return rows, recalls, ranks


def print_table(rows, recalls, ranks, n_listings):
    print(f"\nListings with embeddings: {n_listings}    Queries: {len(rows)}\n")
    print(f"{'query':42} {'#exp':>4} {'hit@10':>6} {'bestRank':>8} {'recall':>7}")
    print("-" * 72)
    for r in rows:
        rec = "n/a" if r["recall"] is None else f"{r['recall']:.2f}"
        br = "-" if r["best"] is None else str(r["best"])
        print(f"{r['query']:42} {r['exp']:>4} {r['hits']:>6} {br:>8} {rec:>7}")
    print("-" * 72)
    if recalls:
        print(f"\nrecall@10 (mean over {len(recalls)} labeled queries): {sum(recalls)/len(recalls):.3f}")
    else:
        print("\nrecall@10: n/a (no labeled queries — fill expected_listing_ids)")
    if ranks:
        print(f"mean rank (of expected hits found):       {sum(ranks)/len(ranks):.2f}")
    else:
        print("mean rank: n/a (no expected listings appeared in results)")


def selftest():
    # Deterministic synthetic data — exercises ranking + recall@10 + mean rank
    # with NO network and NO Supabase. Each query "embeds" to a target listing's
    # vector + small noise, so the target should rank #1.
    import random
    def rv(seed):
        random.seed(seed)
        return [random.gauss(0, 1) for _ in range(16)]
    listings = [{"id": f"L{i}", "title": f"listing {i}", "vec": rv(i)} for i in range(12)]

    def fake_embed(text):
        i = int(text.split("#")[1])
        random.seed(9000 + i)
        return [v + random.gauss(0, 0.05) for v in listings[i]["vec"]]

    queries = [{"query": f"find listing #{i}", "expected_listing_ids": [f"L{i}"]} for i in range(5)]
    rows, recalls, ranks = evaluate(queries, listings, fake_embed)
    print_table(rows, recalls, ranks, len(listings))
    print("\n[selftest] OK — metrics computed with no Supabase. (Real run needs the "
          "embeddings migration + backfill + generate-embedding deployed.)")


def main():
    if "--selftest" in sys.argv:
        return selftest()
    with open(os.path.join(HERE, "queries.json")) as f:
        queries = json.load(f)["queries"]
    listings = fetch_listings()
    if not listings:
        sys.exit("No listings have embeddings yet. Apply 20260627_program_embeddings.sql "
                 "and run backfill-embeddings first, then re-run.")
    rows, recalls, ranks = evaluate(queries, listings, embed_query)
    print_table(rows, recalls, ranks, len(listings))


if __name__ == "__main__":
    main()
