/* =========================================================
   Athlon — branching guided onboarding wizard
   Flow: Get Started → Choose Path → Assessment →
         AI Recommendation → Select Sport/Persona → Training Plan
   ========================================================= */

const STORE_KEY = 'trf_v2';

/* ---------- single source of truth for pricing ---------- */
const PRICING = { report: 29, monthly: 14.99, annual: 125 };
PRICING.annualMonthly = (PRICING.annual / 12).toFixed(2);
PRICING.savePct = Math.round((1 - PRICING.annual / (PRICING.monthly * 12)) * 100);
function fmtMoney(n) { return Number.isInteger(n) ? '$' + n : '$' + n.toFixed(2); }

/* ---------- state ---------- */
function freshData() {
  return {
    // shared
    name: '', age: '', height: '', weight: '',
    goals: [],
    // Path A — chosen sport (drill-library plan)
    sportsChosen: [], mainSport: '', sportMeta: {}, gender: '', position: '', dominantFoot: '', dominantHand: '', throwingHand: '', battingSide: '', secondaryPosition: '', skillLevel: '', experienceYears: '',
    mainGoal: '', weaknesses: [], strengths: [], struggleText: '', goalTimeline: '', tryout: '',
    // secondary-sport profile (only used when two sports are selected)
    position2: '', skillLevel2: '', experienceYears2: '', mainGoal2: '', weaknesses2: [], strengths2: [],
    equipment: [], space: '', environment: '', availability: '', sessionMinutes: '',
    competitionLevel: '', injuryHistory: '', goalDuration: '',
    // baseline fitness test inputs (optional) — drive objective weakness detection
    bl_sprint: '', bl_agility: '', bl_vertical: '', bl_broad: '', bl_run: '',
    bl_pushups: '', bl_plank: '', bl_balance: '', bl_sitreach: '', bl_skill: '',
    // Path B — persona
    athleticBackground: '',
    power: 5, endurance: 5, coordination: 5, teamwork: 5, competitiveness: 5,
    timeCommitment: '', budget: '', interests: []
  };
}
function loadState() {
  try {
    const raw = localStorage.getItem(STORE_KEY);
    if (raw) {
      const s = JSON.parse(raw);
      return { path: s.path || null, stepIndex: 0, data: { ...freshData(), ...(s.data || {}) }, chosenPersona: s.chosenPersona || null };
    }
  } catch (e) {}
  return { path: null, stepIndex: 0, data: freshData(), chosenPersona: null };
}
let state = loadState();
const data = () => state.data;
function save() {
  try { localStorage.setItem(STORE_KEY, JSON.stringify({ path: state.path, data: state.data, chosenPersona: state.chosenPersona })); } catch (e) {}
}

/* ---------- DOM ---------- */
const landing = document.getElementById('landing');
const choose = document.getElementById('choose');
const topbar = document.querySelector('.topbar');
const wizard = document.querySelector('.wizard');
const host = document.getElementById('stepHost');
const prevBtn = document.getElementById('prevBtn');
const nextBtn = document.getElementById('nextBtn');
const progressFill = document.getElementById('progressFill');
const progressLabel = document.getElementById('progressLabel');
const progressPct = document.getElementById('progressPct');
const getStartedBtn = document.getElementById('getStartedBtn');

/* =========================================================
   Small helpers
   ========================================================= */
