#!/usr/bin/env node
/* =========================================================
   scripts/import-drills.js — validate + seed per-sport drill JSON.
   Reads data/drills/<sport>.json, validates each drill against the
   sport's skill taxonomy (SPORT_META in drills.js), applies the
   coach_reviewed youth-safety gate, maps to the engine drill schema,
   and regenerates drills.imported.js (merged into DRILL_DB at runtime).
   Run: npm run import-drills
   ========================================================= */
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const LTAD = require('../ltad.js');   // age/developmental gating (Gate 1)

const ROOT = path.join(__dirname, '..');
const DRILLS_DIR = path.join(ROOT, 'data', 'drills');
const OUT = path.join(ROOT, 'drills.imported.js');

// ---- load the skill taxonomy (SPORT_META) from drills.js in a sandbox ----
function loadSportMeta() {
  const src = fs.readFileSync(path.join(ROOT, 'drills.js'), 'utf8');
  const ctx = {
    window: {}, document: { querySelectorAll: () => [], getElementById: () => null, addEventListener: () => {} },
    state: { data: {} }, matchMedia: () => ({ matches: false }), navigator: {},
    console: { log: () => {}, warn: () => {}, error: () => {} },
  };
  vm.createContext(ctx);
  vm.runInContext(src + ';globalThis.__SPORT_META = (typeof SPORT_META!=="undefined")?SPORT_META:null;', ctx);
  return ctx.__SPORT_META || {};
}

const SPORT_META = loadSportMeta();
const AGE = { u10: [7, 10], u12: [8, 12], u14: [11, 14], u16: [13, 16], u18: [14, 18], teen: [11, 18], adv: [13, 18], adult: [16, 18], all: [7, 18] };
const slug = (s) => String(s).toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
const diffLevel = (d) => (d <= 2 ? 'beginner' : d === 3 ? 'intermediate' : 'advanced');
function findSkill(sport, name) {
  const skills = (SPORT_META[sport] && SPORT_META[sport].skills) || [];
  const n = String(name || '').toLowerCase().trim();
  return skills.find((s) => s.toLowerCase() === n) || null;   // canonical casing or null
}

let live = [], rejected = 0, pending = 0, dupes = 0;
const seenIds = new Set();
const report = [];

