import json, uuid, random

random.seed(42)  # deterministic (Math.random-free requirement is for workflows; this is a local script)

CHI_LAT, CHI_LNG = 41.8781, -87.6298

def jq(s):  # single-quote escape for SQL
    return s.replace("'", "''")

def pgarray(items):
    return "ARRAY[" + ",".join("'" + jq(x) + "'" for x in items) + "]::text[]"

# tier meaning: 0 play, 1 fundamentals, 2 intro-competitive, 3 competitive, 4 elite
SPORTS = {
  "Basketball": {
    "cred": ["USA Basketball Gold License", "CPR/First Aid"],
    "included": ["Skill drills", "Scrimmage play", "Film review"],
    "coaches": [
      ("Marcus Bell","Northside Hoops Academy","Former D1 guard coaching youth fundamentals for 9 years. Patient, development-first.",1,"beginner",6,10,["skill development","fun","fundamentals"],["group","clinic"],65,4.8,52,9,12),
      ("Deja Coleman","Lakeview Basketball Lab","Skills trainer focused on ball-handling and shooting mechanics for developing players.",2,"intermediate",10,14,["skill development","confidence"],["private","group"],80,4.9,71,7,11),
      ("Andre Fox","West Loop Elite Guards","Competitive guard development, footwork and IQ for players eyeing select teams.",3,"advanced",13,17,["competitive play","college recruiting"],["private","team"],110,4.7,44,12,15),
      ("Tanya Reed","Little Dribblers Chicago","Intro basketball for young kids — coordination, teamwork, and joy of the game.",1,"beginner",6,9,["fun","coordination","teamwork"],["group","clinic"],55,4.6,38,6,8),
      ("Chris Nunez","South Side Court Kings","All-levels skills clinics with a strong beginner-to-intermediate pathway.",2,"intermediate",11,15,["skill development","fitness"],["group","camp"],70,4.5,29,8,10),
    ]},
  "Soccer": {
    "cred": ["USSF D License", "CPR/First Aid"],
    "included": ["Technical drills", "Small-sided games", "Fitness"],
    "coaches": [
      ("Sofia Marin","Windy City Futbol","Grassroots coach building first-touch and confidence in young players.",1,"beginner",6,10,["skill development","fun"],["group","clinic"],60,4.8,63,8,10),
      ("Liam O'Connor","Riverside United Training","Possession-based development for intermediate players; small-group focused.",2,"intermediate",10,14,["skill development","teamwork"],["group","team"],75,4.7,49,10,12),
      ("Paulo Ferreira","Chicago Select Soccer","Competitive academy prep — technical and tactical for aspiring club players.",3,"advanced",13,17,["competitive play","college recruiting"],["team","private"],105,4.9,58,14,16),
      ("Grace Kim","Tiny Toes FC","Playful intro soccer for the littlest players. Movement, smiles, first goals.",1,"beginner",6,8,["fun","coordination"],["group"],50,4.6,41,5,7),
      ("Diego Santos","Halsted Street Strikers","Finishing and 1v1 attacking skills for developing forwards.",2,"intermediate",11,15,["skill development","confidence"],["private","group"],85,4.5,33,9,11),
    ]},
  "Baseball": {
    "cred": ["USA Baseball Coach Cert", "CPR/First Aid"],
    "included": ["Hitting drills", "Fielding work", "Bullpen"],
    "coaches": [
      ("Ray Whitaker","Diamond Prospects Chicago","20 years developing hitters. Mechanics and mindset for youth players.",2,"intermediate",10,14,["skill development","hitting"],["private","group"],90,4.8,55,20,18),
      ("Mike Delgado","Northwest Little Sluggers","Tee-ball to coach-pitch fundamentals in a supportive setting.",1,"beginner",6,9,["fun","fundamentals"],["group","clinic"],55,4.7,47,8,10),
      ("Jenna Pope","Lakefront Pitching Lab","Pitching biomechanics and arm care for developing pitchers.",3,"advanced",13,17,["competitive play","pitching"],["private"],120,4.9,39,11,14),
      ("Carlos Rivera","South Loop Baseball Club","Well-rounded skills camps for the intermediate age group.",2,"intermediate",11,15,["skill development","teamwork"],["camp","group"],70,4.5,31,10,12),
      ("Tommy Nash","First Base Beginners","Gentle intro to baseball — catching, throwing, running the bases.",1,"beginner",7,10,["fun","coordination"],["group","clinic"],50,4.6,26,6,9),
    ]},
  "Tennis": {
    "cred": ["USPTA Certified", "CPR/First Aid"],
    "included": ["Stroke technique", "Footwork", "Match play"],
    "coaches": [
      ("Elena Petrova","Grand Slam Juniors","Technical foundation for beginners — grips, rally consistency, fun.",1,"beginner",6,10,["skill development","fun"],["private","group"],75,4.8,44,12,16),
      ("Ben Carter","Lincoln Park Tennis Academy","Intermediate development: consistency, spin, and point construction.",2,"intermediate",10,14,["skill development","confidence"],["private","group"],95,4.7,51,9,13),
      ("Priya Nair","Chicago Tennis Elite","Competitive junior program — UTR growth and tournament prep.",3,"advanced",13,17,["competitive play","college recruiting"],["private","clinic"],130,4.9,37,10,15),
      ("Sam Whitfield","Little Aces Tennis","Red-ball intro tennis for young kids. Coordination and first rallies.",1,"beginner",6,9,["fun","coordination"],["group","clinic"],60,4.6,33,7,10),
      ("Nora Haddad","Uptown Baseline Club","Groundstroke and footwork clinics for the developing intermediate.",2,"intermediate",11,15,["skill development","fitness"],["group","camp"],85,4.5,28,8,11),
    ]},
}

