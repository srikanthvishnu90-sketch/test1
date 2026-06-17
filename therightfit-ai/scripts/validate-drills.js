#!/usr/bin/env node
/* =========================================================
   scripts/validate-drills.js — standalone developmental-tag audit.
   Loads the full live DRILL_DB (base arrays + IMPORTED_DRILLS),
   derives/normalizes each drill's Gate-1 developmental tags, and
   reports any that contradict physiology (the same consistency rules
   the importer enforces). Run: node scripts/validate-drills.js
   ========================================================= */
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const LTAD = require('../ltad.js');

const ROOT = path.join(__dirname, '..');
const ctx = {
  window: {}, document: { querySelectorAll: () => [], getElementById: () => null, addEventListener: () => {} },
  state: { data: {} }, matchMedia: () => ({ matches: false }), navigator: {},
  console: { log() {}, warn() {}, error() {} }, LTAD,
};
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(ROOT, 'drills.imported.js'), 'utf8'), ctx);
vm.runInContext(fs.readFileSync(path.join(ROOT, 'drills.js'), 'utf8') + ';globalThis.__DB=(typeof DRILL_DB!=="undefined")?DRILL_DB:[];', ctx);
const DB = ctx.__DB || [];

let bad = 0, reviewed = 0;
const byStage = {};
DB.forEach((d) => {
  const dev = LTAD.deriveDrillDev(d);
  byStage[dev.ltad_stage] = (byStage[dev.ltad_stage] || 0) + 1;
  if (d.coach_reviewed !== false) reviewed++;
  const v = LTAD.validateDrillDev(dev);
  if (v.length) { bad++; console.log(`✗ ${d.sport}/${d.drill_name || d.id}: ${v.join('; ')}`); }
});

console.log('\nLTAD developmental-tag audit');
console.log('----------------------------');
console.log('drills audited:', DB.length);
console.log('by stage:', JSON.stringify(byStage));
console.log(bad ? `✗ ${bad} drill(s) with contradictory tags` : '✓ all drills have physiologically consistent developmental tags');
process.exit(bad ? 1 : 0);