function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
function cap(s) { return String(s).charAt(0).toUpperCase() + String(s).slice(1); }
function esc(s) { return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;'); }
function listify(arr) {
  arr = arr.filter(Boolean);
  if (!arr.length) return '';
  if (arr.length === 1) return arr[0];
  if (arr.length === 2) return arr[0] + ' and ' + arr[1];
  return arr.slice(0, -1).join(', ') + ', and ' + arr[arr.length - 1];
}
function setError(key, msg) {
  const el = host.querySelector(`[data-error="${key}"]`);
  if (el) el.textContent = msg;
}
// Sport-scoped answers (position, goals, weaknesses…) belong to one sport's
// category set. When the primary sport changes we must drop them, or a plan
// can be built from another sport's categories. See resetSportScopedFields use.
function resetSportScopedFields() {
  const d = data();
  d.position = ''; d.mainGoal = ''; d.weaknesses = []; d.strengths = []; d.dominantFoot = '';
  d.throwingHand = ''; d.battingSide = ''; d.secondaryPosition = ''; d.dominantHand = '';
}

/* ---- field builders (rendered fresh each step, state-aware) ---- */
function numField(id, ph) {
  const v = (data()[id] !== '' && data()[id] != null) ? ` value="${data()[id]}"` : '';
  return `<input type="number" id="${id}" placeholder="${esc(ph)}" aria-label="${esc(ph)}" inputmode="numeric"${v} />`;
}
function txtField(id, ph) {
  const v = (data()[id] !== '' && data()[id] != null) ? ` value="${esc(data()[id])}"` : '';
  return `<input type="text" id="${id}" placeholder="${esc(ph)}" aria-label="${esc(ph)}" autocomplete="off"${v} />`;
}
function chipGroup(key, opts, { multi = false, max = 0 } = {}) {
  const maxAttr = max ? ` data-max="${max}"` : '';
  const body = opts.map(o => {
    const val = typeof o === 'string' ? o : (o.v != null ? o.v : o.l);
    const label = typeof o === 'string' ? o : o.l;
    const soon = typeof o === 'object' && o.soon;
    const sel = multi ? (data()[key] || []).includes(val) : data()[key] === val;
    // KINETIK sport-picker: per-sport accent card (the one multi-accent screen).
    // Keeps .chip + data-value + aria-pressed + data-soon so behavior is unchanged.
    if (key === 'sportsChosen') {
      const sk = (typeof mapSport === 'function') ? mapSport(val) : null;
      const c = (sk && typeof SPORT_ACCENT !== 'undefined' && SPORT_ACCENT[sk]) ? SPORT_ACCENT[sk].d : '';
      const ghost = esc(String(label).trim().charAt(0).toUpperCase());
      return `<button type="button" class="chip chip--sport${sel ? ' selected' : ''}${soon ? ' chip--soon' : ''}"`
        + `${soon ? ' data-soon="1" aria-disabled="true"' : ''} aria-pressed="${sel}" data-value="${esc(val)}"${c ? ` style="--c:${c}"` : ''}>`
        + `<span class="chip--sport__ghost" aria-hidden="true">${ghost}</span>`
        + `<span class="chip--sport__dot" aria-hidden="true"></span>`
        + `<span class="chip--sport__label">${esc(label)}</span>`
        + (soon ? '<span class="chip__soon">Soon</span>' : '')
        + `</button>`;
    }
    if (soon) return `<button type="button" class="chip chip--soon" data-soon="1" aria-disabled="true" data-value="${esc(val)}">${esc(label)}<span class="chip__soon">Soon</span></button>`;
    return `<button type="button" class="chip${sel ? ' selected' : ''}" aria-pressed="${sel}" data-value="${esc(val)}">${esc(label)}</button>`;
  }).join('');
  return `<div class="chip-select" data-chips="${key}" data-multi="${multi}"${maxAttr}>${body}</div>`;
}
// Per-sport season + weeks-to-competition capture (multi-sport only). Drives the
// allocation engine's modes: in-season ≤3 weeks → sharpen; in-season → maintenance;
// off/pre-season → develop. Stored in data().sportMeta keyed by sport KEY.
const SEASON_OPTS = [['in_season', 'In-season'], ['pre_season', 'Pre-season'], ['off_season', 'Off-season'], ['maintenance', 'Maintenance']];
function sportMetaBlock() {
  const chosen = data().sportsChosen || [];
  if (chosen.length < 2) return '';
  data().sportMeta = data().sportMeta || {};
  const rows = chosen.map(label => {
    const sk = (typeof mapSport === 'function') ? mapSport(label) : label;
    if (!sk) return '';
    const meta = data().sportMeta[sk] || { season: 'off_season', weeks: '' };
    data().sportMeta[sk] = meta;
    const seasonChips = SEASON_OPTS.map(([v, l]) =>
      `<button type="button" class="chip${meta.season === v ? ' selected' : ''}" data-season="${sk}" data-v="${v}" aria-pressed="${meta.season === v}">${esc(l)}</button>`).join('');
    const weeks = `<label class="sportmeta__weeks${meta.season === 'in_season' ? '' : ' is-hidden'}" data-weeks-for="${sk}">`
      + `<span>Weeks to competition</span>`
      + `<input type="number" min="0" max="52" inputmode="numeric" data-weeksinput="${sk}" value="${meta.weeks != null ? esc(String(meta.weeks)) : ''}" placeholder="e.g. 6" /></label>`;
    const tag = data().mainSport === label ? '<span class="sportmeta__tag">Primary</span>' : '';
    return `<div class="sportmeta__row"><div class="sportmeta__name">${esc(label)}${tag}</div>`
      + `<div class="seg sportmeta__seasons">${seasonChips}</div>${weeks}</div>`;
  }).join('');
  return field('Season &amp; timing per sport', `<div class="sportmeta">${rows}</div>`, { opt: '(drives sharpen vs maintenance)' });
}
function sliderBlock(rows) {
  return `<div class="sliders">` + rows.map(r => {
    const v = data()[r.key] != null ? data()[r.key] : 5;
    return `<label class="slider"><span>${esc(r.label)}</span>` +
      `<input type="range" min="${r.min || 1}" max="${r.max || 10}" value="${v}" data-range="${r.key}" />` +
      `<b data-out="${r.key}">${v}</b></label>`;
  }).join('') + `</div>`;
}
// Dual-sport context for the wizard (only meaningful when two sports are chosen).
function dualInfo() {
  const dual = (data().sportsChosen || []).length >= 2;
  const mainName = data().mainSport || data().sportsChosen[0] || '';
  const secName = dual ? (data().sportsChosen.find(s => s !== mainName) || data().sportsChosen[1]) : '';
  const key2 = (dual && typeof secondarySportKey === 'function') ? secondarySportKey() : null;
  return { dual, mainName, secName, key2 };
}
function dualDivider(label) { return `<div class="dual-divider"><span>${esc(label)}</span></div>`; }
function field(label, control, { opt = '', errKey = '' } = {}) {
  const optHtml = opt ? ` <em class="field__opt">${esc(opt)}</em>` : '';
  const err = errKey ? `<span class="field__error" data-error="${errKey}"></span>` : '';
  return `<div class="field"><span class="field__label">${esc(label)}${optHtml}</span>${control}${err}</div>`;
}

// Baseline-test step — renders the optional fitness test inputs from assessment.js.
// Numbers entered here are turned into age/sex percentiles and used to DERIVE the
// athlete's weaknesses objectively (see assessment.js → assessBaseline).
function baselineStepBody() {
  const tests = (typeof window !== 'undefined' && window.BASELINE_TESTS) || [];
  if (!tests.length) {
    return `<p class="field-note">Baseline testing is loading — you can continue and add tests later.</p>`;
  }
  const sportKey = (typeof getSportKey === 'function') ? getSportKey() : '';
  const skill = ((typeof window !== 'undefined' && window.SPORT_SKILL_TESTS) || {})[sportKey];
  const card = t => field(`${t.label} (${t.unit})`, numField(t.id, t.ph), { opt: t.how });
  let html = `<p class="field-note"><b>All optional.</b> Enter any tests you can measure at home — the more you add, the more precisely we target your weak spots. Best-of-two for sprints and jumps.</p>`;
  html += `<div class="field-grid bl-grid">` + tests.map(card).join('') + `</div>`;
  if (skill) {
    html += dualDivider('Sport skill test') +
      field(`${skill.label} (${skill.unit})`, numField('bl_skill', skill.ph), { opt: skill.how });
  }
  return html;
}

/* =========================================================
   Option pools
   ========================================================= */
// Go-live gate: a sport is selectable only once it has a credible drill library
// (matches DRILL_DB coverage). Others are "coming soon — notify me" (demand signal).
const SPORTS = [
  { l: 'Basketball' }, { l: 'Soccer' }, { l: 'Football' }, { l: 'Baseball/Softball' },
  { l: 'Golf' }, { l: 'Volleyball' }, { l: 'Tennis' }, { l: 'Lacrosse' },
  { l: 'Swimming' }, { l: 'Track & Field' },
  { l: 'Wrestling', soon: true }, { l: 'Cross Country', soon: true },
];
const GOALS = ['Make the school team', 'Improve speed', 'Build strength', 'Improve confidence', 'Prepare for tryouts', 'Become more competitive'];
const PERSONA_GOALS = [...GOALS, 'Build stamina', 'Find a sport I love'];
const INTERESTS = ['Team sports', 'Individual sports', 'Outdoors', 'Water', 'Combat / contact', 'Endurance / distance', 'Precision & skill', 'Explosive / power', 'Strategy'];

const SPORT_DRILLS = {
  'Basketball': ['Form shooting & free-throw reps', 'Ball-handling cone series', 'Defensive slide ladder', '3-on-3 small-sided games'],
  'Soccer': ['First-touch & passing rondos', 'Dribbling slalom course', 'Shooting reps with both feet', 'Small-sided 4v4 games'],
  'Volleyball': ['Serving accuracy targets', 'Passing & platform control', 'Approach & spike timing', 'Blocking footwork'],
  'Track & Field': ['Sprint mechanics (A/B skips)', 'Block-start practice', 'Stride-out repeats', 'Event-specific technique'],
  'Baseball/Softball': ['Tee & soft-toss hitting', 'Fielding ground balls', 'Throwing-accuracy ladder', 'Base-running reads'],
  'Swimming': ['Stroke-technique drills', 'Kick sets', 'Interval pace sets', 'Flip-turn practice'],
  'Football': ['Footwork ladder & cuts', 'Position-specific reps', 'Catching & ball security', '7-on-7 situational play'],
  'Tennis': ['Groundstroke consistency rallies', 'Serve-placement reps', 'Split-step footwork drills', 'Point-play patterns'],
  'Wrestling': ['Stance & motion drilling', 'Takedown entries', 'Sprawl & defense reps', 'Live situational rounds'],
  'Cross Country': ['Easy aerobic miles', 'Tempo runs', 'Hill repeats', 'Stride mechanics'],
  'Distance running': ['Easy aerobic miles', 'Tempo runs', 'Hill repeats', 'Stride mechanics'],
  'Sprints (Track)': ['Sprint mechanics (A/B skips)', 'Block-start practice', 'Acceleration repeats', 'Top-speed flys']
};
function drillsFor(sport) {
  return SPORT_DRILLS[sport] || ['Sport-specific skill reps', 'Coordination & footwork drills', 'Game / competition simulation', 'Technique refinement with feedback'];
}

/* =========================================================
   Personas (Path B)
   ========================================================= */
const DIM_LABEL = { power: 'Explosive power', endurance: 'Endurance & stamina', coordination: 'Coordination & skill', teamwork: 'Team play & IQ', comp: 'Competitive drive' };
const INTEREST_BOOST = {
  'Team sports': 'teamwork', 'Individual sports': 'coordination', 'Outdoors': 'endurance', 'Water': 'endurance',
  'Combat / contact': 'power', 'Endurance / distance': 'endurance', 'Precision & skill': 'coordination',
  'Explosive / power': 'power', 'Strategy': 'teamwork'
};
const PERSONAS = [
  { id: 'explosive', name: 'The Explosive Competitor', tagline: 'Power, speed, and the will to win.',
    dims: { power: 1, endurance: .3, coordination: .5, teamwork: .4, comp: .9 },
    sports: ['Basketball', 'Football', 'Sprints (Track)', 'Volleyball'],
    env: 'High-intensity, competitive training with clear winners and measurable PRs.',
    devStyle: 'Short explosive sessions — sprints, plyometrics, and strength with full recovery.',
    goals: ['Improve speed', 'Build strength', 'Become more competitive'] },
  { id: 'endurance', name: 'The Endurance Builder', tagline: 'A relentless motor that outlasts everyone.',
    dims: { power: .3, endurance: 1, coordination: .4, teamwork: .4, comp: .6 },
    sports: ['Distance running', 'Soccer', 'Swimming', 'Cross Country'],
    env: 'Volume-based, consistent training that rewards discipline and steady progress.',
    devStyle: 'Progressive aerobic base, tempo work, and durability conditioning.',
    goals: ['Build stamina', 'Improve confidence', 'Make the school team'] },
  { id: 'technical', name: 'The Technical Skill Developer', tagline: 'Precision, touch, and craft.',
    dims: { power: .4, endurance: .4, coordination: 1, teamwork: .5, comp: .6 },
    sports: ['Tennis', 'Baseball/Softball', 'Volleyball', 'Soccer'],
    env: 'Rep-based, feedback-rich coaching focused on technique and consistency.',
    devStyle: 'Skill drills, coordination work, and deliberate practice with film/feedback.',
    goals: ['Prepare for tryouts', 'Improve confidence', 'Make the school team'] },
  { id: 'strategist', name: 'The Team Strategist', tagline: 'Reads the game and lifts the whole group.',
    dims: { power: .5, endurance: .6, coordination: .6, teamwork: 1, comp: .7 },
    sports: ['Soccer', 'Basketball', 'Volleyball', 'Football'],
    env: 'Team practices with defined roles, communication, and game-situation reps.',
    devStyle: 'Game IQ, positioning, conditioning, and small-sided competitive play.',
    goals: ['Make the school team', 'Improve confidence', 'Become more competitive'] },
  { id: 'allaround', name: 'The All-Around Athlete', tagline: 'Balanced, adaptable, and multi-sport ready.',
    dims: { power: .6, endurance: .6, coordination: .6, teamwork: .6, comp: .6 },
    sports: ['Track & Field', 'Soccer', 'Basketball', 'Swimming'],
    env: 'Varied training that develops every quality without early specialization.',
    devStyle: 'Well-rounded development — strength, speed, skill, and mobility in balance.',
    goals: ['Improve confidence', 'Build strength', 'Find a sport I love'] }
];
function computePersonas() {
  const d = data();
  const v = {
    power: (d.power || 5) / 10, endurance: (d.endurance || 5) / 10,
    coordination: (d.coordination || 5) / 10, teamwork: (d.teamwork || 5) / 10,
    comp: (d.competitiveness || 5) / 10
  };
  (d.interests || []).forEach(i => { const b = INTEREST_BOOST[i]; if (b) v[b] = Math.min(1, v[b] + 0.12); });
  const topTrait = DIM_LABEL[Object.entries(v).sort((a, b) => b[1] - a[1])[0][0]];

  const scored = PERSONAS.map(p => {
    let num = 0, den = 0;
    for (const k in p.dims) { num += p.dims[k] * v[k]; den += p.dims[k]; }
    const fit = clamp(Math.round(38 + (num / den) * 56), 35, 96);
    const strengths = Object.entries(p.dims).sort((a, b) => b[1] - a[1]).slice(0, 3).map(([k]) => DIM_LABEL[k]);
    return { ...p, fit, strengths };
  }).sort((a, b) => b.fit - a.fit).slice(0, 3);

  const goalSrc = (d.goals && d.goals.length) ? d.goals : scored[0].goals;
  const goalsList = listify(goalSrc.slice(0, 2).map(g => g.toLowerCase()));
  scored.forEach(p => {
    p.why = `Your ${topTrait.toLowerCase()} is a defining trait, and with ${goalsList} as a focus, ` +
      `${p.name.replace(/^The /, 'the ')} turns that into a clear direction — built around ${p.sports.slice(0, 2).join(' and ')}.`;
  });
  return scored;
}
function personaById(id) { return computePersonas().find(p => p.id === id) || computePersonas()[0]; }

/* =========================================================
   Training-plan generator
   ========================================================= */
const DAY_NAMES = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const ROTATION = [
  { f: 'Skill & technique', d: 'Sport drills + light footwork' },
  { f: 'Strength', d: 'Full-body strength scaled to age & level' },
  { f: 'Speed & conditioning', d: 'Sprints / intervals + agility' },
  { f: 'Skill + small-sided play', d: 'Apply skills in game situations' },
  { f: 'Active recovery & mobility', d: 'Mobility, stretching, light movement' },
  { f: 'Competition / scrimmage', d: 'Compete to test your progress' }
];
function sessionsFromTime(t) { return ({ '1–3 hrs/wk': 2, '4–6 hrs/wk': 3, '7–10 hrs/wk': 4, '10+ hrs/wk': 5 })[t] || 3; }
function levelFromBackground(b) { return ({ 'New to sports': 'Beginner', 'Recreational': 'Developing', 'Plays regularly': 'Intermediate', 'Competitive': 'Advanced', 'Multi-sport': 'Advanced' })[b] || 'Developing'; }

const GOAL_BENCH = {
  'Make the school team': 'Meet the team’s baseline fitness and skill standards in a mock evaluation.',
  'Improve speed': 'Cut measurable time off a 20-yard sprint (target ~0.1–0.2s).',
  'Build strength': 'Add reps or load to key movements (e.g., +20% on a goblet squat).',
  'Improve confidence': 'Lead a drill and complete a scrimmage without hesitation.',
  'Prepare for tryouts': 'Pass a full mock tryout, hitting position-specific standards.',
  'Become more competitive': 'Win or score in the majority of small-sided games.',
  'Build stamina': 'Sustain target pace for a longer distance/time than week one.',
  'Find a sport I love': 'Sample your top sports and commit to a favorite by plan’s end.'
};

function buildCtx() {
  const d = data();
  if (state.path === 'sport' && typeof drillCtx === 'function') return drillCtx();
  const persona = personaById(state.chosenPersona);
  return {
    path: 'persona', persona, focus: persona.sports[0],
    level: levelFromBackground(d.athleticBackground), injury: '',
    sessions: sessionsFromTime(d.timeCommitment), duration: '12 weeks',
    goals: (d.goals.length ? d.goals : persona.goals),
    age: d.age, budget: d.budget, drills: drillsFor(persona.sports[0])
  };
}
function conditioningFor(ctx) {
  const out = ['Dynamic warm-up before every session (8–10 min).'];
  const g = ctx.goals;
  if (g.includes('Improve speed') || g.includes('Become more competitive')) out.push('Sprint & plyometric work 2×/week with full rest between reps.');
  if (g.includes('Build strength')) out.push('Progressive strength training 2×/week (bodyweight → light resistance as form allows).');
  if (g.includes('Build stamina')) out.push('Aerobic base run/swim + one weekly tempo or interval session.');
  if (out.length === 1) out.push('Mixed conditioning: intervals, agility ladders, and tempo work 2×/week.');
  out.push('Finish every session with a 5-minute cooldown.');
  return out;
}
function recoveryFor(ctx) {
  const out = ['1–2 full rest or active-recovery days each week.', '8–10 hours of sleep for growth and adaptation.', 'Hydration and balanced nutrition around training.'];
  if (ctx.injury === 'Recurring' || ctx.injury === 'Currently recovering') out.unshift('Clear this plan with a doctor or physiotherapist, and modify any movement that causes pain.');
  return out;
}
function parentTipsFor(ctx) {
  const age = Number(ctx.age) || 12;
  const out = [];
  if (age <= 11) out.push('Keep it fun — prioritize play and broad skills over early specialization.');
  else if (age >= 15) out.push('Support consistency and recovery; this age can handle structured progression.');
  else out.push('Balance structured training with free play and other activities.');
  out.push('Track sessions together and celebrate small wins.', 'Watch for signs of burnout or overuse, and adjust load as needed.');
  return out;
}
function renderPlan() {
  const ctx = buildCtx();
  const d = data();
  const persona = ctx.persona;

  const schedule = DAY_NAMES.slice(0, ctx.sessions).map((day, i) => {
    const r = ROTATION[i % ROTATION.length];
    return `<div class="pweek"><span class="pweek__day">${day}</span><b>${esc(r.f)}</b><span class="pweek__d">${esc(r.d)}</span></div>`;
  }).join('');

  const benchmarks = ctx.goals.map(g => GOAL_BENCH[g] || `Show clear, measurable improvement on "${esc(g)}" from your week-1 baseline.`);
  benchmarks.push(`Re-test your baseline metrics at the midpoint and end of the ${esc(ctx.duration)} block.`);

  // trait-based strengths / growth areas, from the 1–10 sliders
  const traits = [['power', d.power], ['endurance', d.endurance], ['coordination', d.coordination], ['teamwork', d.teamwork], ['comp', d.competitiveness]]
    .map(([k, v]) => [k, Number(v) || 5]);
  const sorted = traits.slice().sort((a, b) => b[1] - a[1]);
  const strengthTraits = sorted.slice(0, 2).map(t => DIM_LABEL[t[0]]);
  const growthTraits = sorted.slice(-2).map(t => DIM_LABEL[t[0]]).reverse();

  const tag = arr => `<div class="bp__tags">${arr.map(x => `<span class="bp__tag">${esc(x)}</span>`).join('')}</div>`;

  const summary = `A ${esc(d.age || '—')}-year-old athlete · ${esc(d.height || '—')}" · ${esc(d.weight || '—')} lbs · training at a <strong>${esc(ctx.level)}</strong> level`
    + `${d.athleticBackground ? ` with a ${esc(String(d.athleticBackground).toLowerCase())} background` : ''}, ${ctx.sessions}×/week across a ${esc(ctx.duration)} block.`;

  const roadmap = [
    'Weeks 1–4 — Establish the routine, log baseline metrics, and build broad athleticism.',
    'Weeks 5–8 — Layer sport-specific skill with progressive strength and conditioning.',
    'Weeks 9–12 — Benchmark, compete, and reassess to set the next training block.'
  ];

  host.querySelector('#planBody').innerHTML = `
    <div class="bp">
      <div class="bp__head">
        <h3>${esc(persona.name)} — Personalized Report</h3>
        <span>${esc(ctx.duration)} · ${esc(ctx.level)} · ${ctx.sessions}×/week</span>
      </div>

      <div class="bp__section"><h4>Athlete summary</h4><p>${summary}</p></div>

      <div class="bp__section">
        <h4>Selected persona</h4>
        <p><strong>${esc(persona.name)}.</strong> ${esc(persona.tagline)} ${esc(persona.devStyle)}</p>
      </div>

      <div class="bp__section"><h4>Why this persona fits</h4><p>${esc(persona.why)}</p></div>

      <div class="bp__section"><h4>Best-fit sports</h4>${tag(persona.sports)}</div>

      <div class="bp__section">
        <h4>Recommended training focus</h4>
        <p>Centered on <strong>${esc(ctx.focus)}</strong>, working toward ${esc(listify((ctx.goals || []).slice(0, 3).map(g => String(g).toLowerCase())))}.</p>
        ${tag(persona.goals)}
      </div>

      <div class="bp__section bp__section--split">
        <div><h4>Strengths</h4>${tag(strengthTraits)}</div>
        <div><h4>Areas to grow</h4>${tag(growthTraits)}</div>
      </div>

      <div class="bp__section">
        <h4>Suggested weekly training plan</h4>
        <div class="plan-week">${schedule}</div>
      </div>

      <div class="bp__section">
        <h4>Skill drills</h4>
        <ul class="plan-list">${ctx.drills.map(x => `<li>${esc(x)}</li>`).join('')}</ul>
      </div>

      <div class="bp__section">
        <h4>Conditioning</h4>
        <ul class="plan-list">${conditioningFor(ctx).map(x => `<li>${esc(x)}</li>`).join('')}</ul>
      </div>

      <div class="bp__section">
        <h4>Recovery</h4>
        <ul class="plan-list">${recoveryFor(ctx).map(x => `<li>${esc(x)}</li>`).join('')}</ul>
      </div>

      <div class="bp__section">
        <h4>Progress benchmarks</h4>
        <ul class="plan-list">${benchmarks.map(x => `<li>${x}</li>`).join('')}</ul>
      </div>

      <div class="bp__section">
        <h4>Long-term development roadmap</h4>
        <ul class="plan-list">${roadmap.map(x => `<li>${esc(x)}</li>`).join('')}</ul>
      </div>

      <div class="bp__section">
        <h4>Parent recommendations</h4>
        <ul class="plan-list">${parentTipsFor(ctx).map(x => `<li>${esc(x)}</li>`).join('')}</ul>
      </div>

      <div class="bp__cta">
        <strong>Keep this plan working for your athlete</strong>
        <span>Unlock auto-progressing plans, video drills &amp; the AI advisor.</span>
        <div class="bp__price">
          <button type="button" class="btn btn--ghost" data-goresults>Download report — ${esc(fmtMoney(PRICING.report))}</button>
          <button type="button" class="btn btn--solid" data-goresults>Membership — ${esc(fmtMoney(PRICING.monthly))}/mo</button>
        </div>
      </div>
    </div>`;
}

/* =========================================================
   Persona selection rendering (Path B, step 5)
   ========================================================= */
function renderPersonas() {
  const personas = computePersonas();
  const tag = arr => `<div class="bp__tags">${arr.map(x => `<span class="bp__tag">${esc(x)}</span>`).join('')}</div>`;
  host.querySelector('#personaBody').innerHTML = personas.map(p => `
    <button type="button" class="persona-card${state.chosenPersona === p.id ? ' selected' : ''}" data-persona="${p.id}">
      <div class="persona-card__top">
        <span class="persona-card__fit">${p.fit}% match</span>
        <h3>${esc(p.name)}</h3>
        <p>${esc(p.tagline)}</p>
      </div>
      <div class="persona-card__row"><h5>Best-fit sports</h5>${tag(p.sports)}</div>
      <div class="persona-card__row"><h5>Strengths</h5>${tag(p.strengths)}</div>
      <div class="persona-card__row"><h5>Training style</h5><p>${esc(p.devStyle)}</p></div>
      <div class="persona-card__row"><h5>Recommended focus</h5>${tag(p.goals)}</div>
      <div class="persona-card__row"><h5>Ideal environment</h5><p>${esc(p.env)}</p></div>
      <div class="persona-card__why"><h5>Why this fits</h5><p>${esc(p.why)}</p></div>
      <span class="persona-card__pick">${state.chosenPersona === p.id ? 'Chosen' : 'Choose This Persona'}</span>
    </button>`).join('')
    + `<div class="persona-skip">
         <span class="persona-skip__or">Already know the sport you want?</span>
         <button type="button" class="btn btn--ghost" id="skipPersonasBtn">Skip Personas and Choose My Sport Instead →</button>
       </div>`
    + `<span class="field__error" data-error="persona"></span>`;

  const skip = host.querySelector('#skipPersonasBtn');
  if (skip) skip.addEventListener('click', () => { enterPath('sport'); });

  // KINETIK: the recommendation resolved → flood the matched (top) sport's accent in.
  try {
    const top = personas[0];
    const k = top && top.sports && top.sports.length && (typeof mapSport === 'function') && mapSport(top.sports[0]);
    if (k && typeof SPORT_ACCENT !== 'undefined' && SPORT_ACCENT[k]) {
      applyTheme(k);
      if (!state._recoFlooded && typeof floodTransition === 'function') { state._recoFlooded = true; floodTransition(() => {}); }
    }
  } catch (e) {}
}

/* =========================================================
   Flow definitions
   ========================================================= */
function validAge() {
  const checks = [
    ['age', data().age, 5, 19, 'Enter an age between 5 and 19.'],
    ['height', data().height, 36, 84, 'Enter a height in inches (36–84).'],
    ['weight', data().weight, 40, 350, 'Enter a weight in lbs (40–350).']
  ];
  let ok = true;
  checks.forEach(([id, val, min, max, msg]) => {
    const input = host.querySelector('#' + id);
    if (val === '' || val == null || isNaN(val) || !Number.isInteger(Number(val)) || val < min || val > max) {
      setError(id, msg); if (input) input.classList.add('invalid'); ok = false;
    } else { setError(id, ''); if (input) input.classList.remove('invalid'); }
  });
  return ok;
}

const FLOWS = {
  sport: [
    { accent: '#3b82f6', eyebrow: 'Your Sport', title: 'Which sport are we training for?', lead: 'Pick one — or up to two. We pull drills from the library for your sport.',
      body: () => field('Choose your sport(s)', chipGroup('sportsChosen', SPORTS, { multi: true, max: 3 }), { opt: '(1–3)', errKey: 'sportsChosen' })
        + `<p class="field-note">Full drill libraries today: <b>Basketball, Soccer, Football, Baseball/Softball, Golf, Volleyball, Tennis, Lacrosse</b>. Others use a general plan while we expand.</p>`,
      validate: () => {
        const n = data().sportsChosen.length;
        if (n < 1 || n > 3) { setError('sportsChosen', 'Select one to three sports.'); return false; }
        // default the main sport so position/goal options + the plan engine resolve correctly
        if (n >= 2) { if (!data().mainSport || !data().sportsChosen.includes(data().mainSport)) data().mainSport = data().sportsChosen[0]; }
        else { data().mainSport = data().sportsChosen[0] || ''; }
        return true;
      } },

    { accent: '#22d3ee', eyebrow: 'About the Athlete', title: 'Tell us about your athlete.', lead: 'Metrics, position, and level let us match the right drills.',
      body: () => field('Athlete name', txtField('name', 'e.g. Sam'), { opt: '(optional)' })
        + (data().sportsChosen.length >= 2
          ? field('Which is your main sport?', chipGroup('mainSport', data().sportsChosen.map(s => ({ v: s, l: s }))), { opt: '(your #1 priority — the plan is anchored to it)', errKey: 'mainSport' })
            + `<p class="field-note">You picked multiple sports — we build <b>one unified plan</b>: a shared athletic base (built once, it transfers) plus skill work allocated to each sport by priority and season.</p>`
            + sportMetaBlock()
          : '')
        + `<div class="field-grid">
          ${field('Age', numField('age', 'e.g. 12'), { errKey: 'age' })}
          ${field('Height (in)', numField('height', 'e.g. 60'), { errKey: 'height' })}
          ${field('Weight (lbs)', numField('weight', 'e.g. 110'), { errKey: 'weight' })}
        </div>`
        + field('Gender', chipGroup('gender', ['Male', 'Female', 'Prefer not to say']), { opt: '(optional)' })
        + (getSportKey() === 'soccer' ? field('Dominant foot', chipGroup('dominantFoot', ['Left', 'Right', 'Both']), { opt: '(optional)' }) : '')
        + (getSportKey() === 'volleyball' ? field('Dominant hand', chipGroup('dominantHand', ['Right', 'Left', 'Both']), { opt: '(optional)' }) : '')
        + (getSportKey() === 'baseball' ? field('Throwing hand', chipGroup('throwingHand', ['Right', 'Left']), { opt: '(optional)' })
          + field('Batting side', chipGroup('battingSide', ['Right', 'Left', 'Switch']), { opt: '(optional)' }) : '')
        + (dualInfo().dual ? dualDivider('Primary sport — ' + dualInfo().mainName) : '')
        + field('Primary position', chipGroup('position', posOptions()), { errKey: 'position' })
        + (getSportKey() === 'baseball' ? field('Secondary position', chipGroup('secondaryPosition', posOptions()), { opt: '(optional)' }) : '')
        + field('Current skill level', chipGroup('skillLevel', ['Beginner', 'Intermediate', 'Advanced']), { errKey: 'skillLevel' })
        + field('Years of experience', chipGroup('experienceYears', ['New to it', 'Under 1 year', '1-2 years', '3+ years']), { errKey: 'experienceYears' })
        + ((dualInfo().dual && dualInfo().key2) ? (
            dualDivider('Secondary sport — ' + dualInfo().secName)
            + field(dualInfo().secName + ' position', chipGroup('position2', posOptionsFor(dualInfo().key2)), { opt: '(for your secondary sport)' })
            + field(dualInfo().secName + ' skill level', chipGroup('skillLevel2', ['Beginner', 'Intermediate', 'Advanced']), { opt: '(optional)' })
            + field(dualInfo().secName + ' experience', chipGroup('experienceYears2', ['New to it', 'Under 1 year', '1-2 years', '3+ years']), { opt: '(optional)' })
          ) : ''),
      validate: () => {
        let ok = validAge();
        if (!data().position) { setError('position', 'Pick a position (Not sure is fine).'); ok = false; }
        if (!data().skillLevel) { setError('skillLevel', 'Pick a skill level.'); ok = false; }
        if (!data().experienceYears) { setError('experienceYears', 'Pick experience.'); ok = false; }
        return ok;
      } },

    { accent: '#06b6d4', eyebrow: 'Goals & Focus', title: 'What are we building toward?', lead: 'We prioritize drills that solve your goal and your weaknesses first.',
      body: () => (dualInfo().dual ? dualDivider('Primary sport — ' + dualInfo().mainName) : '')
        + field('Main goal', chipGroup('mainGoal', goalOptions()), { errKey: 'mainGoal' })
        + field('Top weaknesses', chipGroup('weaknesses', skillOptions(), { multi: true }), { opt: '(select any)', errKey: 'weaknesses' })
        + field('In their words', `<textarea id="struggleText" class="ta" rows="2" placeholder="e.g. chunks chip shots, loses the ball under pressure, gets tired late" aria-label="What are they struggling with?">${esc(data().struggleText || '')}</textarea>`, { opt: '(optional — we map this to the right drills)' })
        + field('Strengths', chipGroup('strengths', skillOptions(), { multi: true }), { opt: '(optional)' })
        + ((dualInfo().dual && dualInfo().key2) ? (
            dualDivider('Secondary sport — ' + dualInfo().secName)
            + field(dualInfo().secName + ' main goal', chipGroup('mainGoal2', goalOptionsFor(dualInfo().key2)), { opt: '(for your secondary sport)' })
            + field(dualInfo().secName + ' weaknesses', chipGroup('weaknesses2', skillOptionsFor(dualInfo().key2), { multi: true }), { opt: '(select any)' })
            + field(dualInfo().secName + ' strengths', chipGroup('strengths2', skillOptionsFor(dualInfo().key2), { multi: true }), { opt: '(optional)' })
          ) : '')
        + field('Goal timeline', chipGroup('goalTimeline', ['2 weeks', '1 month', '3 months', 'This season']), { errKey: 'goalTimeline' })
        + field('Tryout coming up?', chipGroup('tryout', ['No tryout', 'In 2 weeks', 'In 1 month', 'In 3 months']), { opt: '(optional)' }),
      validate: () => {
        let ok = true;
        if (!data().mainGoal) { setError('mainGoal', 'Pick your main goal.'); ok = false; }
        if (!data().weaknesses.length) { setError('weaknesses', 'Choose at least one weakness.'); ok = false; }
        if (!data().goalTimeline) { setError('goalTimeline', 'Pick a timeline.'); ok = false; }
        return ok;
      } },

    { accent: '#ff7a18', eyebrow: 'Setup', title: 'Where and how do you train?', lead: 'We only pick drills you can actually do with your space and gear.',
      body: () => field('Available equipment', chipGroup('equipment', equipOptions(), { multi: true }), { opt: '(select any — a ball is assumed)' })
        + field('Available space', chipGroup('space', [{ v: 'full', l: 'Full court / field' }, { v: 'half', l: 'Half court / yard' }, { v: 'small', l: 'Small space / indoors' }]), { errKey: 'space' })
        + field('Training environment', chipGroup('environment', ['Home', 'Gym', 'Team practice', 'Outdoor']), { opt: '(optional)' }),
      validate: () => { if (!data().space) { setError('space', 'Pick your available space.'); return false; } return true; } },

    { accent: '#22e58a', eyebrow: 'Schedule & Health', title: 'How much can you put in?', lead: 'This sets how many sessions, how long, and how intense.', nextLabel: 'Continue to baseline test →',
      body: () => field('Days available per week', chipGroup('availability', ['1-2 days', '3-4 days', '5-6 days', 'Daily']), { errKey: 'availability' })
        + field('Minutes per session', chipGroup('sessionMinutes', ['20 min', '30-40 min', '45-60 min', '60+ min']), { errKey: 'sessionMinutes' })
        + field('Competition level', chipGroup('competitionLevel', ['Recreational', 'School team', 'Club / travel', 'Elite']), { opt: '(optional)' })
        + field('Injury history', chipGroup('injuryHistory', ['None', 'Minor / past', 'Recurring', 'Currently recovering']), { errKey: 'injuryHistory' }),
      validate: () => {
        let ok = true;
        if (!data().availability) { setError('availability', 'Pick your training days.'); ok = false; }
        if (!data().sessionMinutes) { setError('sessionMinutes', 'Pick a session length.'); ok = false; }
        if (!data().injuryHistory) { setError('injuryHistory', 'Choose one (None is fine).'); ok = false; }
        return ok;
      } },

    { accent: '#16a34a', eyebrow: 'Baseline Test', title: 'Test yourself — so the plan targets what actually needs work.',
      lead: 'Enter any tests you can measure at home. We turn them into age-matched percentiles and automatically find your weakest areas — no guessing. Skip any you have not done; you can add them later.',
      nextLabel: 'Build my training plan →',
      body: () => baselineStepBody() },

    { accent: '#8b5cf6', eyebrow: 'Your Plan', title: 'Your personalized training plan.', lead: 'Every drill is matched from the library to your profile — and tells you why.', isResult: true, goResults: true, nextLabel: 'See my options →',
      body: () => `<div id="planBody" class="result-body"></div>`, after: () => renderDrillPlan() }
  ],

  persona: [
    { accent: '#3b82f6', eyebrow: 'Physical Profile', title: 'Let’s build your athletic profile.', lead: 'Start with the basics and your athletic background.',
      body: () => field('Athlete name', txtField('name', 'e.g. Sam'), { opt: '(optional)' })
        + `<div class="field-grid">
        ${field('Age', numField('age', 'e.g. 12'), { errKey: 'age' })}
        ${field('Height (in)', numField('height', 'e.g. 60'), { errKey: 'height' })}
        ${field('Weight (lbs)', numField('weight', 'e.g. 110'), { errKey: 'weight' })}
      </div>` + field('Athletic background', chipGroup('athleticBackground', ['New to sports', 'Recreational', 'Plays regularly', 'Competitive', 'Multi-sport']), { errKey: 'athleticBackground' }),
      validate: () => { let ok = validAge(); if (!data().athleticBackground) { setError('athleticBackground', 'Pick an athletic background.'); ok = false; } return ok; } },

    { accent: '#22d3ee', eyebrow: 'Traits', title: 'How does your athlete compete?', lead: 'Rate each from 1–10. There are no wrong answers — this shapes the personas.',
      body: () => field('Athletic traits', sliderBlock([
        { key: 'power', label: 'Explosive power' },
        { key: 'endurance', label: 'Endurance' },
        { key: 'coordination', label: 'Coordination & skill' },
        { key: 'teamwork', label: 'Team play (vs. solo)' },
        { key: 'competitiveness', label: 'Competitiveness' }
      ])) },

    { accent: '#ff7a18', eyebrow: 'Goals & Commitment', title: 'What matters most right now?', lead: 'Goals, time, and budget all factor into the recommendation.',
      body: () => field('Main goals', chipGroup('goals', PERSONA_GOALS, { multi: true }), { opt: '(select any)', errKey: 'goals' })
        + field('Weekly time commitment', chipGroup('timeCommitment', ['1–3 hrs/wk', '4–6 hrs/wk', '7–10 hrs/wk', '10+ hrs/wk']), { errKey: 'timeCommitment' })
        + field('Budget for training', chipGroup('budget', ['Free – low', 'Moderate', 'Higher']), { errKey: 'budget' }),
      validate: () => {
        let ok = true;
        if (!data().goals.length) { setError('goals', 'Choose at least one goal.'); ok = false; }
        if (!data().timeCommitment) { setError('timeCommitment', 'Pick a time commitment.'); ok = false; }
        if (!data().budget) { setError('budget', 'Pick a budget range.'); ok = false; }
        return ok;
      } },

    { accent: '#06b6d4', eyebrow: 'Interests', title: 'What does your athlete enjoy?', lead: 'Interests help us point toward sports they’ll actually love.', nextLabel: 'Generate personas →',
      body: () => field('Interests', chipGroup('interests', INTERESTS, { multi: true }), { opt: '(select any)', errKey: 'interests' }),
      validate: () => { if (!data().interests.length) { setError('interests', 'Choose at least one interest.'); return false; } return true; } },

    { accent: '#22e58a', eyebrow: 'AI Recommendation', title: 'Your top three athletic personas.', lead: 'Generated from your profile. Choose the one that fits best — or skip and pick your own sport.', isResult: true, nextLabel: 'Create My Personalized Report →',
      body: () => `<div id="personaBody" class="persona-grid-wrap"></div>`, after: renderPersonas,
      validate: () => { if (!state.chosenPersona) { setError('persona', 'Choose a persona to continue, or skip to pick your sport.'); return false; } return true; } },

    { accent: '#8b5cf6', eyebrow: 'Your Plan', title: 'Your persona-matched training plan.', lead: 'Tailored to your persona, metrics, and goals — adjust answers any time to regenerate.', isResult: true, goResults: true, nextLabel: 'See my options →',
      body: () => `<div id="planBody" class="result-body"></div>`, after: renderPlan }
  ]
};

/* =========================================================
   Generic step binding
   ========================================================= */
// Coming-soon sport → inline "notify me" capture (demand signal), no selection.
function openNotify(sport, chip) {
  let row = document.getElementById('notifyRow');
  const group = (chip && chip.closest('.chip-select')) || host;
  if (!row) { row = document.createElement('div'); row.id = 'notifyRow'; row.className = 'notify'; group.insertAdjacentElement('afterend', row); }
  row.innerHTML =
    `<p class="notify__msg"><b>${esc(sport)}</b> isn't live yet — get notified the moment it is.</p>` +
    `<form class="notify__form" id="notifyForm">` +
    `<input type="email" id="notifyEmail" placeholder="you@email.com" aria-label="Email me when ${esc(sport)} launches" required>` +
    `<button type="submit" class="btn btn--solid btn--sm">Notify me</button></form>`;
  const form = row.querySelector('#notifyForm');
  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const email = (row.querySelector('#notifyEmail').value || '').trim();
    if (!email) return;
    fetch('/api/notify', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ sport, email }) }).catch(() => {});
    if (window.track) track('notify_signup', { sport });
    row.innerHTML = `<p class="notify__msg notify__msg--ok">✓ Thanks — we'll email you the moment <b>${esc(sport)}</b> is ready.</p>`;
  });
  const inp = row.querySelector('#notifyEmail'); if (inp) inp.focus();
}