const files = fs.existsSync(DRILLS_DIR) ? fs.readdirSync(DRILLS_DIR).filter((f) => f.endsWith('.json')) : [];
for (const file of files) {
  let data;
  try { data = JSON.parse(fs.readFileSync(path.join(DRILLS_DIR, file), 'utf8')); }
  catch (e) { report.push(`✗ ${file}: invalid JSON — ${e.message}`); continue; }
  const sport = data.sport;
  const drills = Array.isArray(data.drills) ? data.drills : [];
  let fLive = 0, fRej = 0, fPend = 0;

  if (!SPORT_META[sport]) {
    report.push(`✗ ${file}: sport "${sport}" has no SPORT_META registry entry (add skills/positions/goals first). ${drills.length} drill(s) skipped.`);
    rejected += drills.length; continue;
  }

  drills.forEach((d, i) => {
    const where = `${file}#${i + 1} "${d && d.name || '?'}"`;
    // required fields
    if (!d || !d.name || !d.instructions || !d.primary_skill || d.difficulty == null || !d.age_band) {
      report.push(`✗ ${where}: missing required field (name, instructions, primary_skill, difficulty, age_band).`); fRej++; rejected++; return;
    }
    const skill = findSkill(sport, d.primary_skill);
    if (!skill) {
      report.push(`✗ ${where}: primary_skill "${d.primary_skill}" not in ${sport} taxonomy [${(SPORT_META[sport].skills || []).join(', ')}].`); fRej++; rejected++; return;
    }
    const diff = Number(d.difficulty);
    if (!(diff >= 1 && diff <= 5)) { report.push(`✗ ${where}: difficulty must be 1–5.`); fRej++; rejected++; return; }
    if (!AGE[d.age_band]) { report.push(`✗ ${where}: age_band "${d.age_band}" invalid.`); fRej++; rejected++; return; }
    // youth-safety gate
    if (d.coach_reviewed !== true) { fPend++; pending++; return; }
    // dedupe: same name → same id; skip repeats (e.g. re-pasted batches)
    const id = sport + '_' + slug(d.name);
    if (seenIds.has(id)) { report.push(`↺ ${where}: duplicate of an already-imported drill — skipped.`); dupes++; return; }
    seenIds.add(id);

    // secondary_skills: keep only taxonomy-valid ones
    const secondary = (Array.isArray(d.secondary_skills) ? d.secondary_skills : [])
      .map((s) => findSkill(sport, s)).filter(Boolean);
    const [amin, amax] = AGE[d.age_band];
    const reps = d.reps_target || '';
    // ---- GATE 1: developmental tags. Honor explicit fields, else derive safe
    //      defaults from age/difficulty/injury/supervision. Then validate that
    //      the tags don't contradict physiology; a violation rejects the drill.
    const devSrc = {
      drill_name: d.name, difficulty_level: diffLevel(diff), recommended_age_min: amin,
      equipment: Array.isArray(d.equipment) ? d.equipment : [],
      injury_cautions: Array.isArray(d.contraindications) ? d.contraindications : [],
      supervision: !!d.supervision,
      min_age: d.min_age, ltad_stage: d.ltad_stage, load_type: d.load_type,
      impact_level: d.impact_level, coordination_demand: d.coordination_demand,
      cognitive_complexity: d.cognitive_complexity, maturation_sensitive: d.maturation_sensitive,
      requires_supervision: d.requires_supervision, contraindications: d.contraindications,
    };
    const dev = LTAD.deriveDrillDev(devSrc);
    const devViolations = LTAD.validateDrillDev(dev);
    if (devViolations.length) {
      report.push(`✗ ${where}: developmental tags contradict physiology — ${devViolations.join('; ')}.`);
      fRej++; rejected++; seenIds.delete(id); return;
    }
    live.push({
      id: id, sport,
      drill_name: d.name, skill_category: skill, area: skill,
      secondary_skills: secondary, best_for: [skill].concat(secondary),
      difficulty_level: diffLevel(diff), progression_level: diff,
      estimated_duration_minutes: Number(d.duration) || 8,
      how_to: d.instructions, statistic: d.statistic || '', pga: d.pga || '',
      coaching_notes: d.coaching_notes || '', mistakes: Array.isArray(d.mistakes) ? d.mistakes : [], safety: d.safety || '',
      benchmarks: reps ? { beginner: reps, intermediate: reps, advanced: reps } : null,
      progression_option: d.progression || '', regression_option: d.regression || '',
      positions: Array.isArray(d.positions) && d.positions.length ? d.positions : ['unknown'],
      recommended_age_min: amin, recommended_age_max: amax,
      injury_cautions: [],
      // engine eligibility fields: don't gate imported drills on equipment (an athlete
      // won't list "targets"); keep equipment informational for display/PDF.
      required_equipment: [], space_required: d.space_needed || 'any', wallok: false,
      equipment: Array.isArray(d.equipment) ? d.equipment : [],
      supervision: !!d.supervision,
      reps_target: reps, space_needed: d.space_needed || '', video_url: d.video_url || null, diagram_url: d.diagram_url || null,
      // GATE 1 developmental tags (validated above)
      min_age: dev.min_age, ltad_stage: dev.ltad_stage, load_type: dev.load_type,
      impact_level: dev.impact_level, coordination_demand: dev.coordination_demand,
      cognitive_complexity: dev.cognitive_complexity, maturation_sensitive: dev.maturation_sensitive,
      requires_supervision: dev.requires_supervision, contraindications: dev.contraindications,
      __dev: dev,
      imported: true,
    });
    fLive++;
  });
  report.push(`• ${file} (${sport}): ${fLive} live, ${fPend} pending review, ${fRej} rejected`);
}

const banner = '/* AUTO-GENERATED by scripts/import-drills.js — do not edit by hand.\n   Run `npm run import-drills` after editing data/drills/<sport>.json. */\n';
const body = '(function (g) {\n  var IMPORTED_DRILLS = ' + JSON.stringify(live, null, 0) + ';\n'
  + '  g.IMPORTED_DRILLS = IMPORTED_DRILLS;\n  if (typeof module !== "undefined" && module.exports) module.exports = IMPORTED_DRILLS;\n})(typeof window !== "undefined" ? window : globalThis);\n';
fs.writeFileSync(OUT, banner + body);

console.log('\nSporve drill import');
console.log('-------------------');
report.forEach((r) => console.log(r));
console.log('-------------------');
console.log(`LIVE (written): ${live.length}   pending review: ${pending}   duplicates skipped: ${dupes}   rejected: ${rejected}`);
const bySport = {};
live.forEach((d) => { bySport[d.sport] = (bySport[d.sport] || 0) + 1; });
console.log('Imported live per sport:', JSON.stringify(bySport));
console.log('→ wrote', path.relative(ROOT, OUT));