REVIEW_BODIES = [
  "My daughter improved so much and actually looks forward to every session.",
  "Patient, encouraging, and clearly knows how to teach kids. Highly recommend.",
  "Great structure and communication. We saw real progress in a few weeks.",
  "Coach makes it fun while still pushing the kids to get better.",
  "Well organized sessions and a genuinely caring approach. Worth every penny.",
  "My son gained a ton of confidence. The small-group focus really helps.",
]

stmts = []
stmts.append("-- Idempotent: clear any prior demo data (cascades profiles/providers/programs/sessions/reviews).")
stmts.append("delete from auth.users where email like '%@sporve-demo.app';")

idx = 0
for sport, cfg in SPORTS.items():
    for (name, biz, bio, tier, skill, amin, amax, goals, stypes, price, rating, reviews, yc, yp) in cfg["coaches"]:
        idx += 1
        uid = str(uuid.uuid4())
        pid = str(uuid.uuid4())
        slug = name.lower().replace(" ", ".").replace("'", "")
        email = f"{slug}@sporve-demo.app"
        # jitter Chicago coords
        lat = round(CHI_LAT + random.uniform(-0.12, 0.12), 6)
        lng = round(CHI_LNG + random.uniform(-0.12, 0.12), 6)
        typical = json.dumps({"age_min": amin, "age_max": amax, "skill_level": skill, "goals": goals})

        # 1. auth user -> trigger creates profiles + providers
        stmts.append(f"""insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, confirmation_token, recovery_token, email_change_token_new, email_change)
values ('00000000-0000-0000-0000-000000000000','{uid}','authenticated','authenticated','{email}', extensions.crypt('SporveDemo!123', extensions.gen_salt('bf')), now(), now(), now(), '{{"provider":"email","providers":["email"]}}'::jsonb, '{{"name":"{jq(name)}","role":"provider"}}'::jsonb, '', '', '', '') on conflict do nothing;""")

        # 2. enrich the provider row (service-role path -> can set verified/approved)
        stmts.append(f"""update public.providers set business_name='{jq(biz)}', bio='{jq(bio)}', sports={pgarray([sport])}, location='Chicago, IL', latitude={lat}, longitude={lng}, status='approved', onboarding_completed=true, verification_status='verified', background_check_status='verified', account_status='active', coach_years_coaching={yc}, coach_years_played={yp}, credentials={pgarray(cfg['cred'])} where owner_id='{uid}';""")

        # 3. program (all gate columns) — explicit id so sessions/reviews can attach
        stmts.append(f"""insert into public.programs (id, provider_id, title, description, sport_type, skill_level, age_group, whats_included, price, currency, pricing_model, max_capacity, latitude, longitude, city, state, country, minimum_age, maximum_age, status, average_rating, total_reviews, intensity_tier, typical_client, session_types)
select '{pid}', pv.id, '{jq(biz + " — " + sport + " Training")}', '{jq(bio)}', '{sport}', '{skill}', '{amin}-{amax} yrs', {pgarray(cfg['included'])}, {price}, 'USD', 'single_session', 12, {lat}, {lng}, 'Chicago', 'IL', 'USA', {amin}, {amax}, 'published', {rating}, {reviews}, {tier}, '{typical}'::jsonb, {pgarray(stypes)}
from public.providers pv where pv.owner_id='{uid}';""")

        # 4. future-dated bookable sessions (8 over next ~4 weeks), capacity open
        stmts.append(f"""insert into public.sessions (program_id, title, start_date, start_time, timezone, address, capacity)
select '{pid}', '{jq(sport + " Session")}', (current_date + (g*3 + 2))::date, '05:00 PM', 'America/Chicago', 'Chicago, IL', 10
from generate_series(0,7) g;""")

        # 5. a few reviews (bodies) — author_id null is allowed
        chosen = random.sample(REVIEW_BODIES, 3)
        rvals = ",".join(f"('{pid}', {random.choice([4,5,5,5])}, '{jq(b)}')" for b in chosen)
        stmts.append(f"""insert into public.reviews (program_id, rating, body) values {rvals};""")

# 6. make the market genuinely ready + belt-and-suspenders override
stmts.append("update public.market_readiness_config set min_active_listings=4, min_review_signals=10 where id=true;")
for sport in SPORTS:
    for s in (sport, sport.lower()):
        stmts.append(f"insert into public.market_overrides (sport, metro, force_ready, note) values ('{jq(s)}','chicago,il', true, 'demo seed') on conflict (sport, metro) do update set force_ready=true, note='demo seed';")

sql = "\n".join(stmts)
open("/private/tmp/claude-501/-Users-vishnusrikanth-SportsMan-main/b57cdb48-e714-4fe9-92ec-03f0969d3eef/scratchpad/seed_full.sql","w").write(sql)
print(f"providers: {idx}, statements: {len(stmts)}, bytes: {len(sql)}")