function bindStep() {
  host.querySelectorAll('input[type="number"]').forEach(el => {
    el.addEventListener('input', () => {
      data()[el.id] = el.value === '' ? '' : Number(el.value);
      el.classList.remove('invalid'); setError(el.id, ''); save();
    });
  });
  host.querySelectorAll('input[type="text"]').forEach(el => {
    el.addEventListener('input', () => {
      data()[el.id] = el.value;
      el.classList.remove('invalid'); setError(el.id, ''); save();
    });
  });
  host.querySelectorAll('textarea').forEach(el => {
    el.addEventListener('input', () => { data()[el.id] = el.value; save(); });
  });
  host.querySelectorAll('input[type="range"]').forEach(r => {
    const key = r.dataset.range;
    const out = host.querySelector(`[data-out="${key}"]`);
    r.addEventListener('input', () => { data()[key] = Number(r.value); if (out) out.textContent = r.value; save(); });
  });
  host.querySelectorAll('.chip-select').forEach(group => {
    const key = group.dataset.chips;
    const multi = group.dataset.multi === 'true';
    const max = group.dataset.max ? Number(group.dataset.max) : Infinity;
    group.querySelectorAll('.chip').forEach(chip => {
      const val = chip.dataset.value;
      chip.addEventListener('click', () => {
        if (chip.dataset.soon) { openNotify(val, chip); return; }   // coming-soon → capture demand, don't select
        if (multi) {
          const arr = data()[key];
          if (arr.includes(val)) { data()[key] = arr.filter(v => v !== val); chip.classList.remove('selected'); chip.setAttribute('aria-pressed', 'false'); }
          else {
            if (arr.length >= max) { group.classList.add('shake'); setTimeout(() => group.classList.remove('shake'), 320); return; }
            arr.push(val); chip.classList.add('selected'); chip.setAttribute('aria-pressed', 'true');
          }
        } else {
          data()[key] = val;
          group.querySelectorAll('.chip').forEach(c => { c.classList.remove('selected'); c.setAttribute('aria-pressed', 'false'); });
          chip.classList.add('selected'); chip.setAttribute('aria-pressed', 'true');
        }
        // If the primary sport changed, stale sport-scoped answers are invalid.
        if (key === 'sportsChosen' && typeof getSportKey === 'function') {
          const nk = getSportKey();
          const committed = nk && nk !== state._sportKey;     // a new sport selected
          if (nk !== state._sportKey) { resetSportScopedFields(); state._sportKey = nk; }
          // KINETIK flood transition on sport commit, then theme the app.
          if (committed && chip.classList.contains('selected') && typeof floodTransition === 'function') {
            applyTheme(nk);                                   // set accent so the flood is the sport color
            floodTransition(() => setSportTheme());
          } else { setSportTheme(); }
        }
        setError(key, ''); save();
      });
    });
  });
  // Per-sport season chips + weeks-to-competition (multi-sport allocation capture)
  host.querySelectorAll('[data-season]').forEach(btn => btn.addEventListener('click', () => {
    const sk = btn.dataset.season, v = btn.dataset.v;
    data().sportMeta = data().sportMeta || {};
    data().sportMeta[sk] = data().sportMeta[sk] || { season: 'off_season', weeks: '' };
    data().sportMeta[sk].season = v;
    host.querySelectorAll('[data-season="' + sk + '"]').forEach(b => {
      const on = b.dataset.v === v; b.classList.toggle('selected', on); b.setAttribute('aria-pressed', on);
    });
    const wk = host.querySelector('[data-weeks-for="' + sk + '"]');
    if (wk) wk.classList.toggle('is-hidden', v !== 'in_season');
    save();
  }));
  host.querySelectorAll('[data-weeksinput]').forEach(inp => inp.addEventListener('input', () => {
    const sk = inp.dataset.weeksinput;
    data().sportMeta = data().sportMeta || {};
    data().sportMeta[sk] = data().sportMeta[sk] || { season: 'off_season', weeks: '' };
    data().sportMeta[sk].weeks = inp.value;
    save();
  }));
  host.querySelectorAll('[data-persona]').forEach(card => {
    card.addEventListener('click', () => {
      state.chosenPersona = card.dataset.persona;
      host.querySelectorAll('[data-persona]').forEach(c => {
        const on = c === card;
        c.classList.toggle('selected', on);
        const pick = c.querySelector('.persona-card__pick');
        if (pick) pick.textContent = on ? 'Chosen' : 'Choose This Persona';
      });
      setError('persona', ''); save();
    });
  });
}

