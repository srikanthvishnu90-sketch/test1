#!/usr/bin/env python3
# ============================================================================
# eval/gen_eval.py — DEV-ONLY generator for the hybrid-pipeline eval.
# Emits a deterministic seed catalog (eval/seed.sql) and 50 labeled queries
# (eval/queries.json) with HARD constraints (price/age/radius). Re-run to
# regenerate. Stdlib only. NOT part of the app.
#
#   python3 eval/gen_eval.py
# ============================================================================
import os, json

HERE = os.path.dirname(os.path.abspath(__file__))
CHI = (41.88, -87.63)  # Chicago origin used by every query

# topic index -> the descriptive cluster the embedding encodes (one-hot dim).
TOPICS = [
    "basketball-youth-beginner", "basketball-competitive", "soccer-youth-beginner",
    "soccer-goalkeeping", "tennis-youth", "speed-agility", "volleyball",
]

# listing: (label, title, topic, sport, price, age_min, age_max, lat, lng, rating, reviews, bio, [review texts])
L = [
 ("lh","Little Hoops",0,"Basketball",60,6,10,41.90,-87.65,4.8,140,
   "Patient, encouraging coaching that builds fundamentals and confidence for young first-time players.",
   ["So patient with my 7 year old beginner.","Focuses on the basics and keeps it fun."]),
 ("jb","Junior Ballers Intro",0,"Basketball",75,7,11,41.86,-87.61,4.6,60,
   "Intro basketball skills — dribbling, passing and teamwork for new players.",
   ["Great first basketball experience for kids."]),
 ("eg","Elite Guard Academy",1,"Basketball",180,12,17,41.89,-87.64,4.9,210,
   "High-performance guard development for competitive and travel players.",
   ["Took my son's game to the next level for tryouts."]),
 ("tt","Travel Team Prep",1,"Basketball",150,13,18,41.95,-87.70,4.7,95,
   "Tryout and travel-team preparation; intense, competitive small groups.",
   ["Serious training for serious players."]),
 ("fk","First Kicks Soccer",2,"Soccer",50,5,9,41.88,-87.62,4.7,120,
   "Beginner soccer for little ones — ball control basics in a playful setting.",
   ["Perfect intro to soccer for my 6 year old."]),
 ("ss","Soccer Starters",2,"Soccer",65,6,10,41.84,-87.66,4.5,40,
   "Foundational soccer skills and small-sided games for new young players.",
   ["Friendly coaches, good for beginners."]),
 ("ka","Keeper Academy",3,"Soccer",90,10,16,41.92,-87.69,4.8,80,
   "Goalkeeper-specific training: positioning, shot-stopping and distribution.",
   ["Best keeper coaching in the area.","My daughter's positioning improved a lot."]),
 ("la","Little Aces Tennis",4,"Tennis",70,6,12,41.87,-87.60,4.6,90,
   "Fun introductory tennis for young children — rallying and footwork basics.",
   ["Kids love it; great for first-timers."]),
 ("jt","Junior Tennis Dev",4,"Tennis",85,8,14,41.95,-87.74,4.7,55,
   "Developmental tennis: strokes, footwork and match basics for juniors.",
   ["Solid stroke development program."]),
 ("sa","Speed & Agility Lab",5,"Conditioning",80,12,18,41.90,-87.66,4.5,70,
   "Speed, agility and athletic conditioning for teen multi-sport athletes.",
   ["Noticeably faster after a few weeks."]),
 ("ac","Athlete Conditioning",5,"Conditioning",70,11,17,42.20,-87.95,4.4,35,
   "Strength, speed and agility for older youth athletes (northern suburbs).",
   ["Good conditioning work."]),
 ("vb","Volley Skills Camp",6,"Volleyball",55,10,15,41.83,-87.64,4.6,50,
   "Volleyball fundamentals — passing, setting and serving for middle schoolers.",
   ["Great skills camp for our middle schooler."]),
]

def uid(lab, p):  # deterministic uuid per listing+role (stable across runs)
    import hashlib
    h = hashlib.md5(f"{lab}:{p}".encode()).hexdigest()
    return f"{h[0:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:32]}"

def vec(topic):  # 1536-d one-hot at the topic dim
    a = ["0"] * 1536; a[topic] = "1"
    return "[" + ",".join(a) + "]"

def haversine(lat, lng):
    import math
    la1, lo1, la2, lo2 = map(math.radians, (CHI[0], CHI[1], lat, lng))
    d = math.acos(min(1, max(-1, math.cos(la1)*math.cos(la2)*math.cos(lo2-lo1)+math.sin(la1)*math.sin(la2))))
    return 3959 * d

def emit_seed():
    out = ["begin;"]
    for (lab,title,topic,sport,price,amin,amax,lat,lng,rating,nrev,bio,revs) in L:
        pv, pg, sid = uid(lab,"a"), uid(lab,"b"), uid(lab,"c")
        out.append(f"insert into providers(id,owner_id,bio,latitude,longitude) values ('{pv}',null,$b${bio}$b$,{lat},{lng});")
        out.append("insert into programs(id,provider_id,title,description,sport_type,skill_level,whats_included,price,"
                   "minimum_age,maximum_age,status,average_rating,total_reviews,latitude,longitude,embedding) values "
                   f"('{pg}','{pv}',$t${title}$t$,$d${bio}$d$,'{sport}','All levels','{{drills,games}}',{price},{amin},{amax},"
                   f"'published',{rating},{nrev},{lat},{lng},'{vec(topic)}');")
        out.append(f"insert into sessions(id,program_id,start_date,capacity) values ('{sid}','{pg}',current_date+5,10);")
        for i, rv in enumerate(revs):
            out.append(f"insert into reviews(program_id,rating,body,created_at) values ('{pg}',5,$r${rv}$r$,now()-interval '{i} day');")
    out.append("commit;")
    open(os.path.join(HERE, "seed.sql"), "w").write("\n".join(out) + "\n")

