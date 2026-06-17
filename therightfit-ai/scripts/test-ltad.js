#!/usr/bin/env node
/* =========================================================
   scripts/test-ltad.js — acceptance tests for the two-gate system.
   Verifies Gate 1 (age/developmental) is a hard ceiling that talent,
   skill, severity, or priority can never override. Run: node scripts/test-ltad.js
   ========================================================= */
const LTAD = require('../ltad.js');

let pass = 0, fail = 0;
function ok(name, cond) { if (cond) { pass++; console.log('✓', name); } else { fail++; console.log('✗', name); } }

// synthetic drills with explicit dev tags (validated as physiologically consistent)
const fundamentals = { drill_name: 'Form Hold', recommended_age_min: 7, difficulty_level: 'beginner' };
const trainToCompete = { drill_name: 'Comp Set', min_age: 16, ltad_stage: 'train_to_compete', load_type: 'bodyweight', impact_level: 'low', difficulty_level: 'advanced' };
const heavyMax = { drill_name: 'Back Squat 1RM', min_age: 16, ltad_stage: 'train_to_compete', load_type: 'heavy_max', impact_level: 'low', maturation_sensitive: true, difficulty_level: 'advanced' };
const plyo = { drill_name: 'Depth Jump', min_age: 14, ltad_stage: 'train_to_train', impact_level: 'high_plyometric', maturation_sensitive: true, difficulty_level: 'intermediate' };
const kneeDrill = { drill_name: 'Cutting Finish', recommended_age_min: 9, difficulty_level: 'beginner', contraindications: ['knee'] };
const supDrill = { drill_name: 'Live Tackle', recommended_age_min: 12, difficulty_level: 'beginner', requires_supervision: true };

// helper: highly skilled 10-year-old (talent maxed via skill, but age fixed)
const tenYO = { dev: LTAD.deriveDevProfile(10, 'm', 'unknown'), age: 10, injuries: [] };
const fifteenSpurt = { dev: LTAD.deriveDevProfile(15, 'm', 'during'), age: 15, injuries: [] };
const sixteenPost = { dev: LTAD.deriveDevProfile(16, 'm', 'post'), age: 16, injuries: [] };
const injuredKnee = { dev: LTAD.deriveDevProfile(12, 'm', 'unknown'), age: 12, injuries: ['knee'] };

// 1. highly skilled 10yo NEVER gets train_to_compete / heavy_max / maturation_sensitive
ok('10yo blocked from train_to_compete', !LTAD.gate1(trainToCompete, tenYO));
ok('10yo blocked from heavy_max', !LTAD.gate1(heavyMax, tenYO));
ok('10yo blocked from high_plyometric (maturation_sensitive)', !LTAD.gate1(plyo, tenYO));
ok('10yo allowed fundamentals drill', LTAD.gate1(fundamentals, tenYO));

// 2. Gate 1 is independent of skill — talent does not appear in gate1() at all
ok('gate1 signature ignores skill/severity/priority', LTAD.gate1.length === 2);

// 3. growth_spurt='during' excludes high_plyometric & heavy_max even for a 15yo
ok('15yo mid-spurt blocked from high_plyometric', !LTAD.gate1(plyo, fifteenSpurt));
ok('15yo mid-spurt blocked from heavy_max', !LTAD.gate1(heavyMax, fifteenSpurt));
// ...but a post-spurt 16yo CAN do maturation-sensitive work
ok('16yo post-spurt allowed heavy_max', LTAD.gate1(heavyMax, sixteenPost));
ok('16yo post-spurt allowed high_plyometric', LTAD.gate1(plyo, sixteenPost));

// 4. contraindications ∩ injuries ⇒ excluded
ok('knee-injured athlete blocked from knee-contraindicated drill', !LTAD.gate1(kneeDrill, injuredKnee));
ok('uninjured athlete allowed the same drill', LTAD.gate1(kneeDrill, { dev: LTAD.deriveDevProfile(12), age: 12, injuries: [] }));

// 5. supervision gate (default available = unchanged behavior)
ok('supervised drill excluded when supervision unavailable', !LTAD.gate1(supDrill, { dev: LTAD.deriveDevProfile(12), age: 12, injuries: [], supervisionAvailable: false }));
ok('supervised drill allowed by default', LTAD.gate1(supDrill, { dev: LTAD.deriveDevProfile(12), age: 12, injuries: [] }));

// 6. validation rejects contradictions
ok('heavy_max without maturation_sensitive is rejected', LTAD.validateDrillDev(LTAD.deriveDrillDev({ min_age: 16, ltad_stage: 'train_to_compete', load_type: 'heavy_max', maturation_sensitive: false })).length > 0);
ok('fundamentals with high impact is rejected', LTAD.validateDrillDev(LTAD.deriveDrillDev({ min_age: 7, ltad_stage: 'fundamentals', impact_level: 'high_plyometric' })).length > 0);
ok('clean derived beginner drill validates', LTAD.validateDrillDev(LTAD.deriveDrillDev(fundamentals)).length === 0);

// 7. within the age-eligible pool, talent still selects difficulty band (Gate 2 lives in passes()).
//    Here we just confirm Gate 1 lets an age-appropriate compete-stage athlete through.
ok('16yo allowed train_to_compete drill', LTAD.gate1(trainToCompete, sixteenPost));

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