/* =========================================================
   Navigation / rendering
   ========================================================= */
/* =========================================================
   KINETIK accent system — black/white architecture + ONE
   propagating sport token. Each sport has a DARK variant (vivid,
   for dark surfaces / --accent) and a LIGHT variant (deepened,
   readable on white / --accent-ink). No sport → collapse to ink.
   Single source of truth: add sport #N = one row here.
   ========================================================= */
const KINETIK_INK = '#0A0A0B';
const SPORT_ACCENT = {
  basketball: { d: '#FF5A1F', l: '#E04405' }, // orange
  swimming:   { d: '#00C2D6', l: '#0091A3' }, // cyan
  golf:       { d: '#18C964', l: '#0E8F45' }, // green
  tennis:     { d: '#FFC700', l: '#A67A00' }, // yellow
  track:      { d: '#C6FF36', l: '#5E8200' }, // volt (running)
  soccer:     { d: '#2BE08A', l: '#0E8F45' }, // mint-green
  football:   { d: '#FF8A2B', l: '#C2510A' }, // amber/pigskin
  baseball:   { d: '#FF3B5C', l: '#D60E37' }, // red
  volleyball: { d: '#7C5CFF', l: '#4A2FD6' }, // violet
  lacrosse:   { d: '#FF2D9C', l: '#C2076B' }, // magenta
};

