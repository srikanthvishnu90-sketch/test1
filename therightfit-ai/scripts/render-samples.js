/* =========================================================
   Sporve plan-PDF — render one sample HTML per sport (Phase 5,
   zero-dependency). Open pdf-samples/index.html (or each file) in
   a browser to visually verify all 27 sports — this is the exact
   HTML/CSS the PDF will render from. PDF bytes come when puppeteer
   is wired (Phase 6, after visual sign-off).
   Run: node scripts/render-samples.js
   ========================================================= */
const fs = require('fs');
const path = require('path');
const { SPORT_THEMES } = require('../plan-pdf/themes.js');
const { buildHtml } = require('../plan-pdf/template.js');
const { sampleDoc } = require('../plan-pdf/sampleDoc.js');

const out = path.join(__dirname, '..', 'pdf-samples');
fs.mkdirSync(out, { recursive: true });

const ids = Object.keys(SPORT_THEMES);
ids.forEach(id => {
  const html = buildHtml(sampleDoc(id), SPORT_THEMES[id]);
  fs.writeFileSync(path.join(out, id + '.html'), html);
});

// simple index for eyeballing
const links = ids.map(id =>
  `<li><a href="${id}.html">${id}</a> <span style="display:inline-block;width:14px;height:14px;border-radius:3px;background:${SPORT_THEMES[id].accent};vertical-align:middle"></span></li>`).join('');
fs.writeFileSync(path.join(out, 'index.html'),
  `<!doctype html><meta charset="utf-8"><title>Sporve plan-PDF samples</title>`
  + `<body style="font-family:system-ui;padding:32px;max-width:640px"><h1>Plan-PDF samples — ${ids.length} sports</h1>`
  + `<p>Each opens the exact 7-page HTML the PDF renders from. Print to PDF (Cmd+P) to preview the document.</p><ul style="line-height:2">${links}</ul></body>`);

// ---- multi-sport sample (Addendum Part B): soccer anchor + basketball secondary ----
const { fromPlanJson } = require('../plan-pdf/fromPlanJson.js');
const alloc = { anchorSportId: 'soccer', baseSessions: 2, baseTheme: ['aerobic_capacity', 'repeated_sprint'], interference: false,
  skill: [{ sportId: 'soccer', sessions: 2, mode: 'sharpen' }, { sportId: 'basketball', sessions: 1, mode: 'maintenance' }] };
const D = (id, name, cat, notes) => ({ id, drill_name: name, skill_category: cat, coaching_notes: notes || '', estimated_duration_minutes: 12, difficulty_level: 'intermediate' });
const wk = [
  { day: 1, dayName: 'Mon', focus: 'Soccer — Finishing', sportLabel: 'Soccer', total: 75, drills: [{ d: D('a', 'Driven Finishing', 'Finishing', 'Plant and strike through the ball.'), sets: '4×6' }, { d: D('b', '1v1 to Goal', 'Attacking'), sets: '6 reps' }] },
  { day: 2, dayName: 'Tue', focus: 'Basketball — Shooting', sportLabel: 'Basketball', total: 60, drills: [{ d: D('c', 'Off-Dribble Pull-Up', 'Shooting', 'Square up on the gather.'), sets: '5×10' }] },
  { day: 3, dayName: 'Wed', focus: 'Shared Athletic Base', crossover: true, total: 55, drills: [{ d: D('d', 'Tempo Intervals', 'Conditioning'), sets: '6×200m' }] },
  { day: 4, dayName: 'Thu', focus: 'Soccer — Passing', sportLabel: 'Soccer', total: 70, drills: [{ d: D('e', 'Switch-Play Rondo', 'Passing'), sets: '4×4min' }] },
  { day: 5, dayName: 'Fri', focus: 'Shared Athletic Base', crossover: true, total: 50, drills: [{ d: D('f', 'Lower-Body Power', 'Strength'), sets: '4×4' }] },
  { day: 6, dayName: 'Sat', focus: 'Recovery & Mobility', recovery: true, total: 25, drills: [{ d: D('g', 'Mobility Flow', 'Mobility'), sets: '1–2 rounds' }] },
];
const plan = { week: wk, focus: ['Soccer: Finishing', 'Basketball: Shooting'], multiSport: true, sports: ['Soccer', 'Basketball'], allocation: alloc, eligibleCount: 30 };
const prof = { age: 15, level: 'intermediate', weaknesses: ['Finishing', 'Off-dribble shooting', 'Pacing'], dayCount: 6, minutes: 65, mainGoal: 'Make varsity', sport: 'soccer', sports: ['soccer', 'basketball'], sportMeta: { soccer: { season: 'in_season', weeks: '2' }, basketball: { season: 'off_season' } } };
const labelFn = (k) => ({ soccer: 'Soccer', basketball: 'Basketball' }[k] || k);
const multiDoc = fromPlanJson(plan, prof, { labelFn, name: 'Sample Athlete', weeks: 12 });
fs.writeFileSync(path.join(out, '_multi-soccer-basketball.html'), buildHtml(multiDoc, SPORT_THEMES[multiDoc.sportId]));

console.log('Rendered ' + ids.length + ' sample HTML files + 1 multi-sport → pdf-samples/');
console.log('Sports:', ids.join(', '));
