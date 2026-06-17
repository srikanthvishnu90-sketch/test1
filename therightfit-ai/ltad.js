/* =========================================================
   ltad.js — Age / Developmental (LTAD) gating, the SECOND gate.

   Adapted from the Next/Postgres/TS spec to Sporve's real stack
   (in-memory DRILL_DB + vanilla JS, node + browser). Two gates are
   orthogonal:
     GATE 1  age / developmental readiness — a HARD safety ceiling
             that talent can NEVER override (this file).
     GATE 2  per-skill difficulty band — talent (passes() in drills.js).

   Gate 1 runs FIRST and is independent of skill level, severity,
   priority, or talent. A more talented athlete only widens Gate 2
   (harder rungs within their stage); it can never raise the stage
   ceiling or unlock maturation-sensitive drills in Gate 1.

   Exposed as window.LTAD (browser) and module.exports (node/import).
   ========================================================= */
(function (g) {
  'use strict';

  var STAGES = ['fundamentals', 'learn_to_train', 'train_to_train', 'train_to_compete'];
  var RANK = { fundamentals: 1, learn_to_train: 2, train_to_train: 3, train_to_compete: 4 };
  // minimum age floor each stage implies (used for derivation + validation).
  // Sporve's catalog serves a few genuinely age-6 fundamentals drills, so the
  // fundamentals floor is the app's true minimum (6) rather than the spec's 7.
  var STAGE_AGE_FLOOR = { fundamentals: 6, learn_to_train: 9, train_to_train: 12, train_to_compete: 16 };

  function stageRank(s) { return RANK[s] || 1; }

  // ---- ATHLETE developmental profile (LTAD) ----
  // age:int, sex:"m"|"f"|undefined, growthSpurt: pre|during|post|unknown
  function deriveDevProfile(age, sex, growthSpurt) {
    age = Number(age) || 12;
    growthSpurt = growthSpurt || 'unknown';
    // girls mature ~1 yr earlier on average — shift the age boundaries down slightly
    var a = sex === 'f' ? age + 1 : age;
    var stage =
      a < 9 ? 'fundamentals' :
      a < 12 ? 'learn_to_train' :
      a < 16 ? 'train_to_train' :
      'train_to_compete';

    var growthSpurtActive = growthSpurt === 'during';
    // maturation-sensitive work (heavy loading, intense plyometrics) needs
    // at/post-PHV AND not mid-spurt
    var allowMaturationSensitive = !growthSpurtActive && (growthSpurt === 'post' || age >= 14);

    // during an active spurt, hold development at most at train_to_train
    if (growthSpurtActive && RANK[stage] > RANK.train_to_train) stage = 'train_to_train';

    return { stage: stage, stageRank: RANK[stage], allowMaturationSensitive: allowMaturationSensitive, growthSpurtActive: growthSpurtActive };
  }

  function sexFromGender(gender) {
    var x = String(gender || '').toLowerCase();
    if (x.indexOf('female') === 0 || x === 'f' || x === 'girl' || x === 'woman') return 'f';
    if (x.indexOf('male') === 0 || x === 'm' || x === 'boy' || x === 'man') return 'm';
    return undefined;
  }

  // ---- DRILL developmental tags ----
  // Honors explicit dev fields when present; otherwise derives SAFE, internally
  // consistent defaults from data already on the drill (age, difficulty, injury
  // cautions, supervision). Derivation is intentionally conservative so the
  // existing catalog never trips Gate 1 incorrectly.
  function stageFromMinAge(minAge) {
    return minAge >= 16 ? 'train_to_compete' :
      minAge >= 12 ? 'train_to_train' :
      minAge >= 9 ? 'learn_to_train' :
      'fundamentals';
  }
  function nameOf(drill) { return String(drill.drill_name || drill.name || '').toLowerCase(); }
  function inferImpact(drill) {
    var n = nameOf(drill);
    if (/\b(depth jump|box jump|bounding|bounds?|plyo|plyometric|reactive jump)\b/.test(n)) return 'high_plyometric';
    return 'low';   // generic "impact"/"jumping" injury tokens are NOT plyometric loading
  }
  function inferLoad(drill) {
    var n = nameOf(drill);
    // Only auto-infer heavy_max from UNAMBIGUOUS barbell strength work. "heavy" /
    // "max" alone are common coaching cues ("heavy feet", "max effort sprint")
    // and must NOT trip the load gate. light_external/moderate are never inferred
    // from keywords (they aren't gated by Gate 1 anyway) — set them explicitly.
    if (/\b(1rm|barbell|back squat|front squat|deadlift|bench press)\b/.test(n)) return 'heavy_max';
    return 'bodyweight';
  }

  // Returns the full, normalized dev-field set for a drill.
  function deriveDrillDev(drill) {
    var minAge = drill.min_age != null ? Number(drill.min_age)
      : (drill.recommended_age_min != null ? Number(drill.recommended_age_min) : 7);
    if (!(minAge >= 0)) minAge = 7;
    var ltad_stage = drill.ltad_stage || stageFromMinAge(minAge);
    var load_type = drill.load_type || inferLoad(drill);
    var impact_level = drill.impact_level || inferImpact(drill);
    var coordination_demand = drill.coordination_demand || 'low';
    var cognitive_complexity = drill.cognitive_complexity ||
      (drill.difficulty_level === 'advanced' ? 'med' : 'low');
    var maturation_sensitive = drill.maturation_sensitive != null ? !!drill.maturation_sensitive
      : (load_type === 'heavy_max' || impact_level === 'high_plyometric');
    var requires_supervision = drill.requires_supervision != null ? !!drill.requires_supervision
      : !!drill.supervision;
    // contraindications: explicit list, else pass through existing injury tokens
    var contraindications = Array.isArray(drill.contraindications) ? drill.contraindications.slice()
      : (Array.isArray(drill.injury_cautions) ? drill.injury_cautions.slice() : []);
    return {
      min_age: minAge, ltad_stage: ltad_stage, stageRank: RANK[ltad_stage] || 1,
      load_type: load_type, impact_level: impact_level,
      coordination_demand: coordination_demand, cognitive_complexity: cognitive_complexity,
      maturation_sensitive: maturation_sensitive, requires_supervision: requires_supervision,
      contraindications: contraindications
    };
  }

  // ---- GATE 1 decision (hard, talent-independent) ----
  // dev = deriveDevProfile(...); supervisionAvailable defaults true (unchanged
  // behavior for our catalog — supervised drills were never excluded before, and
  // we have no "is a coach present" intake yet). injuries: string[] body/loading tokens.
  function gate1(drill, ctx) {
    var d = drill.__dev || deriveDrillDev(drill);
    var dev = ctx.dev;
    var age = Number(ctx.age) || 12;
    var injuries = ctx.injuries || [];
    var supervisionAvailable = ctx.supervisionAvailable !== false;   // default true

    if (age < d.min_age) return false;
    if (dev.stageRank < d.stageRank) return false;
    if (d.maturation_sensitive && !dev.allowMaturationSensitive) return false;
    if (d.requires_supervision && !supervisionAvailable) return false;
    if (injuries.length && d.contraindications.some(function (c) { return injuries.indexOf(c) >= 0; })) return false;
    // during an active growth spurt, stay extra conservative regardless of age
    if (dev.growthSpurtActive && (d.impact_level === 'high_plyometric' || d.load_type === 'heavy_max')) return false;
    return true;
  }

  // ---- Import / validation consistency rules ----
  // Returns an array of violation strings ([] = clean). Tags can't contradict
  // physiology. Mirrors the spec's validate-drills rules.
  function validateDrillDev(dev) {
    var v = [];
    var rank = RANK[dev.ltad_stage] || 0;
    if (STAGES.indexOf(dev.ltad_stage) < 0) v.push('ltad_stage "' + dev.ltad_stage + '" invalid');
    if (['bodyweight', 'light_external', 'moderate', 'heavy_max'].indexOf(dev.load_type) < 0) v.push('load_type "' + dev.load_type + '" invalid');
    if (['low', 'moderate', 'high_plyometric'].indexOf(dev.impact_level) < 0) v.push('impact_level "' + dev.impact_level + '" invalid');
    if (dev.load_type === 'heavy_max' && !(dev.maturation_sensitive && dev.min_age >= 14 && rank >= RANK.train_to_train))
      v.push('heavy_max requires maturation_sensitive + min_age>=14 + stage>=train_to_train');
    if (dev.impact_level === 'high_plyometric' && !(dev.maturation_sensitive && dev.min_age >= 13 && rank >= RANK.train_to_train))
      v.push('high_plyometric requires maturation_sensitive + min_age>=13 + stage>=train_to_train');
    if (dev.ltad_stage === 'fundamentals' && !(dev.load_type === 'bodyweight' && dev.impact_level === 'low' && !dev.maturation_sensitive))
      v.push('fundamentals requires bodyweight + low impact + not maturation_sensitive');
    if (dev.cognitive_complexity === 'high' && !(dev.min_age >= 12))
      v.push('cognitive_complexity=high requires min_age>=12');
    if (dev.min_age < (STAGE_AGE_FLOOR[dev.ltad_stage] || 7))
      v.push('min_age ' + dev.min_age + ' below ' + dev.ltad_stage + ' floor ' + STAGE_AGE_FLOOR[dev.ltad_stage]);
    return v;
  }

  var API = {
    STAGES: STAGES, RANK: RANK, STAGE_AGE_FLOOR: STAGE_AGE_FLOOR,
    stageRank: stageRank, deriveDevProfile: deriveDevProfile, sexFromGender: sexFromGender,
    deriveDrillDev: deriveDrillDev, gate1: gate1, validateDrillDev: validateDrillDev
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = API;
  if (typeof window !== 'undefined') window.LTAD = API;
  g.LTAD = g.LTAD || API;
})(typeof globalThis !== 'undefined' ? globalThis : this);