function mixHex(hex, withHex, amt) {
  const h = s => [1, 3, 5].map(i => parseInt(s.slice(i, i + 2), 16));
  const [r1, g1, b1] = h(hex), [r2, g2, b2] = h(withHex);
  const m = (a, b) => Math.round(a + (b - a) * amt).toString(16).padStart(2, '0');
  return '#' + m(r1, r2) + m(g1, g2) + m(b1, b2);
}
// Set the two propagating vars (+ back-compat aliases) from a sport key.
// null/unknown → neutral: accent collapses to ink (pure black/white page).
const EPE_NEUTRAL = '#c6c6c6';                   // visible neutral accent on the void (no sport)
function applyTheme(sportKey) {
  const pair = (sportKey && SPORT_ACCENT[sportKey]) || null;
  const dark = pair ? pair.d : EPE_NEUTRAL;     // sport accent, else neutral (visible on black)
  const light = pair ? pair.l : EPE_NEUTRAL;
  const b = document.body.style;
  b.setProperty('--accent', dark);
  b.setProperty('--accent-ink', light);
  // back-compat: existing components read these (mostly white surfaces → light)
  b.setProperty('--sport', light);
  b.setProperty('--page-accent', light);
  b.setProperty('--sport-press', mixHex(light, KINETIK_INK, 0.28));
}
function currentSportKey() {
  try { return (typeof getSportKey === 'function') ? getSportKey() : null; } catch (e) { return null; }
}
function setSportTheme() { stopAmbient(); applyTheme(currentSportKey()); }
// Themed pages theme to the sport; neutral pages collapse to ink.
function setAccent(_c) { stopAmbient(); applyTheme(currentSportKey()); }

