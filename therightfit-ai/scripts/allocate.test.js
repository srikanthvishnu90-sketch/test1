const A = require('../allocate.js');
let pass = 0, fail = 0;
const ok = (cond, msg) => { if (cond) { pass++; } else { fail++; console.log('  ✗ FAIL:', msg); } };
const av = (over) => Object.assign({ daysPerWeek: 5, sessionMinutes: 60, age: 16, level: 'intermediate', injuries: [], equipment: [] }, over);
const sp = (id, rank, season, extra) => Object.assign({ sportId: id, priorityRank: rank, season, sportMetrics: {}, struggleTags: [] }, extra || {});

// AC1 — single sport: anchor self, base + all skill, no interference
let r = A.allocate({ availability: av({ daysPerWeek: 4 }), sports: [sp('soccer', 1, 'in_season')] });
ok(r.anchorSportId === 'soccer', 'AC1 anchor=soccer');
ok(r.interference === false, 'AC1 no interference');
ok(r.skill.length === 1 && r.skill[0].sessions === (4 - r.baseSessions), 'AC1 all non-base skill to the one sport');
ok(r.baseSessions + r.skill.reduce((a, s) => a + s.sessions, 0) === 4, 'AC1 sum==D');

// AC2 — soccer(P1,in) + basketball(P2,off), D=5 → base2, soccer2, bball1, anchor soccer, no interference
r = A.allocate({ availability: av({ daysPerWeek: 5 }), sports: [sp('soccer', 1, 'in_season'), sp('basketball', 2, 'off_season')] });
const soc = r.skill.find(s => s.sportId === 'soccer'), bb = r.skill.find(s => s.sportId === 'basketball');
ok(r.baseSessions === 2, 'AC2 base==2 (got ' + r.baseSessions + ')');
ok(soc.sessions === 2, 'AC2 soccer skill==2 (got ' + soc.sessions + ')');
ok(bb.sessions === 1, 'AC2 basketball skill==1 (got ' + bb.sessions + ')');
ok(r.anchorSportId === 'soccer', 'AC2 anchor==soccer');
ok(r.interference === false, 'AC2 no interference');

// AC3 — distance_running(P1,in) + powerlifting(P2,off): interference, PL→maintenance, base→running,
//        and schedule never places opposing axes consecutively
r = A.allocate({ availability: av({ daysPerWeek: 5 }), sports: [sp('distance_running', 1, 'in_season'), sp('powerlifting', 2, 'off_season')] });
ok(r.interference === true, 'AC3 interference==true');
ok(r.skill.find(s => s.sportId === 'powerlifting').mode === 'maintenance', 'AC3 powerlifting→maintenance');
ok(r.anchorSportId === 'distance_running', 'AC3 anchor==running');
ok(r.baseTheme.some(q => ['aerobic_capacity', 'running_economy', 'durability'].includes(q)), 'AC3 base biased to running');
const wk = A.scheduleWeek(r);
const train = wk.filter(d => d.type !== 'rest');
let adjBad = false;
for (let i = 1; i < train.length; i++) if (A._internal.isOpp(train[i - 1].axis, train[i].axis)) adjBad = true;
ok(!adjBad, 'AC3 scheduler: no opposing axes on consecutive TRAINING days');

// AC4 — sums + rest across a range of D
for (const D of [2, 3, 4, 5, 6, 7]) {
  const rr = A.allocate({ availability: av({ daysPerWeek: D }), sports: [sp('soccer', 1, 'pre_season'), sp('basketball', 2, 'off_season')] });
  const sum = rr.baseSessions + rr.skill.reduce((a, s) => a + s.sessions, 0);
  ok(sum === D, 'AC4 D=' + D + ' Σ==D (got ' + sum + ')');
  ok(rr.restDays === 7 - D, 'AC4 D=' + D + ' restDays');
}

// AC6 — every active sport ≥1 skill when D-base >= count
r = A.allocate({ availability: av({ daysPerWeek: 6 }), sports: [sp('soccer', 1, 'off_season'), sp('basketball', 2, 'off_season'), sp('tennis', 3, 'off_season')] });
ok(r.skill.every(s => s.sessions >= 1), 'AC6 3 sports/6 days: each ≥1 skill');

// AC8/highIntensityCap by age
ok(A.allocate({ availability: av({ age: 12 }), sports: [sp('soccer', 1, 'off_season')] }).highIntensityCap === 2, 'cap age<14 ==2');
ok(A.allocate({ availability: av({ age: 16 }), sports: [sp('soccer', 1, 'off_season')] }).highIntensityCap === 3, 'cap age<18 ==3');
ok(A.allocate({ availability: av({ age: 20, level: 'advanced' }), sports: [sp('soccer', 1, 'off_season')] }).highIntensityCap === 4, 'cap adult adv ==4');

// EDGE — 3 sports, 3 days
r = A.allocate({ availability: av({ daysPerWeek: 3 }), sports: [sp('soccer', 1, 'off_season'), sp('basketball', 2, 'off_season'), sp('tennis', 3, 'off_season')] });
ok(r.baseSessions === 1, 'EDGE 3sport/3day base==1');
ok(r.baseSessions + r.skill.reduce((a, s) => a + s.sessions, 0) === 3, 'EDGE 3sport/3day Σ==3');
ok(r.appliedRules.some(x => /maintenance-level/.test(x)), 'EDGE 3sport/3day warns maintenance-level');

// EDGE — no sport in-season → anchor = highest priority, all development
r = A.allocate({ availability: av(), sports: [sp('basketball', 2, 'off_season'), sp('soccer', 1, 'off_season')] });
ok(r.anchorSportId === 'soccer', 'EDGE off-season anchor=highest priority');
ok(r.skill.every(s => s.mode === 'development'), 'EDGE off-season all development');

console.log('\nRESULT: ' + pass + ' passed, ' + fail + ' failed');
process.exit(fail ? 1 : 0);