def catalog():
    return [{"label": l[0], "id": uid(l[0], "b"), "topic": l[2], "sport": l[3],
             "price": l[4], "amin": l[5], "amax": l[6], "dist": round(haversine(l[7], l[8]), 1)} for l in L]

# Query templates per topic: realistic, DISTINCT NL phrasings (~50 total).
QTPL = {
 0: ["beginner basketball for my {age} year old to learn the basics",
     "fun intro hoops near me for a young first-timer",
     "patient basketball coach for kids just starting out",
     "where can my {age} year old learn basketball fundamentals",
     "youth basketball for an absolute beginner",
     "first-time basketball lessons for a young child",
     "easygoing hoops program to build my kid's confidence",
     "introductory basketball skills for a {age} year old",
     "gentle basketball coaching for a nervous beginner"],
 1: ["competitive basketball training for tryout prep",
     "advanced travel-team basketball for my {age} year old",
     "serious guard development for a competitive player",
     "elite basketball coaching to make the travel team",
     "intense hoops training for a high-level {age} year old",
     "skills training for an experienced competitive player"],
 2: ["beginner soccer for my {age} year old to learn ball control",
     "intro soccer for little kids near me",
     "fun first soccer lessons for a young child",
     "where to start soccer for a {age} year old beginner",
     "playful soccer basics for little ones",
     "learn-to-play soccer for a young first-timer",
     "introductory soccer dribbling for a {age} year old",
     "starter soccer sessions for a little kid"],
 3: ["goalkeeper training and positioning drills",
     "soccer keeper coaching for my {age} year old",
     "goalie-specific soccer training near me",
     "shot-stopping and distribution coaching for a keeper",
     "soccer goalkeeping development for a {age} year old"],
 4: ["fun tennis lessons for young children",
     "junior tennis development for my {age} year old",
     "intro tennis rallying and footwork for kids",
     "where can a {age} year old start tennis",
     "beginner-friendly youth tennis program",
     "learn tennis strokes and footwork for juniors",
     "starter tennis classes for a {age} year old"],
 5: ["speed and agility training for a teen athlete",
     "conditioning and quickness for my {age} year old",
     "athletic speed work for older youth",
     "agility and acceleration training for a teen",
     "off-season conditioning for a {age} year old athlete",
     "explosiveness and footwork training for teens",
     "sprint and quickness coaching for a teen athlete"],
 6: ["volleyball skills camp for middle schoolers",
     "learn volleyball passing and setting for my {age} year old",
     "youth volleyball fundamentals near me",
     "serving and passing volleyball clinic for a {age} year old",
     "beginner volleyball for a middle schooler",
     "intro volleyball training for a {age} year old"],
}

def passes(c, item):
    if c.get("sport") and item["sport"].lower() != c["sport"].lower(): return False
    if c.get("max_price") is not None and item["price"] > c["max_price"]: return False
    if c.get("radius_miles") is not None and item["dist"] > c["radius_miles"]: return False
    a = c.get("athlete_age")
    if a is not None and not (item["amin"] <= a <= item["amax"]): return False
    return True

def emit_queries():
    cat = catalog()
    sport_of = {0:"Basketball",1:"Basketball",2:"Soccer",3:"Soccer",4:"Tennis",5:"Conditioning",6:"Volleyball"}
    ages = {0:8,1:14,2:7,3:12,4:9,5:15,6:12}
    # constraint variations to spread difficulty
    variants = [
        {"max_price": 100, "radius_miles": 25},
        {"max_price": 80,  "radius_miles": 25},
        {"max_price": 80,  "radius_miles": 10},
        {"max_price": 200, "radius_miles": 25},
        {"max_price": 60,  "radius_miles": 25},
        {"max_price": 100, "radius_miles": 5},
        {"max_price": 40,  "radius_miles": 25},  # over-constrained -> relax path
    ]
    qs = []
    seen = set()
    vi = 0
    for topic, tpls in QTPL.items():
        for tpl in tpls:
            v = variants[vi % len(variants)]; vi += 1
            age = ages[topic]
            c = {"sport": sport_of[topic], "athlete_age": age,
                 "max_price": v["max_price"], "radius_miles": v["radius_miles"],
                 "lat": CHI[0], "lng": CHI[1]}
            text = tpl.format(age=age)
            if text in seen:
                continue
            seen.add(text)
            exp = [it["id"] for it in cat if it["topic"] == topic and passes(c, it)]
            qs.append({"query": text, "topic": topic, "constraints": c,
                       "expected_listing_ids": exp,
                       "notes": f"topic={TOPICS[topic]}; cap=${v['max_price']} r={v['radius_miles']}mi"})
    payload = {"_comment": ["DEV-ONLY hybrid-pipeline eval set (NOT used by the app).",
        "Each entry: {query, topic, constraints, expected_listing_ids, notes}.",
        "constraints are the ground-truth parse (price/age/radius/sport/lat/lng); the runner",
        "feeds them to search_listings. topic selects the controlled query embedding offline.",
        "expected_listing_ids = catalog listings in the topic that SATISFY the hard constraints."],
        "queries": qs}
    json.dump(payload, open(os.path.join(HERE, "queries.json"), "w"), indent=2)
    return cat, qs

if __name__ == "__main__":
    emit_seed()
    cat, qs = emit_queries()
    labeled = sum(1 for q in qs if q["expected_listing_ids"])
    print(f"wrote seed.sql ({len(L)} listings) and queries.json ({len(qs)} queries, {labeled} with labels)")