/* ---- Ambient landing cycle: uncommitted → rotate through all sports ---- */
const REDUCED_MOTION = (typeof matchMedia === 'function') && matchMedia('(prefers-reduced-motion: reduce)').matches;
let _ambientTimer = null;
function startAmbient() {
  stopAmbient();
  const keys = Object.keys(SPORT_ACCENT);
  if (REDUCED_MOTION) { applyTheme(keys[0]); return; }   // single static accent
  let i = 0;
  applyTheme(keys[0]);
  _ambientTimer = setInterval(() => {
    i = (i + 1) % keys.length;
    applyTheme(keys[i]);
    const ghost = document.getElementById('heroGhost');
    if (ghost) ghost.textContent = keys[i].toUpperCase();
  }, 2200);
}
function stopAmbient() { if (_ambientTimer) { clearInterval(_ambientTimer); _ambientTimer = null; } }

/* ---- Flood transition: full-screen accent circle scales in on sport commit ---- */
function floodTransition(done) {
  if (REDUCED_MOTION) { if (done) done(); return; }
  const el = document.createElement('div');
  el.className = 'flood';
  document.body.appendChild(el);
  requestAnimationFrame(() => el.classList.add('flood--on'));
  let called = false;
  const finish = () => { if (called) return; called = true; if (done) done(); };
  setTimeout(finish, 360);                       // route mid-flood (feels instant)
  setTimeout(() => el.remove(), 760);            // clean up after fade
}
window.floodTransition = floodTransition;

function renderStep() {
  const steps = FLOWS[state.path];
  const step = steps[state.stepIndex];
  setAccent(step.accent);

  host.classList.remove('step--back');
  if (state.direction === 'back') host.classList.add('step--back');
  host.innerHTML =
    `<span class="step__eyebrow">${esc(step.eyebrow)}</span>` +
    `<h1 class="step__title">${step.title}</h1>` +
    `<p class="step__lead">${step.lead}</p>` +
    step.body();
  // re-trigger entrance animation
  host.style.animation = 'none'; void host.offsetWidth; host.style.animation = '';

  if (step.after) step.after();
  bindStep();
  updateProgress();
  updateNav();
  if (window.__lenis) window.__lenis.scrollTo(0, { duration: 0.6 });
  else window.scrollTo({ top: 0, behavior: 'smooth' });
}

function updateProgress() {
  const steps = FLOWS[state.path];
  const total = steps.length + 1;          // +1 for the Choose-Path step
  const num = state.stepIndex + 2;         // Choose was step 1
  const pct = Math.round((num / total) * 100);
  progressFill.style.width = pct + '%';
  progressLabel.textContent = `Step ${num} of ${total}`;
  progressPct.textContent = `${pct}% Complete`;
}

function updateNav() {
  const step = FLOWS[state.path][state.stepIndex];
  prevBtn.textContent = state.stepIndex === 0 ? '← Change path' : '← Previous';
  nextBtn.textContent = step.nextLabel || 'Continue →';
}

function showStep(i, dir) {
  state.stepIndex = i;
  state.direction = dir || 'fwd';
  renderStep();
}

nextBtn.addEventListener('click', () => {
  if (state.generating) return;            // in-flight guard: no duplicate generations
  const step = FLOWS[state.path][state.stepIndex];
  if (step.validate && !step.validate()) return;
  if (step.goResults) { enterResults(); return; }
  const ni = state.stepIndex + 1;
  const target = FLOWS[state.path][ni];
  // RESULT step → show the processing screen, then render the plan from the ONE
  // canonical engine: DRILL_DB + the assessBaseline-derived real scores (see
  // drills.js generatePlan / renderDrillPlan and renderPlan). The plan is built
  // by the step's `after` hook on showStep().
  // NOTE: the old server `drill_library.json` path (a divergent 2nd catalog with
  // decorative metric names) is retired — it no longer overwrites this plan.
  if (target && target.isResult && typeof aiProcess === 'function') {
    if (window.track) track('plan_generated', { engine: 'unified', path: state.path });
    aiProcess(() => showStep(ni, 'fwd'), state.path);
    return;
  }
  showStep(ni, 'fwd');
});

// Assembles the full assessment payload sent to /api/ai/generate-plan.
function buildAssessmentPayload() {
  const d = data();
  const p = Object.assign({}, d, { path: state.path });
  if (state.path === 'persona' && state.chosenPersona && typeof personaById === 'function') {
    const persona = personaById(state.chosenPersona);
    p.persona = persona.name;
    p.sport = (persona.sports || [])[0];
    if (!p.sportsChosen || !p.sportsChosen.length) p.sportsChosen = (persona.sports || []).slice(0, 1);
    p.goals = (d.goals && d.goals.length) ? d.goals : persona.goals;
  }
  return p;
}

/* Extract the rendered report (#planBody .bp) into structured sections and
   download it as a real branded PDF. Used for the persona report (narrative). */
function extractReportSections() {
  const host = document.getElementById('planBody');
  const bp = host && host.querySelector('.bp');
  if (!bp) return null;
  const head = bp.querySelector('.bp__head');
  const title = head && head.querySelector('h3') ? head.querySelector('h3').textContent.trim() : 'Sporve Report';
  const subtitle = head && head.querySelector('span') ? head.querySelector('span').textContent.trim() : '';
  const sections = [];
  bp.querySelectorAll('.bp__section').forEach(sec => {
    if (sec.classList.contains('bp__section--split')) {
      sec.querySelectorAll(':scope > div').forEach(sub => {
        const h = sub.querySelector('h4');
        if (h) sections.push({ heading: h.textContent.trim(), tags: [...sub.querySelectorAll('.bp__tag')].map(t => t.textContent.trim()) });
      });
      return;
    }
    const h = sec.querySelector('h4'); if (!h) return;
    sections.push({
      heading: h.textContent.trim(),
      paragraphs: [...sec.querySelectorAll(':scope > p')].map(p => p.textContent.trim()).filter(Boolean),
      bullets: [...sec.querySelectorAll('li')].map(li => li.textContent.trim()).filter(Boolean),
      tags: [...sec.querySelectorAll('.bp__tag')].map(t => t.textContent.trim()),
    });
  });
  return { kind: 'report', title, subtitle, sections };
}
async function downloadReportPdf(btn) {
  const payload = extractReportSections();
  if (!payload) { alert('Open your report first, then download.'); return; }
  const label = btn && btn.textContent; if (btn) { btn.disabled = true; btn.textContent = 'Preparing PDF…'; }
  try {
    const res = await fetch('/api/report/pdf', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
    if (!res.ok) throw new Error('pdf ' + res.status);
    const blob = await res.blob(); const url = URL.createObjectURL(blob);
    const a = document.createElement('a'); a.href = url;
    a.download = (payload.title || 'Sporve-Report').replace(/[^a-z0-9]+/gi, '-').replace(/^-|-$/g, '') + '.pdf';
    document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(url), 4000);
    if (window.track) track('pdf_downloaded', { kind: 'report' });
  } catch (e) { console.error('[pdf] report download failed', e); alert('Sorry — the PDF could not be generated. Please try again.'); }
  finally { if (btn) { btn.disabled = false; btn.textContent = label; } }
}
window.downloadReportPdf = downloadReportPdf;

prevBtn.addEventListener('click', () => {
  if (state.stepIndex === 0) { goChoose(); return; }
  showStep(state.stepIndex - 1, 'back');
});

/* =========================================================
   Screens
   ========================================================= */
function showScreen(name) {
  document.body.dataset.screen = name;
  landing.hidden = name !== 'landing';
  choose.hidden = name !== 'choose';
  topbar.hidden = name !== 'wizard';
  wizard.hidden = name !== 'wizard';
  const results = document.getElementById('results');
  const dash = document.getElementById('dash');
  if (results) results.hidden = name !== 'results';
  if (dash) dash.hidden = name !== 'dash';
  if (name === 'results' || name === 'dash' || name === 'wizard') setSportTheme();
}
function showLanding() { showScreen('landing'); startAmbient(); requestAnimationFrame(() => animateHero()); }
function goChoose() { stopAmbient(); state._recoFlooded = false; setAccent(); showScreen('choose'); window.scrollTo({ top: 0 }); }
function enterResults() {
  setAccent('#3b82f6');
  showScreen('results');
  if (typeof renderResultsSummary === 'function') renderResultsSummary();
  window.scrollTo({ top: 0 });
}
function enterPath(path) {
  if (path !== state.path) state.chosenPersona = null;
  state.path = path;
  state._sportKey = (typeof getSportKey === 'function') ? getSportKey() : null;
  save();
  showScreen('wizard');
  showStep(0, 'fwd');
}
function resetAll() {
  state = { path: null, stepIndex: 0, data: freshData(), chosenPersona: null };
  try { localStorage.removeItem(STORE_KEY); } catch (e) {}
  goChoose();
}

// In-plan pricing buttons jump to the full options/checkout screen.
document.addEventListener('click', e => {
  if (e.target.closest('[data-goresults]')) { e.preventDefault(); enterResults(); }
});

getStartedBtn.addEventListener('click', goChoose);

/* =========================================================
   Nav auth (guest-first, save-gated) — Login surfaced; account
   menu + "My plan" return path when signed in.
   ========================================================= */
function navInitial(u) { const e = (u && u.email) || ''; return (e[0] || '?').toUpperCase(); }
function refreshNavAuth() {
  const host = document.getElementById('navAuth');
  if (!host) return;
  const authed = window.API && API.isAuthed();
  if (authed) {
    const u = API.getUser ? API.getUser() : null;
    host.innerHTML =
      '<button type="button" class="nav__login js-myplan">My plan</button>' +
      '<div class="nav__acct">' +
        '<button type="button" class="nav__avatar" id="navAvatar" aria-label="Account menu">' + navInitial(u) + '</button>' +
        '<div class="nav__menu" id="navMenu">' +
          '<button type="button" class="js-myplan">My plan</button>' +
          '<button type="button" class="js-logout">Log out</button>' +
        '</div>' +
      '</div>';
  } else {
    host.innerHTML =
      '<button type="button" class="nav__login js-login">Log in</button>' +
      '<button type="button" class="btn btn--solid nav__cta js-start">Create a plan</button>';
  }
}
window.refreshReturnButton = refreshNavAuth;   // auth-ui.js calls this after login
function openMyPlan() { if (typeof enterDashboard === 'function') { enterDashboard(); } else { goChoose(); } }

document.addEventListener('click', e => {
  if (e.target.closest('.js-start')) { e.preventDefault(); goChoose(); return; }
  if (e.target.closest('.js-login')) { e.preventDefault(); if (window.Auth) Auth.openAuthModal('login', refreshNavAuth); return; }
  if (e.target.closest('.js-logout')) { e.preventDefault(); if (window.API) API.logout(); refreshNavAuth(); showLanding(); return; }
  if (e.target.closest('.js-myplan')) { e.preventDefault(); openMyPlan(); return; }
  if (e.target.closest('#navAvatar')) { e.preventDefault(); const m = document.getElementById('navMenu'); if (m) m.classList.toggle('open'); return; }
  const menu = document.getElementById('navMenu'); if (menu && !e.target.closest('.nav__acct')) menu.classList.remove('open');
});
refreshNavAuth();
// Landing nav/footer links smooth-scroll to their sections.
document.querySelectorAll('[data-scroll]').forEach(a =>
  a.addEventListener('click', e => {
    e.preventDefault();
    const t = document.querySelector(a.getAttribute('data-scroll'));
    if (t) t.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }));
// Parental-consent gate (COPPA): a guardian must confirm before the assessment.
const consentCheck = document.getElementById('consentCheck');
const consentErr = document.getElementById('consentErr');
try { if (consentCheck && localStorage.getItem('trf_consent') === '1') consentCheck.checked = true; } catch (e) {}
if (consentCheck) consentCheck.addEventListener('change', () => {
  if (consentErr) consentErr.hidden = consentCheck.checked;
  try { localStorage.setItem('trf_consent', consentCheck.checked ? '1' : '0'); } catch (e) {}
});
document.querySelectorAll('.path-card').forEach(card => {
  card.addEventListener('click', () => {
    if (consentCheck && !consentCheck.checked) {
      if (consentErr) consentErr.hidden = false;
      const gate = document.getElementById('consentGate');
      if (gate) { gate.classList.add('consent--shake'); setTimeout(() => gate.classList.remove('consent--shake'), 500); }
      return;
    }
    document.querySelectorAll('.path-card').forEach(c => c.classList.remove('selected'));
    card.classList.add('selected');
    if (window.track) track('path_chosen', { path: card.dataset.path });
    setTimeout(() => enterPath(card.dataset.path), 140);
  });
});
// Everything on the landing funnels into the create-a-plan flow:
// clicking any tagged section (that isn't a real link/button/field) starts a plan.
document.querySelectorAll('[data-cta-start]').forEach(el =>
  el.addEventListener('click', e => {
    if (e.target.closest('a, button, input, select, textarea, label')) return;
    goChoose();
  }));

['landingBrand', 'chooseBrand', 'topbarBrand', 'resultsBrand'].forEach(id => {
  const el = document.getElementById(id);
  if (el) el.addEventListener('click', e => { e.preventDefault(); showLanding(); });
});
const howBtn = document.getElementById('howItWorksBtn');
if (howBtn) howBtn.addEventListener('click', () => {
  const f = document.querySelector('.hero__feats');
  if (f) f.scrollIntoView({ behavior: 'smooth', block: 'center' });
});

/* =========================================================
   Premium motion: count-up, scroll-reveal, hero viz, AI processing
   ========================================================= */
const reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

function countUp(el) {
  const to = Number(el.dataset.count) || 0;
  const suffix = el.dataset.suffix || '';
  if (reduceMotion) { el.textContent = to + suffix; return; }
  const dur = 1200, t0 = performance.now();
  (function tick(now) {
    const p = Math.min(1, (now - t0) / dur);
    const eased = 1 - Math.pow(1 - p, 3);
    el.textContent = Math.round(to * eased) + suffix;
    if (p < 1) requestAnimationFrame(tick);
  })(t0);
}

function animateScope(scope) {
  if (!scope) return;
  scope.querySelectorAll('.countup').forEach(countUp);
  scope.querySelectorAll('.ring__fill[data-ring]').forEach(c => {
    const pct = Number(c.dataset.ring) || 0;
    const len = 2 * Math.PI * 52;
    c.style.strokeDashoffset = reduceMotion ? len * (1 - pct / 100) : len;
    if (!reduceMotion) requestAnimationFrame(() => { c.style.strokeDashoffset = len * (1 - pct / 100); });
  });
  scope.querySelectorAll('.hmetric__bar i[data-w]').forEach(b => {
    requestAnimationFrame(() => { b.style.width = b.dataset.w + '%'; });
  });
}

let heroAnimated = false;
function animateHero() {
  const viz = document.querySelector('.hero__viz');
  if (!viz) return;
  if (heroAnimated) { return; }            // animate once per load
  heroAnimated = true;
  animateScope(viz);
}

/* reveal-on-scroll */
(function initReveal() {
  if (!('IntersectionObserver' in window)) {
    document.querySelectorAll('.reveal').forEach(el => el.classList.add('in'));
    return;
  }
  const io = new IntersectionObserver((entries) => {
    entries.forEach(e => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } });
  }, { threshold: 0.15 });
  document.querySelectorAll('.reveal').forEach(el => io.observe(el));
})();

/* cinematic AI processing screen */
function aiProcess(done, path) {
  const overlay = document.getElementById('aiproc');
  const msgEl = document.getElementById('aiprocMsg');
  const barEl = document.getElementById('aiprocBar');
  const pctEl = document.getElementById('aiprocPct');
  if (!overlay) { done(); return; }

  const personaMsgs = [
    'Analyzing athlete profile…',
    'Scoring physical & trait metrics…',
    'Matching athletic personas…',
    'Ranking best-fit directions…',
    'Generating your recommendations…'
  ];
  const planMsgs = [
    'Analyzing athlete profile…',
    'Matching sport-specific drills…',
    'Filtering by age, equipment & space…',
    'Building your weekly training plan…',
    'Generating Athletic Blueprint…'
  ];
  const msgs = path === 'persona' ? personaMsgs : planMsgs;

  overlay.hidden = false;
  let mi = 0;
  msgEl.textContent = msgs[0];
  const total = reduceMotion ? 600 : 2600;
  const t0 = performance.now();
  (function tick(now) {
    const p = Math.min(1, (now - t0) / total);
    const pct = Math.round(p * 100);
    if (pctEl) pctEl.textContent = pct;
    if (barEl) barEl.style.width = pct + '%';
    const idx = Math.min(msgs.length - 1, Math.floor(p * msgs.length));
    if (idx !== mi) { mi = idx; msgEl.textContent = msgs[idx]; }
    if (p < 1) requestAnimationFrame(tick);
    else {
      done();
      setTimeout(() => { overlay.hidden = true; if (barEl) barEl.style.width = '0%'; }, 280);
    }
  })(t0);
}

/* Processing screen tied to a REAL request: the bar climbs toward 90% while
   the request is in flight and can never complete before the response arrives. */
/* Processing screen with GUARANTEED completion. Progress is decoupled from the
   data: the bar eases to 90% and holds, but a hard watchdog (and the settled
   promise) ALWAYS drive it to 100% and call done() — even if the request never
   resolves, the tab is backgrounded (rAF paused), or #aiproc is missing.
   It is impossible to get stuck at 90%. done(null) → caller renders fallback. */
function aiProcessAwait(promise, done, path) {
  const HARD_CAP_MS = 42000;            // never sit longer than this
  const overlay = document.getElementById('aiproc');
  const msgEl = document.getElementById('aiprocMsg');
  const barEl = document.getElementById('aiprocBar');
  const pctEl = document.getElementById('aiprocPct');

  let settled = false, failed = false, result = null, finished = false;
  promise
    .then(r => { settled = true; result = r; })
    .catch((e) => { settled = true; failed = true; console.warn('[generation] request failed → fallback:', e && e.message); });

  function finish() {
    if (finished) return;
    finished = true;
    clearTimeout(watchdog);
    if (pctEl) pctEl.textContent = 100;
    if (barEl) barEl.style.width = '100%';
    try { done(failed ? null : result); }
    finally { if (overlay) setTimeout(() => { overlay.hidden = true; if (barEl) barEl.style.width = '0%'; }, 280); }
  }

  // Hard watchdog: fires even when requestAnimationFrame is throttled/paused.
  const watchdog = setTimeout(() => {
    if (!settled) { failed = true; console.warn('[generation] watchdog ' + HARD_CAP_MS + 'ms hit → forcing fallback'); }
    finish();
  }, HARD_CAP_MS);

  // No overlay? Still complete (watchdog covers a never-settling promise).
  if (!overlay) { promise.then(() => finish()).catch(() => finish()); return; }

  const msgs = ['Analyzing athlete profile…', 'Matching age-appropriate drills…', 'Writing the weekly plan…', 'Checking youth-safety limits…', 'Finalizing your plan…'];
  overlay.hidden = false;
  let mi = 0;
  msgEl.textContent = msgs[0];
  const t0 = performance.now();
  (function tick(now) {
    if (finished) return;
    const elapsed = now - t0;
    const p = settled ? 1 : Math.min(0.9, elapsed / 6000);
    if (pctEl) pctEl.textContent = Math.round(p * 100);
    if (barEl) barEl.style.width = (p * 100) + '%';
    const idx = Math.min(msgs.length - 1, Math.floor((settled ? 1 : p / 0.9) * msgs.length));
    if (idx !== mi) { mi = idx; msgEl.textContent = msgs[idx]; }
    if (settled && p >= 1) { finish(); return; }
    requestAnimationFrame(tick);
  })(t0);
}

/* ---- boot ---- */
showLanding();
