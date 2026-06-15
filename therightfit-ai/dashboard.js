/* =========================================================
   Sporve — Weekly Training Dashboard + retention
   Client-side, localStorage-persisted. "AI" is rule-based.
   Timeline is simulated: each daily check-in advances one day,
   so streaks / XP / levels are demonstrable without waiting.
   Relies on globals from script.js: buildCtx, computePersonas,
   state, showScreen, setAccent, resetAll, data.
   ========================================================= */

const DASH_KEY = 'trf_dash_v1';
const DASH_ACCENT = '#22e58a';
const SESSION_TASKS = ['speed', 'skill', 'recovery'];

/* ---------- DOM ---------- */
const dashMain = document.getElementById('dashMain');
const dashTabs = document.getElementById('dashTabs');
const modal = document.getElementById('modal');
const modalBody = document.getElementById('modalBody');

let dash = null;        // active dashboard state
let activeTab = 'week';

/* ---------- helpers (local; esc/clamp/listify mirror script.js) ---------- */
const e = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
const cl = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const pct = (a, b) => b ? Math.round((a / b) * 100) : 0;

/* ---------- real calendar dates (streaks reflect actual days) ---------- */
function todayStr(dt) {
  const d = dt || new Date();
  return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
}
function daysBetween(a, b) { return Math.round((new Date(b + 'T00:00:00') - new Date(a + 'T00:00:00')) / 86400000); }
// signature of the underlying assessment so we can detect a re-assessment
function planSig() { const c = buildCtx(); return [state.path, c.focus, c.level, c.sessions].join('|'); }

/* =========================================================
   XP / levels
   ========================================================= */
function totalXpForLevel(L) { return 50 * L * (L - 1); }   // L1:0 L2:100 L3:300 L4:600 L5:1000
function computeLevel(xp) { let L = 1; while (totalXpForLevel(L + 1) <= xp) L++; return L; }

/* =========================================================
   Badges
   ========================================================= */
const BADGES = [
  { id: 'first', icon: '', label: 'First Step', desc: 'Logged your first workout', test: d => d.workoutsCompleted >= 1 },
  { id: 'streak7', icon: '', label: '7-Day Streak', desc: 'Trained 7 days in a row', test: d => d.bestStreak >= 7 },
  { id: 'streak30', icon: '', label: '30-Day Streak', desc: 'Trained 30 days in a row', test: d => d.bestStreak >= 30 },
  { id: 'w100', icon: '', label: '100 Workouts', desc: 'Completed 100 workouts', test: d => d.workoutsCompleted >= 100 },
  { id: 'perfectweek', icon: '', label: 'Perfect Week', desc: 'Completed every weekly objective', test: d => d.weeksPerfect >= 1 },
  { id: 'nevermiss', icon: '', label: 'Never Missed a Week', desc: 'Four perfect weeks', test: d => d.weeksPerfect >= 4 },
  { id: 'level5', icon: '', label: 'Level 5 Athlete', desc: 'Reached athlete level 5', test: d => computeLevel(d.xp) >= 5 }
];

/* =========================================================
   State
   ========================================================= */
function saveDashLocal() { try { localStorage.setItem(DASH_KEY, JSON.stringify(dash)); } catch (e2) {} }
function loadDash() { try { const r = localStorage.getItem(DASH_KEY); if (r) return JSON.parse(r); } catch (e2) {} return null; }

// Persist: always cache locally; when signed in with a server plan, debounce a PUT.
let _saveTimer = null;
function saveDash() {
  saveDashLocal();
  if (window.API && API.isAuthed() && dash && dash._planId) {
    clearTimeout(_saveTimer);
    _saveTimer = setTimeout(() => {
      API.updatePlan(dash._planId, {
        dash, plan: dash.plan, sig: dash.sig, tier: dash.tier,
        max_weeks: dash.maxWeeks, name: dash.name, status: 'active'
      }).catch(() => {});
    }, 600);
  }
}

// Build the POST payload that auto-saves a plan to the server.
function planPayload(tier, status) {
  const ctx = buildCtx();
  const d = data();
  return {
    name: dash ? dash.name : planName(ctx),
    tier: tier || (dash && dash.tier) || 'free',
    status: status || 'active',
    max_weeks: dash ? dash.maxWeeks : (tier === 'member' ? 12 : 4),
    sig: planSig(),
    athlete: {
      name: (d.name || '').trim() || null, age: d.age || null, height: d.height || null, weight: d.weight || null,
      sport: ctx.focus || null, persona: state.chosenPersona || null, path: state.path || null, assessment: d
    },
    ctx, plan: ctx.plan || null, dash
  };
}

// Save the current seeded dash as a new server plan and remember its id.
async function persistNewPlan(tier, status) {
  const saved = await API.savePlan(planPayload(tier, status));
  dash._planId = saved.id;
  dash._athleteId = saved.athlete_id;
  saveDashLocal();
  return saved;
}

// Replace in-memory dash with a server plan's stored state.
function hydrateFromServerPlan(sp) {
  if (sp.dash && typeof sp.dash === 'object') {
    dash = sp.dash;
  } else {
    // Minimal/imported plan with no saved tracker — rebuild from ctx/plan.
    dash = seedDash(sp.tier || 'free');
    if (sp.plan) { dash.plan = sp.plan; dash.mode = 'drills'; dash.checks = dash.checks || {}; }
  }
  dash._planId = sp.id;
  dash._athleteId = sp.athlete_id;
  if (!dash.name) dash.name = sp.name || planName(sp.ctx || {});
  saveDashLocal();
}

function task(id, label, target) { return { id, label, target, done: 0 }; }
function weekTasks(week, ctx) {
  const s = ctx.sessions || 3;
  const bump = Math.floor((week - 1) / 2);          // gentle progression every 2 weeks
  const speed = Math.max(2, Math.round(s * 0.4)) + bump;
  const skill = Math.max(1, Math.round(s * 0.35));
  return [
    task('speed', `Complete ${speed} speed / conditioning sessions`, speed),
    task('skill', `Complete ${skill} skill sessions`, skill),
    task('stretch', `Stretch 4 times`, 4),
    task('recovery', `Complete 1 recovery session`, 1),
    task('checkin', `Daily check-in ${Math.min(5, s + 1)} days`, Math.min(5, s + 1))
  ];
}

// Human-friendly plan name, e.g. "Volleyball — Intermediate · 12-week plan".
function planName(ctx) {
  const sport = ctx.focus || (state.path === 'persona' ? 'Athletic' : 'Training');
  const lvl = ctx.level ? cap(String(ctx.level)) : '';
  const dur = ctx.duration ? ' · ' + ctx.duration : '';
  return `${sport}${lvl ? ' — ' + lvl : ''}${dur} plan`;
}

function seedDash(tier) {
  const ctx = buildCtx();
  const maxWeeks = tier === 'free' ? 4 : 12;
  const onboardGoals = ((ctx.goals && ctx.goals.length) ? ctx.goals : (data().goals || [])).slice(0, 3);
  // drill mode when the sport path produced a library plan; otherwise generic objectives
  const drillMode = !!ctx.plan;
  const base = {
    tier, maxWeeks,
    name: planName(ctx), athleteName: (data().name || '').trim(),
    sport: ctx.focus, startDate: todayStr(),
    multiSport: !!ctx.multiSport, sports: ctx.sports || null,
    profile: ctx.profile || null,   // drives adaptive weekly regeneration
    focus: ctx.focus, level0: ctx.level, sessions: ctx.sessions, duration: ctx.duration,
    path: state.path, mode: drillMode ? 'drills' : 'tasks',
    week: 1, day: 0,
    xp: 0, streak: 0, bestStreak: 0,
    lastCheckinDate: null, parentEmail: '', sig: planSig(),
    workoutsCompleted: 0, weeksPerfect: 0,
    history: [], checkins: [], adapt: '',
    goals: onboardGoals.map(g => ({ text: g, progress: 0 })),
    metrics: [{ week: 0, height: data().height || '', weight: data().weight || '' }],
    badges: {}, review: null,
    // Part 2: closed-loop tracking
    perf: {},                       // per-drill achieved-quality logs: key -> {quality,pain}
    // baseline capability snapshot (from objective testing) seeds the progress timeline
    capabilityHistory: (ctx.profile && ctx.profile.baselineTested)
      ? [{ week: 0, date: todayStr(), capability: ctx.profile.capability, percentiles: ctx.profile.percentiles }]
      : []
  };
  if (drillMode) { base.plan = ctx.plan; base.checks = {}; }
  else { base.tasks = weekTasks(1, ctx); }
  return base;
}

/* =========================================================
   Entry points (called from results screen)
   ========================================================= */
// Seed a brand-new plan from the current assessment, applying the drift check
// against any locally cached dashboard. Used for the anonymous/offline path.
function seedOrReuseLocal(tier) {
  const existing = loadDash();
  if (existing && existing.tier) {
    dash = existing;
    if (tier === 'member' && dash.tier === 'free') { dash.tier = 'member'; dash.maxWeeks = 12; }
    if (dash.sig && dash.sig !== planSig()) {
      if (confirm('Your latest assessment is different from your saved dashboard. Rebuild it from your new plan? Your current dashboard progress will reset.')) {
        const keepTier = dash.tier;
        dash = seedDash(keepTier);
        dash.tier = keepTier;
        dash.maxWeeks = keepTier === 'member' ? 12 : 4;
      } else {
        dash.sig = planSig();
      }
    }
  } else {
    dash = seedDash(tier);
  }
}

// Open the tracking dashboard. Server-backed when signed in; falls back to the
// local cache (anonymous/offline) so the dashboard always opens.
async function enterDashboard(tier) {
  setAccent(DASH_ACCENT);
  showScreen('dash');
  activeTab = 'week';
  syncTabs();

  if (window.API && API.isAuthed()) {
    renderDashLoading();
    try {
      const sp = await API.getActivePlan();
      if (sp) {
        hydrateFromServerPlan(sp);
        if (tier === 'member' && dash.tier === 'free') { dash.tier = 'member'; dash.maxWeeks = 12; }
      } else {
        // Signed in but nothing saved yet — seed from the current assessment and save.
        seedOrReuseLocal(tier || 'free');
        try { await persistNewPlan(dash.tier); } catch (e) {}
      }
    } catch (e) {
      renderDashError(() => enterDashboard(tier));
      return;
    }
  } else {
    seedOrReuseLocal(tier);
  }

  saveDash();
  renderDashboard();
}
window.enterDashboard = enterDashboard;

// "Start Tracking This Plan" / "Save to Dashboard": persist then (optionally) open.
// Reuses the existing active plan when it matches the current assessment so we
// don't create duplicate plans every time the button is pressed.
async function startTrackingPlan(tier, openDashboard) {
  return new Promise(resolve => {
    window.Auth.requireAuth(async () => {
      try {
        const sig = planSig();
        let reused = false;
        try {
          const active = await API.getActivePlan();
          if (active && active.sig === sig) { hydrateFromServerPlan(active); reused = true; }
        } catch (e) {}
        if (!reused) {
          seedOrReuseLocal(tier || 'free');
          await persistNewPlan(dash.tier, 'active');
        }
        if (openDashboard) {
          setAccent(DASH_ACCENT); showScreen('dash'); activeTab = 'week'; syncTabs();
          saveDash(); renderDashboard();
        }
        resolve(true);
      } catch (e) {
        alert((e && e.message) || 'Your plan was generated but could not be saved. Please try again.');
        resolve(false);
      }
    });
  });
}

/* =========================================================
   XP + badge processing (with celebration)
   ========================================================= */
function addXp(n) {
  if (!n) return;
  const before = computeLevel(dash.xp);
  dash.xp = Math.max(0, dash.xp + n);
  const after = computeLevel(dash.xp);
  if (after > before && n > 0) queueCelebrate({ icon: '', title: `Level ${after}!`, body: `You leveled up to <b>Athlete Level ${after}</b>. Keep the momentum going.` });
}
function checkBadges() {
  BADGES.forEach(b => {
    if (!dash.badges[b.id] && b.test(dash)) {
      dash.badges[b.id] = dash.day;
      queueCelebrate({ icon: b.icon, title: 'Badge unlocked!', body: `<b>${b.label}</b><br><span class="muted">${b.desc}</span>` });
    }
  });
}

/* ---- celebration modal (queues multiple) ---- */
let celebrateQueue = [];
function queueCelebrate(item) { celebrateQueue.push(item); }
function flushCelebrations() {
  if (!celebrateQueue.length) return;
  const items = celebrateQueue; celebrateQueue = [];
  modalBody.innerHTML = items.map(it => `
    <div class="celebrate">
      <div class="celebrate__icon">${it.icon}</div>
      <h3>${it.title}</h3>
      <p>${it.body}</p>
    </div>`).join('<hr class="celebrate__div" />');
  openModalA11y();
}
// Accessible modal show/hide: move focus in on open, restore it on close,
// and trap Tab within the dialog while it's open.
let _modalLastFocus = null;
function openModalA11y() {
  _modalLastFocus = document.activeElement;
  modal.hidden = false;
  const x = document.getElementById('modalX');
  if (x) setTimeout(() => x.focus(), 0);
}
function closeModal() {
  modal.hidden = true;
  if (_modalLastFocus && _modalLastFocus.focus) { try { _modalLastFocus.focus(); } catch (e) {} }
  _modalLastFocus = null;
}
if (modal) modal.addEventListener('keydown', (e) => {
  if (e.key !== 'Tab' || modal.hidden) return;
  const f = modal.querySelectorAll('a[href],button:not([disabled]),input,select,textarea,[tabindex]:not([tabindex="-1"])');
  if (!f.length) return;
  const first = f[0], last = f[f.length - 1];
  if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
  else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
});

/* =========================================================
   Derived metrics
   ========================================================= */
function dayItems(s) {
  const items = [];
  if (s.warmup) items.push({ key: 'w' + s.day, label: 'Warmup — ' + s.warmup, kind: 'warm' });
  s.drills.forEach((x, i) => items.push({ key: 'd' + s.day + '_' + i, label: x.d.drill_name, kind: 'skill', item: x }));
  if (s.cooldown) items.push({ key: 'c' + s.day, label: 'Cooldown — ' + s.cooldown, kind: 'cool' });
  return items;
}
function allItems() { return (dash.plan && dash.plan.week ? dash.plan.week : []).reduce((a, s) => a.concat(dayItems(s)), []); }
function weekDone() {
  if (dash.mode === 'drills') return allItems().filter(it => dash.checks[it.key]).length;
  return dash.tasks.reduce((a, t) => a + t.done, 0);
}
function weekTarget() {
  if (dash.mode === 'drills') return Math.max(1, allItems().length);
  return dash.tasks.reduce((a, t) => a + t.target, 0);
}
function weekPct() { return pct(weekDone(), weekTarget()); }
function weekScore() { return weekDone() * 10 + (weekPct() >= 100 ? 50 : 0); }
function monthlyConsistency() {
  const recent = dash.history.slice(-4).map(h => h.pct);
  recent.push(weekPct());
  return Math.round(recent.reduce((a, b) => a + b, 0) / recent.length);
}
function goalCompletion() {
  if (!dash.goals.length) return 0;
  return Math.round(dash.goals.reduce((a, g) => a + g.progress, 0) / dash.goals.length);
}

/* =========================================================
   HUD + tab chrome
   ========================================================= */
function renderHud() {
  const lvl = computeLevel(dash.xp);
  const cur = totalXpForLevel(lvl), next = totalXpForLevel(lvl + 1);
  document.getElementById('hudLevel').textContent = lvl;
  document.getElementById('hudXp').style.width = pct(dash.xp - cur, next - cur) + '%';
  document.getElementById('hudXpLabel').textContent = `${dash.xp - cur} / ${next - cur} XP`;
  document.getElementById('hudStreak').textContent = dash.streak;
  document.getElementById('hudTier').textContent = dash.tier === 'member' ? 'Member' : 'Free';
}
function syncTabs() {
  dashTabs.querySelectorAll('button').forEach(b => b.classList.toggle('active', b.dataset.tab === activeTab));
}

/* =========================================================
   Renderers per tab
   ========================================================= */
function renderDashboard() {
  if (!dash) { renderDashEmpty(); return; }
  renderHud();
  ({ week: tabWeek, progress: tabProgress, coach: tabCoach, goals: tabGoals, reassess: tabReassess, parent: tabParent }[activeTab] || tabWeek)();
  flushCelebrations();
  saveDash();
}

/* ---- loading / error / empty states ---- */
function renderDashLoading() {
  dashMain.innerHTML = `<div class="dash-state"><div class="dash-state__spin"></div><p>Loading your plan…</p></div>`;
}
function renderDashError(retry) {
  dashMain.innerHTML = `
    <div class="dash-state">
      <div class="dash-state__icon"></div>
      <h2>We couldn't load your plan</h2>
      <p class="muted">Check your connection and try again.</p>
      <button type="button" class="btn btn--solid" id="dashRetry">Retry</button>
    </div>`;
  const b = dashMain.querySelector('#dashRetry');
  if (b && retry) b.addEventListener('click', retry);
}
function renderDashEmpty() {
  renderHud && document.getElementById('hudTier') && (document.getElementById('hudTier').textContent = '—');
  dashMain.innerHTML = `
    <div class="dash-state">
      <div class="dash-state__icon"></div>
      <h2>You don't have an active training plan yet</h2>
      <p class="muted">Take the assessment to generate a personalized plan, then start tracking it here.</p>
      <div class="dash-state__actions">
        <button type="button" class="btn btn--solid" id="emptyCreate">Create a training plan</button>
        <button type="button" class="btn btn--ghost" id="emptyReports">View saved plans</button>
      </div>
    </div>`;
  const c = dashMain.querySelector('#emptyCreate');
  if (c) c.addEventListener('click', () => { if (typeof resetAll === 'function') resetAll(); });
  const r = dashMain.querySelector('#emptyReports');
  if (r) r.addEventListener('click', () => openLibrary());
}

/* ---- progress ring (reusable) ---- */
function ringSvg(percent, big, sub, accentClass) {
  const r = 34, C = 2 * Math.PI * r;
  const off = C * (1 - cl(percent, 0, 100) / 100);
  return `
    <div class="pring ${accentClass || ''}">
      <svg viewBox="0 0 80 80">
        <circle class="pring__track" cx="40" cy="40" r="${r}" />
        <circle class="pring__fill" cx="40" cy="40" r="${r}" style="stroke-dasharray:${C};stroke-dashoffset:${off}" />
      </svg>
      <div class="pring__center"><b>${big}</b><span>${e(sub)}</span></div>
    </div>`;
}
function dayComplete(s) {
  const items = dayItems(s).filter(it => it.kind === 'skill');
  return items.length > 0 && items.every(it => dash.checks[it.key]);
}
function nextMilestoneLabel() {
  const locked = BADGES.find(b => !dash.badges[b.id]);
  if (locked) return locked.label;
  return weekPct() >= 100 ? 'Finish the week' : 'Complete this week';
}

/* ---- EPE dense-dashboard widgets (FinGlow-informed; existing data only) ---- */
function epeSparkline(vals) {
  vals = (vals || []).filter(v => typeof v === 'number');
  if (vals.length < 2) return '<p class="muted" style="font-size:12px;margin:8px 0">Not enough history yet.</p>';
  const w = 240, h = 54;
  const pts = vals.map((v, i) => ((i / (vals.length - 1)) * w).toFixed(1) + ',' + (h - (cl(v, 0, 100) / 100) * h).toFixed(1)).join(' ');
  const ly = h - (cl(vals[vals.length - 1], 0, 100) / 100) * h;
  return `<svg viewBox="0 0 ${w} ${h}" preserveAspectRatio="none" style="width:100%;height:54px;display:block">`
    + `<polyline points="${pts}" fill="none" stroke="var(--accent)" stroke-width="1.5" vector-effect="non-scaling-stroke"/>`
    + `<line x1="${w}" y1="0" x2="${w}" y2="${h}" stroke="var(--epe-stroke,#222)" stroke-width="1"/>`
    + `<circle cx="${w}" cy="${ly.toFixed(1)}" r="2.5" fill="var(--accent)"/></svg>`;
}
function epeArc(done, total) {
  const p = total ? Math.min(1, done / total) : 0;
  const C = Math.PI * 42, off = C * (1 - p);
  return `<svg viewBox="0 0 100 58" style="width:120px;height:60px;display:block;margin:0 auto">`
    + `<path d="M8,52 A42,42 0 0 1 92,52" fill="none" stroke="#1A1A1A" stroke-width="6" stroke-linecap="round"/>`
    + `<path d="M8,52 A42,42 0 0 1 92,52" fill="none" stroke="var(--accent)" stroke-width="6" stroke-linecap="round" stroke-dasharray="${C.toFixed(1)}" stroke-dashoffset="${off.toFixed(1)}"/></svg>`;
}
function epeReadiness() {
  const a = (typeof acwr === 'function') ? acwr() : null;
  if (!a) return '';                                   // only render when the data exists
  const r = a.ratio;
  const pos = cl(((r - 0.5) / (1.8 - 0.5)) * 100, 2, 98);
  const zone = (r >= 0.8 && r <= 1.3) ? 'Optimal' : (r < 0.8 ? 'Under-loaded' : 'High load');
  return `<div class="epe-widget"><div class="epe-widget__k">Readiness · Load Balance</div>`
    + `<div class="epe-gradbar"><i style="left:${pos.toFixed(0)}%"></i></div>`
    + `<div class="epe-widget__row"><span>ACWR ${r.toFixed(2)}</span><span style="color:var(--accent)">${zone}</span></div></div>`;
}
function dashBriefing() {
  const name = ((dash.athleteName || (data().name || '').trim()) || 'Athlete').split(' ')[0];
  let date = ''; try { date = new Date().toLocaleDateString(undefined, { weekday: 'long', month: 'short', day: 'numeric' }); } catch (e2) {}
  return `<div class="epe-brief"><div><div class="epe-brief__hi">Hello, ${e(name)}</div>`
    + `<div class="epe-brief__date">Daily Briefing${date ? ' · ' + e(date) : ''}</div></div>`
    + `<span class="epe-brief__live epe-live">Synced</span></div>`;
}
function dashWidgets() {
  if (dash.mode !== 'drills') return '';               // drill plans only (tasks mode keeps its objectives)
  const hist = (dash.history || []).map(h => h.pct).concat([weekPct()]);
  const done = weekDone(), total = weekTarget();
  const spark = `<div class="epe-widget"><div class="epe-widget__k">Progress over time</div>${epeSparkline(hist)}<div class="epe-widget__row"><span>Weekly completion</span><span style="color:var(--accent)">${weekPct()}%</span></div></div>`;
  const arc = `<div class="epe-widget"><div class="epe-widget__k">Block volume</div>${epeArc(done, total)}<div class="epe-widget__row"><span>Drills this week</span><span style="color:var(--accent)">${done}/${total}</span></div></div>`;
  return `<div class="epe-grid">${epeReadiness()}${spark}${arc}</div>`;
}

/* ---- Multi-sport allocation view (renders plan.allocation; existing data) ---- */
function dashAllocation() {
  const plan = dash.plan, alloc = plan && plan.allocation;
  if (!alloc || !alloc.skill || alloc.skill.length < 2) return '';
  const accentOf = (k) => (typeof SPORT_ACCENT !== 'undefined' && SPORT_ACCENT[k] && SPORT_ACCENT[k].d) || 'var(--accent)';
  const labelOf = (k) => (typeof sportLabelFor === 'function') ? sportLabelFor(k) : k;
  const SEASON = { in_season: 'IN-SEASON', pre_season: 'PRE-SEASON', off_season: 'OFF-SEASON', maintenance: 'MAINTENANCE' };
  const seasonOf = (k) => { const m = (dash.profile && dash.profile.sportMeta && dash.profile.sportMeta[k]) || {}; return SEASON[m.season] || 'OFF-SEASON'; };
  const total = alloc.skill.reduce((a, s) => a + s.sessions, 0) + (alloc.baseSessions || 0) || 1;
  const rows = alloc.skill.map(s => {
    const c = accentOf(s.sportId), p = Math.round((s.sessions / total) * 100), anchor = s.sportId === alloc.anchorSportId;
    return `<div class="alloc-row"><div class="alloc-row__hd"><span class="alloc-dot" style="background:${c}"></span>`
      + `<b style="color:${c}">${e(labelOf(s.sportId))}</b>${anchor ? '<span class="alloc-anchor">ANCHOR</span>' : ''}`
      + `<span class="alloc-season">${seasonOf(s.sportId)}</span><span class="alloc-mode">${e((s.mode || '').toUpperCase())}</span></div>`
      + `<div class="alloc-bar"><i style="width:${p}%;background:${c}"></i></div>`
      + `<div class="alloc-meta">${s.sessions} skill session${s.sessions === 1 ? '' : 's'}/wk · ${p}%</div></div>`;
  }).join('');
  const bp = Math.round(((alloc.baseSessions || 0) / total) * 100);
  const baseRow = `<div class="alloc-row"><div class="alloc-row__hd"><span class="alloc-dot" style="background:var(--epe-neutral)"></span><b>Shared Athletic Base</b>`
    + `<span class="alloc-mode">${(alloc.baseTheme || []).slice(0, 2).map(q => q.replace(/_/g, ' ')).join(' · ')}</span></div>`
    + `<div class="alloc-bar"><i style="width:${bp}%;background:var(--epe-neutral)"></i></div>`
    + `<div class="alloc-meta">${alloc.baseSessions || 0}×/wk · built once, transfers across sports</div></div>`;
  const note = alloc.interference ? `<div class="alloc-note">⚠ ${e((alloc.appliedRules || [])[0] || 'Heavy strength and hard endurance are separated across days.')}</div>` : '';
  return `<div class="alloc-card"><div class="alloc-card__k">Multi-Sport Allocation · Anchor ${e(labelOf(alloc.anchorSportId))}</div>${rows}${baseRow}${note}</div>`;
}

/* ---- This Week (premium) ---- */
function tabWeek() {
  const adapt = dash.adapt ? `<div class="ai-note"><b>AI adjustment</b> ${e(dash.adapt)}</div>` : '';
  const athlete = (dash.athleteName || (data().name || '').trim() || 'Your athlete');
  const week = dash.plan && dash.plan.week ? dash.plan.week : [];
  const drills = dash.mode === 'drills';

  // Injury safety gate — shown until the athlete marks themselves cleared.
  const injuryBanner = dash.injury ? `
    <div class="safety-banner" role="alert">
      <div class="safety-banner__txt">
        <b>Recovery mode</b>
        <span>You reported an injury on ${e(dash.injury.date)}. Your plan is recovery &amp; mobility only — please stop training and check with a parent, coach, or healthcare professional before resuming. Sporve is general guidance, not medical advice.</span>
      </div>
      <button type="button" class="btn btn--ghost btn--sm" id="injuryResume">I'm cleared — resume</button>
    </div>` : '';

  // Current-plan header.
  const header = injuryBanner + `
    <div class="cplan">
      <div class="cplan__main">
        <span class="cplan__eyebrow">${e(athlete)} · ${e(dash.sport || dash.focus || 'Training')}</span>
        <h2 class="cplan__name">${e(dash.name || 'Your training plan')}</h2>
        <div class="cplan__meta">
          <span class="cplan__week">Week ${dash.week > dash.maxWeeks ? dash.maxWeeks : dash.week} of ${dash.maxWeeks}</span>
          <span>·</span><span>Focus: ${e(dash.focus || 'Development')}</span>
        </div>
      </div>
      <div class="cplan__actions">
        <button type="button" class="btn btn--ghost btn--sm" id="cpDownload">Download plan</button>
        <button type="button" class="btn btn--ghost btn--sm" id="cpLibrary">My plans</button>
      </div>
    </div>`;

  // Weekly progress overview.
  const skillTotal = drills ? allItems().filter(it => it.kind === 'skill').length : weekTarget();
  const skillDone = drills ? allItems().filter(it => it.kind === 'skill' && dash.checks[it.key]).length : weekDone();
  const workoutsThisWeek = drills ? week.filter(dayComplete).length : dash.tasks.filter(t => t.done >= t.target).length;
  const workoutsTotal = drills ? week.length : dash.tasks.length;
  const todayIdx = week.length ? (dash.day % week.length) : 0;
  const missed = drills ? week.filter((s, i) => i < todayIdx && !dayComplete(s)).length : 0;
  const overview = `
    <div class="poverview">
      <div class="poverview__ring">
        ${ringSvg(weekPct(), weekPct() + '%', 'Weekly', 'pring--blue')}
        <div class="poverview__ringmeta"><b>Weekly completion</b><span>${skillDone}/${skillTotal} items done</span></div>
      </div>
      <div class="poverview__cards">
        ${miniCard('', dash.streak, 'Day streak')}
        ${miniCard('', workoutsThisWeek + '/' + workoutsTotal, 'Workouts')}
        ${miniCard('', skillDone + '/' + skillTotal, 'Drills done')}
        ${miniCard('', missed, 'Missed')}
        ${miniCard('', '', 'Next: ' + nextMilestoneLabel(), true)}
      </div>
    </div>
    ${(drills && dash.multiSport && dash.sports) ? perSportProgress(week) : ''}
    ${adapt}`;

  const canAdvance = dash.week <= dash.maxWeeks;
  const advLabel = dash.week < dash.maxWeeks ? 'Finish week &amp; start week ' + (dash.week + 1) : 'Finish &amp; complete program';

  // Unified "Finish today": ONE place to capture how today felt. Completion is
  // derived from the drills you actually checked off (no separate self-report).
  const loggedToday = dash.lastCheckinDate === todayStr();
  const sFin = week[todayIdx];
  const tTotal = (drills && sFin) ? dayItems(sFin).filter(it => it.kind === 'skill').length : 0;
  const tDone = (drills && sFin) ? dayItems(sFin).filter(it => it.kind === 'skill' && dash.checks[it.key]).length : 0;
  const finishToday = dash.injury ? '' : (loggedToday
    ? `<div class="finish-today finish-today--done"><b>✓ Logged today</b><span class="muted">Come back tomorrow to keep your streak going.</span></div>`
    : `<div class="finish-today" id="finishToday">
        <div class="ft__hd"><b>Finish today</b>${drills ? `<span class="muted">${tDone}/${tTotal} drills checked off</span>` : ''}</div>
        <div class="ft__grid">
          <div class="field"><span class="field__label">Energy</span>${scaleChips('energy')}</div>
          <div class="field"><span class="field__label">Soreness</span>${segChips('soreness', ['None', 'A little sore', 'Quite sore', 'Injured'])}</div>
          <div class="field"><span class="field__label">Motivation</span>${scaleChips('motivation')}</div>
          <div class="field"><span class="field__label">Effort <em class="field__opt">(1–5)</em></span>${scaleChips('rpe')}</div>
        </div>
        <label class="ft__rest"><input type="checkbox" id="ftRest" /> <span>Today was a planned rest day</span></label>
        <button type="button" class="btn btn--solid" id="completeTodayBtn">Complete today (+15 XP)</button>
      </div>`);

  const cta = finishToday + `
    <div class="week-actions">
      <button type="button" class="btn btn--ghost btn--sm" id="regenBtn">↻ Regenerate plan</button>
      ${canAdvance ? `<button type="button" class="btn btn--solid" id="weekAdvanceBtn">${advLabel} →</button>` : ''}
    </div>`;

  if (drills) {
    // Today's Workout — the most important card.
    const todayS = week[todayIdx];
    let todayHtml = '';
    if (todayS) {
      const rows = dayItems(todayS).map(it => drillRow(it)).join('');
      const total = dayItems(todayS).filter(it => it.kind === 'skill').length;
      const done = dayItems(todayS).filter(it => it.kind === 'skill' && dash.checks[it.key]).length;
      todayHtml = `
        <div class="today">
          <div class="today__hd">
            <div><span class="today__eyebrow">Today · ${e(todayS.dayName)}${todayS.sportLabel ? ' · <span class="daytag ' + dayTagClass(todayS) + '">' + e(todayS.sportLabel) + '</span>' : ''}</span><h3>${e(todayS.focus)}</h3></div>
            <span class="today__time">~${todayS.total} min · ${done}/${total} done</span>
          </div>
          <div class="dchecks">${rows}</div>
        </div>`;
    }

    // Color-coded weekly strip.
    const strip = week.map((s, i) => {
      let cls = 'upcoming';
      if (dayComplete(s)) cls = 'done';
      else if (i === todayIdx) cls = 'today';
      else if (i < todayIdx) cls = 'missed';
      else if (s.recovery) cls = 'rest';
      const n = dayItems(s).filter(it => it.kind === 'skill').length;
      return `
        <button type="button" class="wstrip__day wstrip__day--${cls}" data-day="${i}">
          <span class="wstrip__name">${e(s.dayName.slice(0, 3))}</span>
          ${s.sportLabel ? `<span class="daytag ${dayTagClass(s)}">${e(s.sportLabel)}</span>` : ''}
          <span class="wstrip__focus">${e(s.focus)}</span>
          <span class="wstrip__n">${n} drills · ~${s.total}m</span>
        </button>`;
    }).join('');
    const stripHtml = `<div class="wstrip"><div class="wstrip__hd"><b>This week</b><span class="wstrip__legend"><i class="lg lg--done"></i>Done <i class="lg lg--today"></i>Today <i class="lg lg--missed"></i>Missed</span></div><div class="wstrip__row">${strip}</div></div>`;

    // Full sessions (expandable detail kept for completeness).
    const sessions = week.map(s => {
      const rows = dayItems(s).map(it => drillRow(it)).join('');
      return `
        <div class="daycard daycard--live${dayComplete(s) ? ' daycard--done' : ''}">
          <div class="daycard__hd"><span class="daycard__day">${e(s.dayName)} · Day ${s.day}${s.sportLabel ? ' · <span class="daytag ' + dayTagClass(s) + '">' + e(s.sportLabel) + '</span>' : ''}</span><b>${e(s.focus)}</b><span class="daycard__time">~${s.total} min</span></div>
          <div class="dchecks">${rows}</div>
        </div>`;
    }).join('');

    dashMain.innerHTML = dashBriefing() + header + overview + dashWidgets() + dashAllocation() + todayHtml + stripHtml
      + `<details class="allweek"><summary>All sessions this week</summary><div class="daycards daycards--live">${sessions}</div></details>`
      + cta;

    dashMain.querySelectorAll('.dchk').forEach(row => {
      row.addEventListener('click', ev => {
        ev.preventDefault();
        const key = row.dataset.key, on = !dash.checks[key];
        if (on) dash.checks[key] = true; else delete dash.checks[key];
        addXp(on ? 10 : -10);
        checkBadges();
        renderDashboard();
      });
    });
    dashMain.querySelectorAll('.wstrip__day').forEach(b => b.addEventListener('click', () => {
      const det = dashMain.querySelector('.allweek'); if (det) det.open = true;
      const cards = dashMain.querySelectorAll('.daycards--live .daycard');
      const target = cards[Number(b.dataset.day)];
      if (target) target.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }));
    // Part 2: per-drill performance logging controls (quality / pain / cues).
    dashMain.querySelectorAll('.dperf').forEach(block => {
      const key = block.dataset.key;
      const get = () => (dash.perf[key] = dash.perf[key] || {});
      block.querySelectorAll('[data-q]').forEach(btn => btn.addEventListener('click', () => {
        const p = get();
        p.quality = (p.quality === btn.dataset.q) ? '' : btn.dataset.q;   // toggle off if same
        block.querySelectorAll('[data-q]').forEach(b => b.classList.toggle('on', b.dataset.q === p.quality));
        saveDash();
      }));
      const painBtn = block.querySelector('[data-pain]');
      if (painBtn) painBtn.addEventListener('click', () => {
        const p = get(); p.pain = !p.pain; painBtn.classList.toggle('on', p.pain); saveDash();
      });
      const moreBtn = block.querySelector('[data-more]');
      const detail = block.querySelector('.dperf__detail');
      if (moreBtn && detail) moreBtn.addEventListener('click', () => {
        detail.hidden = !detail.hidden; moreBtn.classList.toggle('on', !detail.hidden);
      });
    });
  } else {
    const objs = dash.tasks.map(t => `
      <div class="obj">
        <div class="obj__top"><span>${e(t.label)}</span><b>${t.done}/${t.target}</b></div>
        <div class="pips" data-task="${t.id}">
          ${Array.from({ length: t.target }).map((_, i) => `<button type="button" class="pip${i < t.done ? ' on' : ''}" data-i="${i}"></button>`).join('')}
        </div>
      </div>`).join('');
    dashMain.innerHTML = dashBriefing() + header + overview + `<div class="objs">${objs}</div>` + cta;
    dashMain.querySelectorAll('.pips').forEach(group => {
      const t = dash.tasks.find(x => x.id === group.dataset.task);
      group.querySelectorAll('.pip').forEach(p => {
        p.addEventListener('click', () => {
          const i = Number(p.dataset.i), old = t.done;
          const next = (t.done === i + 1) ? i : i + 1;
          t.done = next;
          addXp((next - old) * 10);
          checkBadges();
          renderDashboard();
        });
      });
    });
  }

  const regen = dashMain.querySelector('#regenBtn');
  if (regen) regen.addEventListener('click', () => {
    const hasProgress = dash.mode === 'drills' ? Object.keys(dash.checks || {}).length > 0 : dash.tasks.some(t => t.done > 0);
    if (hasProgress && !confirm('Regenerate this week\'s plan? Your check-marks for this week will be cleared.')) return;
    if (dash.mode === 'drills' && typeof drillCtx === 'function') {
      const ctx = drillCtx();
      if (ctx.plan) { dash.plan = ctx.plan; dash.checks = {}; }
    } else { dash.tasks = weekTasks(dash.week, buildCtx()); }
    queueCelebrate({ icon: '↻', title: 'Plan refreshed', body: 'Your plan was regenerated from the drill library using your latest profile.' });
    renderDashboard();
  });

  // Close the loop from the primary tab: finish + adapt + advance in one click.
  const adv = dashMain.querySelector('#weekAdvanceBtn');
  if (adv) adv.addEventListener('click', () => {
    if (dash.injury) { toast('Mark yourself cleared from recovery before advancing.'); return; }
    const p = weekPct();
    if (p < 50 && !confirm(`You've completed ${p}% of this week. Finish it and adapt your plan anyway?`)) return;
    activeTab = 'coach';            // finishWeek() ends with renderDashboard() → shows the review
    finishWeek();
  });

  // Finish-today feel capture (the unified daily logger).
  const feel = { energy: 3, motivation: 3, soreness: 'None', rpe: 3, rest: false };
  dashMain.querySelectorAll('.finish-today [data-seg]').forEach(group => {
    group.querySelectorAll('button').forEach(b => b.addEventListener('click', () => {
      group.querySelectorAll('button').forEach(x => x.classList.remove('selected'));
      b.classList.add('selected');
      const k = group.dataset.seg;
      feel[k] = group.dataset.scale ? Number(b.dataset.v) : b.dataset.v;
    }));
  });
  const restBox = dashMain.querySelector('#ftRest');
  if (restBox) restBox.addEventListener('change', () => { feel.rest = restBox.checked; });
  const doneBtn = dashMain.querySelector('#completeTodayBtn');
  if (doneBtn) doneBtn.addEventListener('click', () => completeToday(feel));

  // Injury "resume" — explicit, athlete-confirmed exit from recovery mode.
  const resume = dashMain.querySelector('#injuryResume');
  if (resume) resume.addEventListener('click', () => {
    if (!confirm('Only resume if you are pain-free and cleared to train. We\'ll rebuild this week from your plan.')) return;
    dash.injury = null;
    if (typeof drillCtx === 'function') { const ctx = drillCtx(); if (ctx && ctx.plan) { dash.plan = ctx.plan; dash.checks = {}; dash.perf = {}; } }
    dash.adapt = 'Welcome back — rebuilt your week. Ease back in and stop if anything hurts.';
    renderDashboard();
  });

  wireWeekButtons();
}
function stat(value, label) { return `<div class="stat"><b>${value}</b><span>${e(label)}</span></div>`; }
function miniCard(icon, value, label, wide) {
  return `<div class="mcard${wide ? ' mcard--wide' : ''}"><span class="mcard__icon">${icon}</span>${value !== '' ? `<b class="mcard__v">${value}</b>` : ''}<span class="mcard__l">${e(label)}</span></div>`;
}
function dayTagClass(s) { return s.crossover ? 'daytag--cross' : s.recovery ? 'daytag--rest' : 'daytag--sport'; }
// Per-sport completion bars (dual-sport dashboards).
function perSportProgress(week) {
  const buckets = {};
  (dash.sports || []).forEach(l => buckets[l] = { done: 0, total: 0 });
  buckets['Crossover & recovery'] = { done: 0, total: 0 };
  week.forEach(s => {
    const key = (dash.sports || []).includes(s.sportLabel) ? s.sportLabel : 'Crossover & recovery';
    dayItems(s).filter(it => it.kind === 'skill').forEach(it => {
      buckets[key].total += 1;
      if (dash.checks[it.key]) buckets[key].done += 1;
    });
  });
  const bars = Object.keys(buckets).filter(k => buckets[k].total > 0).map(k => {
    const b = buckets[k]; const p = pct(b.done, b.total);
    return `<div class="psp"><div class="psp__top"><span>${e(k)}</span><b>${p}%</b></div><div class="psp__track"><i style="width:${p}%"></i></div><span class="psp__n">${b.done}/${b.total} drills</span></div>`;
  }).join('');
  return `<div class="psp__wrap"><div class="psp__title">Progress by sport</div><div class="psp__grid">${bars}</div></div>`;
}
function drillRow(it) {
  const on = !!dash.checks[it.key];
  const meta = it.kind === 'skill'
    ? `<span class="dchk__meta">${e(it.item.d.skill_category)} · ${e(it.item.sets)} · ${it.item.d.estimated_duration_minutes} min · ${e((typeof DIFF_LABEL !== 'undefined' && DIFF_LABEL[it.item.d.difficulty_level]) || it.item.d.difficulty_level || '')}</span>`
    : '';
  const why = it.kind === 'skill' && it.item.reasons && it.item.reasons.length
    ? `<span class="dchk__why">Why: it ${e(it.item.reasons.slice(0, 1).join(''))}.</span>` : '';
  const tag = it.item && it.item._eased ? ' <span class="dtag dtag--eased">Eased</span>'
    : it.item && it.item._boosted ? ' <span class="dtag dtag--boost">Boosted</span>' : '';
  const label = `
    <label class="dchk${on ? ' on' : ''}" data-key="${it.key}" data-kind="${it.kind}">
      <input type="checkbox" ${on ? 'checked' : ''} />
      <span class="dchk__box"></span>
      <span class="dchk__txt"><b>${e(it.label)}</b>${tag}${meta}${why}</span>
    </label>`;
  if (it.kind !== 'skill') return `<div class="drow">${label}</div>`;
  // Part 2: per-drill performance logging — how it felt drives real progression,
  // not just a checkmark. Plus an expandable cue + common-mistakes panel.
  const d = it.item.d;
  const perf = (dash.perf && dash.perf[it.key]) || {};
  const q = perf.quality || '';
  const cue = d.coaching_notes ? `<p class="dperf__cue"><b>Cue:</b> ${e(d.coaching_notes)}</p>` : '';
  const how = d.how_to ? `<p class="dperf__how"><b>How:</b> ${e(d.how_to)}</p>` : '';
  const miss = (d.mistakes && d.mistakes.length) ? `<p class="dperf__miss"><b>Avoid:</b> ${e(d.mistakes.slice(0, 3).join(' · '))}</p>` : '';
  const safe = d.safety ? `<p class="dperf__safe"><b>Safety:</b> ${e(d.safety)}</p>` : '';
  const perfBlock = `
    <div class="dperf" data-key="${it.key}">
      <div class="dperf__row">
        <span class="dperf__lbl">How did it feel?</span>
        <span class="dperf__q">
          <button type="button" data-q="easy" class="dperf__chip${q === 'easy' ? ' on' : ''}">Too easy</button>
          <button type="button" data-q="right" class="dperf__chip${q === 'right' ? ' on' : ''}">Just right</button>
          <button type="button" data-q="hard" class="dperf__chip${q === 'hard' ? ' on' : ''}">Too hard</button>
        </span>
        <button type="button" class="dperf__pain${perf.pain ? ' on' : ''}" data-pain>Pain</button>
        <button type="button" class="dperf__more" data-more>Cues &amp; mistakes</button>
      </div>
      <div class="dperf__detail" hidden>${how}${cue}${miss}${safe}</div>
    </div>`;
  return `<div class="drow">${label}${perfBlock}</div>`;
}
// Header buttons shared by both dashboard modes.
function wireWeekButtons() {
  const dl = dashMain.querySelector('#cpDownload');
  if (dl) dl.addEventListener('click', (e) => {
    // Real branded PDF of the CURRENT dashboard plan (reflects week/level after progress).
    if (window.downloadPlanPdf && dash && dash.plan && dash.plan.week) {
      window.downloadPlanPdf(e.currentTarget, { plan: dash.plan, profile: dash.profile, sport: (window.state && state.data && (state.data.sportsChosen || [])[0]) || '' });
    } else { downloadReport('training', false); }
  });
  const lib = dashMain.querySelector('#cpLibrary');
  if (lib) lib.addEventListener('click', () => openLibrary());
}

/* ---- Unified daily logger (folded into the Today view) ----
   "Did you complete today?" is no longer self-reported — it's DERIVED from the
   drills you actually checked off. The feel inputs (energy/soreness/motivation/
   effort) still drive the immediate adaptation, streak, and training load. ---- */
function completeToday(feel) {
  const today = todayStr();
  if (dash.lastCheckinDate === today) { toast('Already logged today — come back tomorrow.'); return; }
  const week = (dash.plan && dash.plan.week) || [];
  const idx = week.length ? (dash.day % week.length) : 0;
  const s = week[idx];
  // Single completion signal: did = derived from real check-offs.
  let did;
  if (feel.rest) did = 'Rest day';
  else if (dash.mode === 'drills') {
    const done = s ? dayItems(s).filter(it => it.kind === 'skill' && dash.checks[it.key]).length : 0;
    did = done > 0 ? 'Yes' : 'Missed it';
  } else {
    // tasks mode: treat a non-rest log as a training day
    did = 'Yes';
  }
  submitCheckin({ did, energy: feel.energy, motivation: feel.motivation, soreness: feel.soreness, rpe: feel.rpe });
}
function segChips(key, opts, preselect = true) {
  return `<div class="seg" data-seg="${key}">${opts.map((o, i) => `<button type="button" class="chip${preselect && i === 0 ? ' selected' : ''}" data-v="${e(o)}">${e(o)}</button>`).join('')}</div>`;
}
function scaleChips(key) {
  return `<div class="seg seg--scale" data-seg="${key}" data-scale="1">${[1, 2, 3, 4, 5].map(n => `<button type="button" class="chip${n === 3 ? ' selected' : ''}" data-v="${n}">${n}</button>`).join('')}</div>`;
}
function submitCheckin(sel) {
  const today = todayStr();
  // One check-in per real calendar day — streaks reflect actual consecutive days.
  if (dash.lastCheckinDate === today) {
    queueCelebrate({ icon: '', title: 'Already checked in today', body: 'Come back tomorrow to keep the streak going. One honest check-in per day.' });
    flushCelebrations();
    return;
  }
  const gap = dash.lastCheckinDate ? daysBetween(dash.lastCheckinDate, today) : null;
  dash.day += 1;
  // session-RPE training load (sRPE × minutes) — fuels the acute:chronic guard.
  const mins = (dash.profile && dash.profile.minutes) || 35;
  const load = sel.did === 'Yes' ? (Number(sel.rpe) || 3) * 2 * mins : 0;
  dash.checkins.push({ day: dash.day - 1, date: today, load, ...sel });

  // streak: a consecutive day extends it; a gap or a missed day resets it
  if (sel.did === 'Missed it') {
    dash.streak = 0;
  } else if (sel.did === 'Yes') {
    dash.streak = (gap === 1) ? dash.streak + 1 : 1;   // first ever, or returning after a gap → restart at 1
    dash.workoutsCompleted += 1;
  } else if (gap !== null && gap > 1) {                 // Rest day after a gap still breaks the streak
    dash.streak = 0;
  }
  dash.lastCheckinDate = today;
  dash.bestStreak = Math.max(dash.bestStreak, dash.streak);

  // credit the weekly "daily check-in" objective (generic mode only)
  if (dash.tasks) { const ci = dash.tasks.find(t => t.id === 'checkin'); if (ci && ci.done < ci.target) ci.done += 1; }

  // AI adaptation — the check-in now actually rewrites the remaining plan.
  const adaptRes = applyDailyAdaptation(sel);
  dash.adapt = adaptRes.note;

  addXp(15);
  if (sel.did === 'Yes') addXp(5);
  checkBadges();
  // Surface the change: jump to the (now-updated) week so it isn't invisible.
  if (adaptRes.changed) {
    activeTab = 'week'; syncTabs();
    queueCelebrate({
      icon: adaptRes.kind === 'injury' ? '🩹' : adaptRes.kind === 'boost' ? '⬆' : '↻',
      title: adaptRes.kind === 'injury' ? 'Recovery mode on' : 'Plan updated',
      body: adaptRes.note
    });
  }
  renderDashboard();
}
/* =========================================================
   Daily adaptation — the check-in now ACTUALLY changes the plan
   (the remaining, not-yet-completed drills of the current week),
   and injury/pain de-loads immediately + flips a safety gate.
   ========================================================= */
const REC_BASE = [
  { id: 'rec_mobility', drill_name: 'Gentle full-body mobility flow', skill_category: 'Recovery',
    estimated_duration_minutes: 8, difficulty_level: 'beginner',
    how_to: 'Move slowly through pain-free range of motion — neck, shoulders, hips, ankles. 1–2 easy rounds.',
    coaching_notes: 'Only move in ranges that do not hurt. This is about blood flow, not effort.',
    mistakes: ['Pushing into pain', 'Rushing the reps'], safety: 'Stop immediately if anything hurts.' },
  { id: 'rec_walk', drill_name: 'Easy walk or light cardio', skill_category: 'Recovery',
    estimated_duration_minutes: 10, difficulty_level: 'beginner',
    how_to: 'Easy walk, bike, or pool at a conversational pace. No sprinting, jumping, or cutting.',
    coaching_notes: 'Light movement supports recovery without loading the injury.',
    mistakes: ['Going too hard'], safety: 'Skip it if movement is painful.' },
  { id: 'rec_stretch', drill_name: 'Gentle static stretching', skill_category: 'Recovery',
    estimated_duration_minutes: 8, difficulty_level: 'beginner',
    how_to: 'Hold easy stretches 20–30s for the muscle groups that feel tight — never the injured area if it hurts.',
    coaching_notes: 'Breathe and relax into each hold. No bouncing.',
    mistakes: ['Stretching an injured area into pain'], safety: 'Avoid any stretch that causes pain.' },
];
function recoveryItemAt(k, sport) {
  const d = Object.assign({}, REC_BASE[k % REC_BASE.length], { sport: sport || 'recovery' });
  return { d, role: 'Recovery', reasons: ['supports recovery without loading the injury'], sets: '1–2 easy rounds' };
}
function stripNote(s) { return String(s || '').replace(/ · (eased|lighter \(full rest\)|\+1 set)$/, ''); }

// Rewrite only the UNCOMPLETED drills of the current week (completed work is left
// untouched so checkmarks/keys stay stable). mode: 'recover' | 'easier' | 'lighter'.
function deloadOrRecover(mode) {
  const week = (dash.plan && dash.plan.week) || [];
  let recK = 0, changed = 0;
  week.forEach(s => {
    let sChanged = 0;
    (s.drills || []).forEach((x, i) => {
      if (dash.checks['d' + s.day + '_' + i]) return;          // never touch completed work
      if (mode === 'recover') { s.drills[i] = recoveryItemAt(recK++, s.sportLabel || dash.sport); }
      else if (mode === 'easier') {
        const easier = (typeof regressDrill === 'function') ? regressDrill(x.d, dash.profile) : x.d;
        s.drills[i] = { d: easier, role: x.role, reasons: x.reasons, sets: stripNote(x.sets) + ' · eased', _eased: true };
      } else { // lighter
        s.drills[i] = Object.assign({}, x, { sets: stripNote(x.sets) + ' · lighter (full rest)', _eased: true });
      }
      sChanged++; changed++;
    });
    if (mode === 'recover' && sChanged) { s.focus = 'Recovery & mobility'; s.recovery = true; s.crossover = false; }
  });
  return changed;
}
function boostRemaining() {
  const week = (dash.plan && dash.plan.week) || [];
  let changed = 0;
  week.forEach(s => {
    const idx = (s.drills || []).findIndex((x, i) => !dash.checks['d' + s.day + '_' + i]);
    if (idx < 0) return;
    const x = s.drills[idx];
    const harder = (typeof progressDrill === 'function') ? progressDrill(x.d, dash.profile) : x.d;
    s.drills[idx] = { d: harder, role: x.role, reasons: x.reasons, sets: stripNote(x.sets) + ' · +1 set', _boosted: true };
    changed++;
  });
  return changed;
}

// Decide + apply today's adaptation; return { changed, kind, note }.
function applyDailyAdaptation(sel) {
  // Injury → immediate recovery week + safety gate.
  if (sel.soreness === 'Injured') {
    dash.injury = { date: todayStr() };
    const n = deloadOrRecover('recover');
    return { changed: true, kind: 'injury',
      note: `Injury logged — the rest of this week is now recovery & mobility only (${n} drill${n !== 1 ? 's' : ''} swapped). Stop training and check with a parent, coach, or healthcare professional before resuming.` };
  }
  // Pain flagged on any drill today, or "quite sore" → de-load to easier variations.
  const painToday = !!(dash.perf && Object.values(dash.perf).some(p => p && p.pain));
  if (sel.soreness === 'Quite sore' || painToday) {
    const n = deloadOrRecover('easier');
    return { changed: n > 0, kind: 'deload',
      note: `Soreness/pain noted — eased your remaining drills to easier variations with more rest${n ? ` (${n} updated)` : ''}. Stop any drill that hurts.` };
  }
  // Low energy → lighter volume on remaining work.
  if (Number(sel.energy) <= 2) {
    const n = deloadOrRecover('lighter');
    return { changed: n > 0, kind: 'light',
      note: `Low energy today — your remaining drills are set to lighter sets with full rest${n ? ` (${n} updated)` : ''}. Prioritize sleep and food tonight.` };
  }
  // Strong day → small progression on remaining sessions.
  if (sel.did === 'Yes' && Number(sel.energy) >= 4) {
    const n = boostRemaining();
    return { changed: n > 0, kind: 'boost',
      note: `Feeling strong — added a small progression to your remaining sessions${n ? ` (${n} updated)` : ''}.` };
  }
  // Low motivation → ease the remaining work so wins come quicker.
  if (Number(sel.motivation) <= 2) {
    const n = deloadOrRecover('easier');
    return { changed: n > 0, kind: 'motivation',
      note: `Motivation dipped — eased the remaining work so you can stack some quick wins${n ? ` (${n} updated)` : ''}.` };
  }
  return { changed: false, kind: 'ontrack', note: 'On track — your plan stays as scheduled. Nice consistency.' };
}

/* ---- Progress ---- */
function tabProgress() {
  const lvl = computeLevel(dash.xp);
  const cur = totalXpForLevel(lvl), next = totalXpForLevel(lvl + 1);
  const earned = BADGES.filter(b => dash.badges[b.id]);
  const locked = BADGES.filter(b => !dash.badges[b.id]);
  const hist = dash.history.concat([{ week: dash.week, pct: weekPct() }]);

  dashMain.innerHTML = `
    <div class="dash-head"><div><span class="dash-eyebrow">Visual progress</span><h2>Your development</h2></div></div>

    <div class="stat-row">
      ${stat('Lv ' + lvl, 'Athlete level')}
      ${stat(dash.bestStreak, 'Best streak')}
      ${stat(dash.workoutsCompleted, 'Workouts done')}
      ${stat(goalCompletion() + '%', 'Goals progress')}
    </div>

    ${capHistoryHtml()}
    ${loadGuardHtml()}

    <div class="card">
      <h4>Level ${lvl} → ${lvl + 1}</h4>
      <div class="bigbar"><div class="bigbar__fill" style="width:${pct(dash.xp - cur, next - cur)}%"></div></div>
      <p class="muted">${dash.xp - cur} / ${next - cur} XP to next level · ${dash.xp} XP total</p>
    </div>

    <div class="card">
      <h4>Weekly completion history</h4>
      <div class="histbars">
        ${hist.map(h => `<div class="histbar"><div class="histbar__col"><div class="histbar__fill" style="height:${h.pct}%"></div></div><span>W${h.week}</span></div>`).join('')}
      </div>
    </div>

    <div class="card">
      <h4>Goal completion</h4>
      ${dash.goals.length ? dash.goals.map(g => `
        <div class="goalbar"><span>${e(g.text)}</span><div class="minibar"><div class="minibar__fill" style="width:${g.progress}%"></div></div><b>${g.progress}%</b></div>`).join('') : '<p class="muted">No goals committed yet — add some in the Goals tab.</p>'}
    </div>

    <div class="card">
      <h4>Milestones &amp; badges</h4>
      <div class="badges">
        ${earned.map(b => `<div class="badge earned" title="${e(b.desc)}"><span>${b.icon}</span><b>${e(b.label)}</b></div>`).join('')}
        ${locked.map(b => `<div class="badge locked" title="${e(b.desc)}"><span></span><b>${e(b.label)}</b></div>`).join('')}
      </div>
    </div>`;
}

/* ---- AI Coach (weekly review + advance) ---- */
function tabCoach() {
  const canFinish = dash.week <= dash.maxWeeks;
  dashMain.innerHTML = `
    <div class="dash-head"><div><span class="dash-eyebrow">Sunday review</span><h2>AI coach review</h2></div></div>
    <p class="dash-sub">Every week your coach reviews the data and adjusts the plan.</p>
    ${(function () { const s = coachSummary(); return s ? `<div class="card coach-read"><h4>Coach read</h4><p>${e(s)}</p></div>` : ''; })()}
    <div id="reviewBox">${dash.review ? reviewHtml(dash.review) : '<p class="muted">Finish the week to generate your first review.</p>'}</div>
    ${canFinish ? `<button type="button" class="btn btn--solid dash-cta" id="finishWeekBtn">Generate review &amp; ${dash.week < dash.maxWeeks ? 'start week ' + (dash.week + 1) : 'complete program'} →</button>`
      : `<div class="ai-note"><b>Program complete!</b> ${dash.tier === 'free' ? 'Upgrade to membership to keep progressing with new plans.' : 'Time for a monthly reassessment to set the next block.'}</div>`}
  `;
  const btn = dashMain.querySelector('#finishWeekBtn');
  if (btn) btn.addEventListener('click', finishWeek);
}
function reviewHtml(r) {
  // Backward-compatible: render the old short shape if that's all we have.
  if (!r.report) {
    return `
      <div class="review">
        <div class="review__hd"><b>Week ${r.week} review</b><span>${r.pct}% complete · score ${r.score}</span></div>
        <div class="review__sec"><h5>What went well</h5><p>${e(r.well || '')}</p></div>
        <div class="review__sec"><h5>Areas to improve</h5><p>${e(r.improve || '')}</p></div>
        <div class="review__sec"><h5>Progress toward goals</h5><p>${e(r.progress || '')}</p></div>
        <div class="review__sec"><h5>Recommended adjustments</h5><p>${e(r.adjust || '')}</p></div>
      </div>`;
  }
  const R = r.report;
  const list = arr => (arr && arr.length) ? `<ul class="review__list">${arr.map(x => `<li>${e(x)}</li>`).join('')}</ul>` : '<p class="muted">—</p>';
  const intensityChip = `<span class="review__intensity review__intensity--${(R.intensity || '').toLowerCase()}">${e(R.intensity)} intensity</span>`;
  const aiBadge = R.aiUsed ? '<span class="review__ai">✦ Sporve AI</span>' : '';
  const aiSummary = R.aiSummary ? `<div class="ai-note review__summary"><b>${R.aiUsed ? '✦ Coach review' : 'Coach review'}</b> ${e(R.aiSummary)}</div>` : '';
  const aiSafety = (R.aiSafety && R.aiSafety.length) ? `<div class="review__sec review__sec--safety"><h5>⚠ Safety</h5>${list(R.aiSafety)}</div>` : '';
  return `
    <div class="review">
      <div class="review__hd"><b>Week ${r.week} review ${aiBadge}</b><span>${R.completion}% complete · score ${r.score} ${intensityChip}</span></div>
      <div class="review__bar"><div class="review__barfill" style="width:${R.completion}%"></div></div>
      ${aiSummary}
      ${aiSafety}
      <div class="review__sec"><h5>Best-performing areas</h5>${list(R.best)}</div>
      <div class="review__sec"><h5>Weakest areas</h5>${list(R.weak)}</div>
      <div class="review__sec"><h5>⏭Missed drills</h5>${list(R.missed)}</div>
      <div class="review__sec"><h5>What I'm changing &amp; why</h5>${list(R.changes)}</div>
      <div class="review__sec"><h5>New drills next week</h5>${list(R.newDrills)}</div>
      ${(R.aiImprovements && R.aiImprovements.length) ? `<div class="review__sec"><h5>Coach highlights</h5>${list(R.aiImprovements)}</div>` : ''}
      <div class="review__sec"><h5>Updated goals</h5><p>${e(R.goals)}</p></div>
      <div class="review__sec"><h5>Coach's note</h5><p>${e(R.motivation)}</p></div>
      <div class="review__sec"><h5>Next week</h5>${list(R.nextPlan)}</div>
    </div>`;
}

// Tally completion by drill / category from this week's checkmarks.
function weekStats() {
  const skill = allItems().filter(it => it.kind === 'skill');
  const total = skill.length || 1;
  const done = skill.filter(it => dash.checks[it.key]);
  const doneCats = {}, missedCats = {};
  const doneDrillIds = new Set(), missedDrillIds = new Set();
  const missedDrillNames = [], doneDrillNames = [];
  // Part 2: per-drill achieved quality → drives drill-level progression/regression.
  const easyIds = new Set(), hardIds = new Set(), painIds = new Set();
  skill.forEach(it => {
    const cat = it.item.d.skill_category, id = it.item.d.id, name = it.item.d.drill_name;
    if (dash.checks[it.key]) { doneCats[cat] = (doneCats[cat] || 0) + 1; doneDrillIds.add(id); doneDrillNames.push(name); }
    else { missedCats[cat] = (missedCats[cat] || 0) + 1; missedDrillIds.add(id); missedDrillNames.push(name); }
    const perf = dash.perf && dash.perf[it.key];
    if (perf) {
      if (perf.quality === 'easy') easyIds.add(id);
      else if (perf.quality === 'hard') hardIds.add(id);
      if (perf.pain) painIds.add(id);
    }
  });
  return { pct: Math.round(done.length / total * 100), total, doneCount: done.length, doneCats, missedCats, doneDrillIds, missedDrillIds, missedDrillNames, doneDrillNames, easyIds, hardIds, painIds };
}

function finishWeek() {
  const score = weekScore();
  const isDrills = dash.mode === 'drills' && dash.plan && dash.plan.week;
  const stats = isDrills ? weekStats() : { pct: weekPct(), missedCats: {}, doneCats: {}, missedDrillNames: dash.tasks ? dash.tasks.filter(t => t.done < t.target).map(t => t.label) : [], doneDrillNames: [] };
  const p = stats.pct;

  dash.history.push({ week: dash.week, pct: p, score });
  if (p >= 100) { dash.weeksPerfect += 1; addXp(100); } else addXp(50);

  const advancing = dash.week < dash.maxWeeks;
  let report = null, narrateInputs = null;

  if (isDrills) {
    const prevPlan = dash.plan;
    // transient copy: weekInBlock + recentIds (a Set) drive periodization & novelty
    // but must NOT be persisted onto dash.profile (a Set can't survive JSON).
    const baseProf = dash.profile || (typeof profileFromData === 'function' ? profileFromData() : null);
    const prof = baseProf ? Object.assign({}, baseProf) : null;
    if (prof) {
      prof.weekInBlock = dash.week + 1;
      prof.recentIds = new Set(prevPlan.week.reduce((a, s) => a.concat(s.drills.map(x => x.d.id)), []));
    }
    let adaptation = { direction: 'maintain', intensityLabel: 'Maintained', changes: [], missedCats: [] };
    if (advancing && prof && typeof adaptWeek === 'function') {
      const res = adaptWeek(prof, prevPlan, stats);
      adaptation = res.adaptation;
      // Names new to next week (vs the week just finished) = the "new drills".
      const prevNames = new Set(prevPlan.week.reduce((a, s) => a.concat(s.drills.map(x => x.d.drill_name)), []));
      const nextNames = res.plan.week.reduce((a, s) => a.concat(s.drills.map(x => x.d.drill_name)), []);
      report = buildWeekReport(stats, adaptation, res.plan, [...new Set(nextNames.filter(n => !prevNames.has(n)))]);
      dash.plan = res.plan;
      dash.checks = {};
      dash.adapt = adaptation.changes[0] || '';
    } else {
      report = buildWeekReport(stats, adaptation, prevPlan, []);
    }
    // Inputs for the AI NARRATOR — names + felt-difficulty captured from the
    // week just finished (before dash.plan was swapped to next week).
    const idName = {};
    prevPlan.week.forEach(s => (s.drills || []).forEach(x => { idName[x.d.id] = x.d.drill_name; }));
    const diffRatings = {};
    (stats.easyIds || new Set()).forEach(id => { diffRatings[idName[id] || id] = 'easy'; });
    (stats.hardIds || new Set()).forEach(id => { diffRatings[idName[id] || id] = 'hard'; });
    const painNotes = Array.from(stats.painIds || []).map(id => (idName[id] || ('drill ' + id)) + ': pain reported');
    narrateInputs = { diffRatings, painNotes };
  }

  dash.review = report
    ? { week: dash.week, pct: p, score, report }
    : { week: dash.week, pct: p, score,
        well: p >= 80 ? `Strong week at ${p}%.` : p >= 50 ? `Solid effort at ${p}%.` : `Light week (${p}%) — let's rebuild.`,
        improve: 'Focus on what you missed next week.', progress: `Goal progress ${goalCompletion()}%.`,
        adjust: p >= 90 ? 'Adding a small progression next week.' : 'Keeping volume steady next week.' };

  // #7 — ONE narrator: adaptWeek already decided the plan; ask the server AI to
  // write the coach voice over those decisions (async, grounded, optional).
  if (report) maybeNarrate(stats, report, narrateInputs);

  // Persist the weekly report as a progress log (best-effort).
  if (window.API && API.isAuthed() && dash._planId) {
    API.logProgress({ plan_id: dash._planId, kind: 'week', payload: { week: dash.week, pct: p, report } }).catch(() => {});
  }

  if (advancing) {
    dash.week += 1;
    if (!isDrills) dash.tasks = weekTasks(dash.week, buildCtx());
    queueCelebrate({ icon: '', title: `Week ${dash.week} ready`, body: report ? `Plan adapted: ${e(report.intensity)} intensity. ${e((report.changes[0] || ''))}` : 'Your next week is ready.' });
  } else {
    dash.week = dash.maxWeeks + 1;
    queueCelebrate({ icon: '', title: 'Program complete!', body: dash.tier === 'free' ? 'You finished the free block. Upgrade to keep progressing.' : 'Block complete — run a monthly reassessment to set your next phase.' });
  }
  checkBadges();
  renderDashboard();
}

// #7 — the single grounded NARRATOR. Sends the deterministic stats + the
// adaptation the engine already chose; merges the AI's coach voice into the
// review when it returns. Never decides drills; deterministic text is the floor.
function maybeNarrate(stats, report, inputs) {
  if (!report || !(window.Athlon && typeof Athlon.coachReview === 'function')) return;
  const reviewId = dash.review && dash.review.week;
  const payload = {
    completedDrills: stats.doneDrillNames || [],
    missedDrills: stats.missedDrillNames || [],
    difficultyRatings: (inputs && inputs.diffRatings) || {},
    painNotes: (inputs && inputs.painNotes) || [],
    completionPct: stats.pct,
    adaptation: { intensity: report.intensity, changes: report.changes || [] },
    sport: dash.sport || dash.focus || '', week: reviewId,
    athleteAge: (dash.profile && dash.profile.age) || null
  };
  Athlon.coachReview(payload).then(out => {
    if (!out || !out.update) return;
    if (!dash.review || dash.review.week !== reviewId || !dash.review.report) return;   // user moved on
    const u = out.update, r = dash.review.report;
    if (u.weeklySummary) r.aiSummary = u.weeklySummary;
    if (u.motivationMessage) r.motivation = u.motivationMessage;
    if (Array.isArray(u.improvements) && u.improvements.length) r.aiImprovements = u.improvements.slice(0, 4);
    if (Array.isArray(u.safetyFlags) && u.safetyFlags.length) r.aiSafety = u.safetyFlags.slice(0, 2);
    r.aiUsed = !!(out.meta && out.meta.aiUsed);
    saveDash();
    if (activeTab === 'coach') renderDashboard();
  }).catch(() => {});
}

// Assemble the 10-part weekly report from stats + the adaptation result.
function buildWeekReport(stats, adaptation, nextPlan, newDrillNames) {
  const catRatio = {};
  Object.keys(stats.doneCats || {}).forEach(c => { catRatio[c] = (catRatio[c] || 0) + stats.doneCats[c]; });
  const best = Object.keys(stats.doneCats || {}).filter(c => !(stats.missedCats || {})[c]).slice(0, 4);
  const weak = Object.keys(stats.missedCats || {}).sort((a, b) => stats.missedCats[b] - stats.missedCats[a]).slice(0, 4);
  const missed = (stats.missedDrillNames || []).slice(0, 6);
  const nextSummary = (nextPlan.week || []).map(s => `${s.dayName}: ${s.focus} (${s.drills.length} drills, ~${s.total} min)`);
  const dir = adaptation.direction;
  const motivation = dir === 'increase'
    ? `Great consistency — you earned a tougher week. Keep the same effort and the harder drills will feel normal fast.`
    : dir === 'decrease'
      ? `No guilt about a lighter week. Next week is shorter and simpler so you can string together wins and rebuild momentum.`
      : `Steady work. Lock in this consistency and we'll add load as soon as you're ready.`;
  const goals = weak.length
    ? `Close the gap in ${weak.map(c => c.toLowerCase()).join(', ')} while holding your strengths.`
    : `Keep progressing your strongest areas and chase your next benchmark.`;
  return {
    completion: stats.pct,
    best: best.length ? best : ['Showing up and logging your week'],
    weak: weak.length ? weak : ['Nothing major — great coverage'],
    missed: missed.length ? missed : ['None — you completed everything'],
    changes: adaptation.changes || [],
    newDrills: (newDrillNames && newDrillNames.length) ? newDrillNames.slice(0, 6) : ['Same core drills, progressed in difficulty/volume'],
    intensity: adaptation.intensityLabel || 'Maintained',
    goals, motivation, nextPlan: nextSummary
  };
}

/* ---- Goals (monthly commitments) ---- */
function tabGoals() {
  const sugg = ['Improve sprint speed', 'Increase strength', 'Make the school team', 'Improve confidence', 'Build endurance', 'Sharpen skills'];
  dashMain.innerHTML = `
    <div class="dash-head"><div><span class="dash-eyebrow">Monthly commitments</span><h2>Your goals</h2></div></div>
    <p class="dash-sub">Commit to what matters this month. Set each target's progress as you go — it factors into your weekly reviews and parent report.</p>

    <div class="goal-list">
      ${dash.goals.length ? dash.goals.map((g, i) => `
        <div class="goal-item">
          <div class="goal-item__top"><b>${e(g.text)}</b><button type="button" class="linkbtn linkbtn--sm" data-del="${i}">remove</button></div>
          <input type="range" min="0" max="100" value="${g.progress}" data-goal="${i}" />
          <span class="goal-item__pct">${g.progress}% toward this goal</span>
        </div>`).join('') : '<p class="muted">No goals yet. Add one below.</p>'}
    </div>

    <div class="goal-add">
      <div class="seg seg--wrap">${sugg.map(s => `<button type="button" class="chip" data-add="${e(s)}">+ ${e(s)}</button>`).join('')}</div>
      <div class="goal-add__custom">
        <input type="text" id="goalCustom" placeholder="Write your own goal…" />
        <button type="button" class="btn btn--ghost btn--sm" id="goalAddBtn">Add</button>
      </div>
    </div>`;

  dashMain.querySelectorAll('[data-goal]').forEach(r => r.addEventListener('input', () => {
    dash.goals[Number(r.dataset.goal)].progress = Number(r.value);
    r.nextElementSibling.textContent = r.value + '% toward this goal';
    saveDash(); renderHud();
  }));
  dashMain.querySelectorAll('[data-del]').forEach(b => b.addEventListener('click', () => { dash.goals.splice(Number(b.dataset.del), 1); renderDashboard(); }));
  dashMain.querySelectorAll('[data-add]').forEach(b => b.addEventListener('click', () => addGoal(b.dataset.add)));
  dashMain.querySelector('#goalAddBtn').addEventListener('click', () => {
    const v = dashMain.querySelector('#goalCustom').value.trim();
    if (v) addGoal(v);
  });
}
function addGoal(text) {
  if (dash.goals.some(g => g.text === text)) return;
  dash.goals.push({ text, progress: 0 });
  renderDashboard();
}

/* ---- Monthly reassessment ---- */
function tabReassess() {
  const first = dash.metrics[0] || {};
  const due = (dash.week - 1) % 4 === 0 && dash.week > 1;
  const tests = (typeof window !== 'undefined' && window.BASELINE_TESTS) || [];
  const sportKey = (typeof getSportKey === 'function') ? getSportKey() : '';
  const skill = ((typeof window !== 'undefined' && window.SPORT_SKILL_TESTS) || {})[sportKey];
  const blInputs = tests.map(t =>
    `<label class="field"><span class="field__label">${e(t.label)} (${e(t.unit)})</span>` +
    `<input type="number" id="ra_${t.id}" value="${data()[t.id] != null ? data()[t.id] : ''}" placeholder="${e(t.ph)}" /></label>`).join('');
  const skillInput = skill
    ? `<label class="field"><span class="field__label">${e(skill.label)} (${e(skill.unit)})</span><input type="number" id="ra_bl_skill" value="${data().bl_skill != null ? data().bl_skill : ''}" placeholder="${e(skill.ph)}" /></label>`
    : '';

  dashMain.innerHTML = `
    <div class="dash-head"><div><span class="dash-eyebrow">Re-test &amp; recalculate</span><h2>Re-measure your baseline</h2></div></div>
    <p class="dash-sub">${due ? 'A re-test is due — re-run the same tests so we can measure real change and rebuild your plan.' : 'Re-run the same tests every ~4 weeks. We turn them into percentiles, measure your progress, and rebuild the plan around your new weak spots.'}</p>

    <form id="reassessForm">
      <div class="field-grid">
        <label class="field"><span class="field__label">Height (in)</span><input type="number" id="raHeight" value="${first.height || ''}" placeholder="e.g. 61" /></label>
        <label class="field"><span class="field__label">Weight (lbs)</span><input type="number" id="raWeight" value="${first.weight || ''}" placeholder="e.g. 115" /></label>
      </div>
      <div class="field"><span class="field__label">Re-test results <em class="field__opt">enter the same tests you did at the start — any you have</em></span></div>
      <div class="field-grid bl-grid">${blInputs}</div>
      ${skillInput ? `<div class="field-grid bl-grid">${skillInput}</div>` : ''}
      <button type="submit" class="btn btn--solid">Re-test &amp; rebuild my plan (+40 XP)</button>
    </form>

    ${capHistoryHtml()}`;

  dashMain.querySelector('#reassessForm').addEventListener('submit', ev => {
    ev.preventDefault();
    // 1) write the new test numbers back into the athlete profile
    tests.forEach(t => {
      const el = dashMain.querySelector(`#ra_${t.id}`);
      if (el) data()[t.id] = el.value === '' ? '' : Number(el.value);
    });
    const sk = dashMain.querySelector('#ra_bl_skill');
    if (sk) data().bl_skill = sk.value === '' ? '' : Number(sk.value);
    const h = Number(dashMain.querySelector('#raHeight').value) || '';
    const w = Number(dashMain.querySelector('#raWeight').value) || '';
    if (h) data().height = h;
    if (w) data().weight = w;
    dash.metrics.push({ week: dash.week, height: h, weight: w });
    if (typeof save === 'function') save();

    // 2) recompute the capability profile from the new numbers + snapshot it
    let deltaMsg = 'Your plan was rebuilt around your latest numbers.';
    let leveledUp = null;
    if (typeof assessBaseline === 'function') {
      const ba = assessBaseline(data());
      if (ba) {
        dash.capabilityHistory = dash.capabilityHistory || [];
        const baseSnap = dash.capabilityHistory[0];
        dash.capabilityHistory.push({ week: dash.week, date: todayStr(), capability: ba.capability, percentiles: ba.percentiles });
        if (baseSnap) deltaMsg = describeCapDelta(baseSnap.capability, ba.capability);
        if (dash.profile) { dash.profile.capability = ba.capability; dash.profile.percentiles = ba.percentiles; dash.profile.priorities = ba.priorities; }

        // 2b) CLOSE THE LOOP: when measured capability crosses a band, EARN a
        // higher training level → the regenerated plan selects harder drills and
        // shows the next-tier benchmarks. Promotion is earned (never demoted).
        const caps = Object.values(ba.capability || {}).filter(v => typeof v === 'number');
        if (caps.length >= 2) {
          const overall = Math.round(caps.reduce((s, v) => s + v, 0) / caps.length);
          const order = ['beginner', 'intermediate', 'advanced'];
          const earned = overall >= 75 ? 'advanced' : overall >= 55 ? 'intermediate' : 'beginner';
          const cur = String(data().skillLevel || 'beginner').toLowerCase();
          if (order.indexOf(earned) > order.indexOf(cur)) {
            data().skillLevel = earned.charAt(0).toUpperCase() + earned.slice(1);
            if (typeof save === 'function') save();
            leveledUp = data().skillLevel;
          }
        }
      }
    }

    // 3) regenerate the plan from the updated (re-profiled) athlete
    if (dash.mode === 'drills' && typeof drillCtx === 'function') {
      const ctx = drillCtx();
      if (ctx.plan) { dash.plan = ctx.plan; dash.checks = {}; dash.perf = {}; if (ctx.profile) dash.profile = ctx.profile; }
    } else {
      dash.tasks = weekTasks(dash.week, buildCtx());
    }
    dash.sig = planSig();

    addXp(leveledUp ? 80 : 40);
    queueCelebrate(leveledUp
      ? { icon: '', title: 'Level up → ' + leveledUp + '!', body: 'Your measured re-test earned a harder plan — ' + leveledUp + '-level drills and tougher benchmarks. ' + deltaMsg }
      : { icon: '', title: 'Re-tested & rebuilt', body: deltaMsg });
    renderDashboard();
  });
}

// Plain-language summary of capability change between two snapshots.
function describeCapDelta(base, latest) {
  const caps = Object.keys(latest).filter(c => base[c] != null);
  if (!caps.length) return 'New baseline recorded — your plan was rebuilt to match.';
  const deltas = caps.map(c => ({ c, d: latest[c] - base[c] })).sort((a, b) => b.d - a.d);
  const up = deltas[0], down = deltas[deltas.length - 1];
  let msg = '';
  if (up && up.d > 0) msg += `Biggest gain: ${up.c} +${up.d} percentile. `;
  if (down && down.d < 0) msg += `Watch: ${down.c} ${down.d}. `;
  return (msg || 'Steady across the board. ') + 'Plan rebuilt around your new weak spots.';
}

// Capability timeline (baseline → latest) for the reassessment tab.
function capHistoryHtml() {
  const hist = dash.capabilityHistory || [];
  if (hist.length < 1) return `<div class="card"><h4>Baseline</h4><p class="muted">No baseline test on file. Add your numbers above to start tracking real progress.</p></div>`;
  const base = hist[0].capability, latest = hist[hist.length - 1].capability;
  const caps = Object.keys(latest);
  const rows = caps.map(c => {
    const b = base[c] != null ? base[c] : latest[c];
    const l = latest[c];
    const d = l - b;
    const arrow = d > 0 ? `<span class="cap__up">▲ +${d}</span>` : d < 0 ? `<span class="cap__down">▼ ${d}</span>` : `<span class="cap__same">—</span>`;
    return `<div class="cap__row"><span class="cap__name">${e(c)}</span>
      <span class="cap__track"><i style="width:${l}%"></i><u style="left:${b}%"></u></span>
      <span class="cap__pct">${l}<small>pct</small></span>${hist.length > 1 ? arrow : ''}</div>`;
  }).join('');
  return `<div class="card cap-card"><h4>Capability profile ${hist.length > 1 ? '<span class="muted">(baseline marker vs latest)</span>' : '<span class="muted">(baseline)</span>'}</h4>${rows}</div>`;
}

// Acute:chronic workload ratio from logged session-RPE loads (youth overuse guard).
function acwr() {
  const loads = (dash.checkins || []).filter(c => typeof c.load === 'number');
  if (loads.length < 5) return null;
  const avg = a => a.reduce((s, c) => s + c.load, 0) / a.length;
  const acute = avg(loads.slice(-7));
  const chronic = avg(loads.slice(-28));
  if (!chronic) return null;
  return { ratio: acute / chronic, acute: Math.round(acute), chronic: Math.round(chronic) };
}
function loadGuardHtml() {
  const a = acwr();
  if (!a) return `<div class="card"><h4>Training load</h4><p class="muted">Log a few more daily check-ins (with effort) to track your acute:chronic workload — the standard guard against ramping up too fast.</p></div>`;
  const r = a.ratio;
  const zone = r > 1.5 ? 'high' : r > 1.3 ? 'warn' : r < 0.8 ? 'low' : 'ok';
  const msg = zone === 'high' ? 'Load is spiking — add a recovery day and watch for soreness.'
    : zone === 'warn' ? 'Ramping fast — okay short-term, but hold here rather than pushing higher this week.'
    : zone === 'low' ? 'Load has dropped — you can safely add a little this week.'
    : 'Load is in the safe build zone. Keep going.';
  return `<div class="card load-card load-card--${zone}"><h4>Training load <span class="muted">acute : chronic</span></h4>
    <div class="load__ratio">${r.toFixed(2)}<small>ratio</small></div>
    <div class="load__bar"><i style="width:${Math.min(100, r / 2 * 100)}%"></i><u style="left:40%"></u><u style="left:65%"></u></div>
    <p class="load__msg">${e(msg)}</p></div>`;
}

// Deterministic plain-language coach summary — grounded entirely in the engine's
// own data (derived weaknesses, capability deltas, adaptation, load) so it can
// never invent a drill. (An LLM can later rewrite this text; the facts stay fixed.)
function coachSummary() {
  const prof = dash.profile || {};
  const bits = [];
  const name = (dash.athleteName || '').trim().split(' ')[0];
  // priorities being targeted
  const pr = (prof.priorities || []).map(p => p.title);
  if (pr.length) bits.push(`This block is built around ${listOf(pr)} — the lowest areas from ${name ? name + "'s" : 'the'} baseline test.`);
  else if ((prof.weaknesses || []).length) bits.push(`This block targets ${listOf(prof.weaknesses.slice(0, 3))}.`);
  // capability change
  const hist = dash.capabilityHistory || [];
  if (hist.length > 1) {
    const base = hist[0].capability, latest = hist[hist.length - 1].capability;
    const caps = Object.keys(latest).filter(c => base[c] != null);
    const up = caps.map(c => ({ c, d: latest[c] - base[c] })).sort((a, b) => b.d - a.d)[0];
    if (up && up.d > 0) bits.push(`Since the baseline, ${up.c} is up ${up.d} percentile — the plan is working.`);
  }
  // adaptation last week
  if (dash.review && dash.review.report && dash.review.report.intensity) {
    bits.push(`Last week's completion set intensity to ${String(dash.review.report.intensity).toLowerCase()} for this week.`);
  } else if (dash.adapt) bits.push(dash.adapt);
  // load guard
  const a = acwr();
  if (a && a.ratio > 1.3) bits.push('Training load is climbing quickly — keep recovery honest this week.');
  return bits.join(' ');
}
function listOf(arr) {
  arr = (arr || []).filter(Boolean);
  if (!arr.length) return 'your goals';
  if (arr.length === 1) return arr[0];
  if (arr.length === 2) return arr[0] + ' and ' + arr[1];
  return arr.slice(0, -1).join(', ') + ', and ' + arr[arr.length - 1];
}

/* ---- Parent accountability ---- */
function tabParent() {
  const lvl = computeLevel(dash.xp);
  const earned = BADGES.filter(b => dash.badges[b.id]);
  const lastCi = dash.checkins.slice(-1)[0];
  dashMain.innerHTML = `
    <div class="dash-head"><div><span class="dash-eyebrow">For parents</span><h2>Accountability report</h2></div></div>
    <p class="dash-sub">A weekly snapshot to help you encourage and support your athlete.</p>

    <div class="stat-row">
      ${stat(weekPct() + '%', 'This week')}
      ${stat(monthlyConsistency() + '%', 'Monthly consistency')}
      ${stat(dash.streak, 'Current streak')}
      ${stat('Lv ' + lvl, 'Athlete level')}
    </div>

    <div class="card">
      <h4>Progress summary</h4>
      <ul class="plan-list">
        <li>Completed ${dash.workoutsCompleted} workouts across ${dash.week > dash.maxWeeks ? dash.maxWeeks : dash.week} week(s).</li>
        <li>Goal progress (self-reported) is averaging ${goalCompletion()}%.</li>
        <li>${dash.weeksPerfect} perfect week(s) so far.</li>
        ${lastCi ? `<li>Most recent check-in: ${e(lastCi.did)}, energy ${lastCi.energy}/5, motivation ${lastCi.motivation}/5.</li>` : ''}
      </ul>
    </div>

    <div class="card">
      <h4>Milestones reached</h4>
      <div class="badges">${earned.length ? earned.map(b => `<div class="badge earned"><span>${b.icon}</span><b>${e(b.label)}</b></div>`).join('') : '<p class="muted">No milestones yet — encourage that first workout!</p>'}</div>
    </div>

    <div class="card">
      <h4>How to help this week</h4>
      <ul class="plan-list">
        <li>Ask about today's session and celebrate showing up, not just outcomes.</li>
        <li>Protect sleep and recovery days — they drive the gains.</li>
        <li>${weekPct() < 60 ? 'Completion dipped — a little encouragement goes a long way right now.' : 'Great consistency — acknowledge the effort out loud.'}</li>
      </ul>
    </div>

    <button type="button" class="btn btn--ghost" id="emailReport">Email this report to a parent</button>
    <button type="button" class="linkbtn" id="dashReset">Reset dashboard &amp; start over</button>`;

  dashMain.querySelector('#emailReport').addEventListener('click', () => {
    const to = (prompt('Send this week\'s report to which email address?', dash.parentEmail || '') || '').trim();
    if (!to) return;
    dash.parentEmail = to; saveDash();
    const nl = '%0D%0A';
    const body = [
      'Sporve — Weekly Athlete Report', '',
      'This week completion: ' + weekPct() + '%',
      'Monthly consistency: ' + monthlyConsistency() + '%',
      'Current streak: ' + dash.streak + ' day(s)',
      'Athlete level: ' + lvl,
      'Workouts completed: ' + dash.workoutsCompleted,
      'Goal progress (self-reported): ' + goalCompletion() + '%'
    ].join(nl);
    window.location.href = `mailto:${encodeURIComponent(to)}?subject=${encodeURIComponent('Weekly Athlete Report — Sporve')}&body=${body}`;
  });
  dashMain.querySelector('#dashReset').addEventListener('click', () => {
    if (confirm('Reset all dashboard progress and start a new assessment?')) {
      try { localStorage.removeItem(DASH_KEY); } catch (e2) {}
      dash = null;
      resetAll();
    }
  });
}

/* =========================================================
   Printable report (Download → browser print to PDF)
   ========================================================= */
// One drill, fully expanded for the printable report (no interactive controls).
function reportDrill(item, n, level) {
  const d = item.d;
  const rows = [];
  rows.push(`<p class="report__dmeta">${e(d.skill_category)} · ${e(item.sets)} · ${d.estimated_duration_minutes} min · ${e((typeof DIFF_LABEL !== 'undefined' && DIFF_LABEL[d.difficulty_level]) || d.difficulty_level)}</p>`);
  if (d.how_to) rows.push(`<p><b>How to do it:</b> ${e(d.how_to)}</p>`);
  if (item.reasons && item.reasons.length) rows.push(`<p><b>Why it's in your plan:</b> it ${e(item.reasons.slice(0, 2).join(', and '))}.</p>`);
  if (d.coaching_notes) rows.push(`<p><b>Focus on:</b> ${e(d.coaching_notes)}</p>`);
  if (d.statistic) rows.push(`<p><b>Why it works:</b> ${e(d.statistic)}</p>`);
  const bmVal = d.benchmarks && d.benchmarks[level];
  if (bmVal) rows.push(`<p><b>Your goal (${e(cap(level))}):</b> ${e(bmVal)}</p>`);
  if (d.mistakes && d.mistakes.length) rows.push(`<p><b>Common mistakes:</b> ${e(d.mistakes.join(' · '))}</p>`);
  if (d.safety) rows.push(`<p><b>Safety:</b> ${e(d.safety)}</p>`);
  if (d.progression_option) rows.push(`<p><b>Progress to:</b> ${e(d.progression_option)}</p>`);
  else if (d.regression_option) rows.push(`<p><b>Easier option:</b> ${e(d.regression_option)}</p>`);
  return `<div class="report__drill"><h3>${n}. ${e(d.drill_name)}</h3>${rows.join('')}</div>`;
}

// One training day, fully expanded for the report.
function reportDay(s, level) {
  return `
    <div class="report__day">
      <h2>${e(s.dayName)} · Day ${s.day} — ${e(s.focus)} <span class="report__daytime">~${s.total} min</span></h2>
      ${s.warmup ? `<p><b>Warmup:</b> ${e(s.warmup)}</p>` : ''}
      ${s.drills.map((x, i) => reportDrill(x, i + 1, level)).join('')}
      ${s.cooldown ? `<p><b>Cooldown:</b> ${e(s.cooldown)}</p>` : ''}
      <p class="report__bench"><b>Progress benchmark:</b> ${e(s.benchmark)}</p>
    </div>`;
}

// Shared context for both PDFs. Prefers the plan powering the live tracker so a
// downloaded document can never drift from the dashboard.
function reportCtx() {
  let ctx = buildCtx();
  if (dash && dash.mode === 'drills' && dash.plan && dash.sig === planSig()) {
    ctx = { ...ctx, plan: dash.plan };
  }
  return ctx;
}

/* ---- professional report helpers ---- */
const RPT_ICON = { Basketball: '', Soccer: '', Football: '', Baseball: '', Golf: '', Volleyball: '' };
function sportIcon(label) { return RPT_ICON[label] || ''; }
let _rptPage = 0;
function rptPage(title, inner, opts = {}) {
  _rptPage += 1;
  return `
    <section class="rpt__page${opts.cover ? ' rpt__page--cover' : ''}">
      ${opts.cover ? '' : `<header class="rpt__top"><span class="rpt__brand">Sporve</span>${title ? `<span class="rpt__ptitle">${e(title)}</span>` : ''}</header>`}
      <div class="rpt__body">${inner}</div>
      <footer class="rpt__foot"><span>Sporve · Personalized Sports Training Report</span><span>Page ${_rptPage}</span></footer>
    </section>`;
}
function skillBar(label, pct, kind) {
  return `<div class="rpt__bar"><span class="rpt__barlabel">${e(label)}</span><span class="rpt__bartrack"><i class="rpt__barfill rpt__barfill--${kind || 'blue'}" style="width:${cl(pct, 4, 100)}%"></i></span></div>`;
}
// Drills attributed to one sport from the unified plan (single sport → all days).
function drillsForSportLabel(plan, label, multi) {
  const out = []; const seen = new Set();
  (plan.week || []).forEach(s => {
    const owns = multi ? (s.sportLabel === label) : !s.crossover && !s.recovery;
    if (!owns) return;
    s.drills.forEach(x => { if (!seen.has(x.d.id)) { seen.add(x.d.id); out.push(x); } });
  });
  return out;
}
function crossoverDrillsFrom(plan) {
  const out = []; const seen = new Set();
  (plan.week || []).forEach(s => { if (s.crossover || s.recovery) s.drills.forEach(x => { if (!seen.has(x.d.id)) { seen.add(x.d.id); out.push(x); } }); });
  return out;
}
function emphasisBars(items) {
  const counts = {}; items.forEach(x => { const c = x.d.skill_category; counts[c] = (counts[c] || 0) + 1; });
  const max = Math.max(1, ...Object.values(counts));
  return Object.keys(counts).sort((a, b) => counts[b] - counts[a]).slice(0, 5)
    .map(c => skillBar(c, Math.round(counts[c] / max * 100), 'blue')).join('');
}
// One sport's breakdown page (strengths / weaknesses / goals / position / drills).
function sportBreakdownPage(ctx, key, label, n) {
  const sub = (ctx.perSport && ctx.perSport[key]) || {};
  const lvl = cap(sub.level || ctx.level || 'beginner');
  const pos = (typeof posLabelFor === 'function') ? posLabelFor(key, sub.position) : (sub.position || 'Not sure');
  const items = drillsForSportLabel(ctx.plan, label, ctx.multiSport);
  const strengths = (sub.strengths && sub.strengths.length) ? sub.strengths : [];
  const weaknesses = (sub.weaknesses && sub.weaknesses.length) ? sub.weaknesses : [];
  const goal = sub.mainGoal || 'Overall development';
  const drillCards = items.slice(0, 6).map(x => `<li><b>${e(x.d.drill_name)}</b> <span class="rpt__muted">· ${e(x.d.skill_category)} · ${e(x.sets)}</span></li>`).join('') || '<li>Balanced skill work across the week.</li>';
  const inner = `
    <h1 class="rpt__h1">${sportIcon(label)} ${e(label)} ${n ? `<span class="rpt__tag">${n === 1 ? 'Primary sport' : 'Secondary sport'}</span>` : ''}</h1>
    <p class="rpt__sub">${e(lvl)} · Position: <b>${e(pos)}</b> · Goal: <b>${e(goal)}</b></p>
    <div class="rpt__cols">
      <div class="rpt__card rpt__card--good"><h3>Strengths</h3>${strengths.length ? `<ul>${strengths.map(s => `<li>${e(s)}</li>`).join('')}</ul>` : '<p class="rpt__muted">Add strengths in your profile to highlight them here.</p>'}</div>
      <div class="rpt__card rpt__card--warn"><h3>Weaknesses to target</h3>${weaknesses.length ? `<ul>${weaknesses.map(s => `<li>${e(s)}</li>`).join('')}</ul>` : '<p class="rpt__muted">No specific weaknesses flagged.</p>'}</div>
    </div>
    <h3>Position-specific focus</h3>
    <p>As a <b>${e(pos)}</b>, training emphasizes the skills and movements that role demands most.</p>
    <h3>Training emphasis this block</h3>
    <div class="rpt__bars">${emphasisBars(items) || skillBar('Skill development', 70, 'blue')}</div>
    <h3>Recommended ${e(label)} drills</h3>
    <ul class="rpt__drilllist">${drillCards}</ul>
    <h3>Key improvement areas</h3>
    <p>${weaknesses.length ? `Prioritize ${weaknesses.slice(0, 3).map(w => w.toLowerCase()).join(', ')} while maintaining your strengths.` : `Keep progressing toward your goal of ${goal.toLowerCase()}.`}</p>`;
  return rptPage(e(label) + ' breakdown', inner);
}
function aiSummaryText(ctx) {
  const d = data();
  const who = (d.name || 'This athlete').trim() || 'This athlete';
  const lvl = cap(ctx.level || 'beginner');
  if (ctx.multiSport && ctx.sports && ctx.sports.length >= 2) {
    return `${who} is a two-sport athlete training for <b>${e(ctx.sports[0])}</b> and <b>${e(ctx.sports[1])}</b> at a ${e(lvl)} level. Rather than stacking two separate programs, this plan builds <b>one balanced week</b>: dedicated skill days for each sport, a shared <b>crossover athletic day</b> (jumping, lateral quickness, reaction, core, mobility) that improves both sports at once, and recovery to prevent overtraining. We prioritized each sport's stated weaknesses and position needs while keeping total training time realistic for ${ctx.sessions} days per week.`;
  }
  return `${who} is training for <b>${e(ctx.focus)}</b> at a ${e(lvl)} level, ${ctx.sessions} days per week. The plan leads with your main goal and flagged weaknesses, matches every drill from the library to your position and equipment, and progresses week to week based on what you complete.`;
}

function renderReport() {
  const report = document.getElementById('report');
  report.dataset.doc = 'full';
  _rptPage = 0;
  const ctx = reportCtx();
  const d = data();
  const level = (ctx.profile && ctx.profile.level) || String(ctx.level || 'beginner').toLowerCase();
  const hasPlan = !!(ctx.plan && ctx.plan.week && ctx.plan.week.length);
  const athlete = (d.name || '').trim() || 'Your Athlete';
  const sportKeys = (ctx.sportKeys && ctx.sportKeys.length) ? ctx.sportKeys : [];
  const sportLabels = (ctx.sports && ctx.sports.length) ? ctx.sports : (ctx.focus ? [ctx.focus] : []);

  // ----- Cover -----
  const cover = rptPage('', `
    <div class="rpt__cover">
      <div class="rpt__coverbrand">Sporve</div>
      <div class="rpt__covericons">${(sportLabels.length ? sportLabels : ['']).map(s => `<span>${sportIcon(s)}</span>`).join('')}</div>
      <h1 class="rpt__covertitle">Personalized AI Sports<br/>Training Report</h1>
      <div class="rpt__coverathlete">${e(athlete)}</div>
      <div class="rpt__coversports">${sportLabels.map((s, i) => `<span class="rpt__chip">${sportIcon(s)} ${e(s)}${ctx.multiSport ? ` · ${i === 0 ? 'Primary' : 'Secondary'}` : ''}</span>`).join('')}</div>
      <div class="rpt__coverdate">Created ${e(todayStr())}</div>
    </div>`, { cover: true });

  // ----- Athlete profile -----
  const profileRows = [
    ['Athlete', athlete], ['Age', d.age || '—'], ['Height', d.height ? d.height + '"' : '—'], ['Weight', d.weight ? d.weight + ' lbs' : '—'],
    ['Skill level', cap(level)], ['Training', (ctx.sessions || 3) + ' days/week'], ['Equipment', (d.equipment && d.equipment.length) ? d.equipment.join(', ') : 'Bodyweight / minimal'],
    ['Injury history', d.injuryHistory || 'None'], ['Plan length', ctx.duration || '12 weeks']
  ];
  if (ctx.multiSport) {
    profileRows.push(['Primary sport', `${sportIcon(sportLabels[0])} ${sportLabels[0]} — ${posLabelFor(sportKeys[0], (ctx.perSport[sportKeys[0]] || {}).position)}`]);
    profileRows.push(['Secondary sport', `${sportIcon(sportLabels[1])} ${sportLabels[1]} — ${posLabelFor(sportKeys[1], (ctx.perSport[sportKeys[1]] || {}).position)}`]);
  } else {
    profileRows.push(['Sport', `${sportIcon(sportLabels[0])} ${sportLabels[0] || ctx.focus}`]);
    if (sportKeys[0]) profileRows.push(['Position', posLabelFor(sportKeys[0], (ctx.perSport[sportKeys[0]] || {}).position)]);
  }
  const profilePage = rptPage('Athlete profile', `
    <h1 class="rpt__h1">Athlete profile</h1>
    <table class="rpt__table">${profileRows.map(r => `<tr><th>${e(r[0])}</th><td>${e(String(r[1]))}</td></tr>`).join('')}</table>
    <h3>Main goals</h3>
    <ul>${(ctx.goals || []).map(g => `<li>${e(g)}</li>`).join('') || '<li>Overall athletic development</li>'}</ul>`);

  // ----- AI coaching summary -----
  const summaryPage = rptPage('AI coaching summary', `
    <h1 class="rpt__h1">AI coaching summary</h1>
    <div class="rpt__quote">${aiSummaryText(ctx)}</div>
    <h3>What we prioritized</h3>
    <ul>
      <li>Your stated goal${ctx.multiSport ? 's for each sport' : ''} and flagged weaknesses lead the plan.</li>
      <li>Every drill is matched to your position, level, space, and equipment.</li>
      <li>${ctx.multiSport ? 'Crossover athletic work develops both sports while keeping training time manageable.' : 'Conditioning and recovery are balanced to avoid overtraining.'}</li>
      <li>The plan adapts each week based on what you complete.</li>
    </ul>`);

  if (!hasPlan) {
    // persona / no-library fallback: cover + profile + summary only
    report.innerHTML = cover + profilePage + summaryPage + rptPage('Next steps', `
      <h1 class="rpt__h1">Next steps</h1>
      <p>Pick a sport with a full drill library (Basketball, Soccer, Football, Baseball/Softball, Golf, Volleyball) to unlock the complete week-by-week plan, drill library, and progress tracking.</p>`);
    return;
  }

  // ----- Per-sport breakdown pages -----
  const breakdowns = ctx.multiSport
    ? sportKeys.slice(0, 2).map((k, i) => sportBreakdownPage(ctx, k, sportLabels[i], i + 1)).join('')
    : sportBreakdownPage(ctx, sportKeys[0], sportLabels[0] || ctx.focus, 0);

  // ----- Combined athletic development -----
  const cross = crossoverDrillsFrom(ctx.plan);
  const combinedPage = ctx.multiSport ? rptPage('Combined athletic development', `
    <h1 class="rpt__h1">Combined athletic development</h1>
    <p class="rpt__sub">Skills that build <b>both</b> ${e(sportLabels.join(' & '))} — trained once, paid off twice.</p>
    <div class="rpt__cols">
      <div class="rpt__card"><h3>Shared athletic qualities</h3><ul>
        <li>Vertical jump &amp; explosive power</li><li>Lateral quickness &amp; agility</li><li>Reaction time</li>
        <li>Core strength &amp; landing mechanics</li><li>Shoulder &amp; hip mobility</li><li>Conditioning &amp; endurance</li></ul></div>
      <div class="rpt__card"><h3>Crossover drills in your plan</h3><ul>${(cross.length ? cross.slice(0, 6) : []).map(x => `<li><b>${e(x.d.drill_name)}</b> <span class="rpt__muted">· ${e(x.d.skill_category)}</span></li>`).join('') || '<li>Athletic development integrated into each session.</li>'}</ul></div>
    </div>
    <div class="rpt__note">Because both sports reward jumping, lateral quickness, and reaction speed, these crossover drills improve both at once — keeping your total training time realistic.</div>` ) : '';

  // ----- Weekly training calendar -----
  const calPage = rptPage('Weekly training plan', `
    <h1 class="rpt__h1">Weekly training plan</h1>
    <table class="rpt__cal">
      <thead><tr><th>Day</th><th>Focus</th><th>Drills</th><th>Time</th></tr></thead>
      <tbody>${ctx.plan.week.map(s => `<tr><td><b>${e(s.dayName)}</b></td><td>${s.sportLabel ? `<span class="rpt__pill">${e(s.sportLabel)}</span> ` : ''}${e(s.focus)}</td><td>${s.drills.length}</td><td>~${s.total}m</td></tr>`).join('')}</tbody>
    </table>`);

  // ----- Drill library cards -----
  const allDrills = []; const seen = new Set();
  ctx.plan.week.forEach(s => s.drills.forEach(x => { if (!seen.has(x.d.id)) { seen.add(x.d.id); allDrills.push({ x, sportLabel: s.sportLabel }); } }));
  const drillCards = allDrills.map(({ x, sportLabel }) => {
    const dd = x.d;
    return `
      <div class="rpt__drill">
        <div class="rpt__drillhd"><b>${e(dd.drill_name)}</b><span class="rpt__pill">${e(sportLabel || sportLabels[0] || ctx.focus)}</span></div>
        <div class="rpt__drillmeta">${e(dd.skill_category)} · ${e(x.sets)} · ${dd.estimated_duration_minutes} min · ${e((DIFF_LABEL && DIFF_LABEL[dd.difficulty_level]) || dd.difficulty_level)}</div>
        ${dd.coaching_notes ? `<p><b>Cue:</b> ${e(dd.coaching_notes)}</p>` : ''}
        ${(dd.mistakes && dd.mistakes.length) ? `<p class="rpt__muted"><b>Avoid:</b> ${e(dd.mistakes.slice(0, 3).join(' · '))}</p>` : ''}
        ${dd.progression_option ? `<p class="rpt__muted"><b>Progress to:</b> ${e(dd.progression_option)}</p>` : ''}
      </div>`;
  }).join('');
  const libPage = rptPage('Drill library', `<h1 class="rpt__h1">Drill library</h1><div class="rpt__drillgrid">${drillCards}</div>`);

  // ----- Progress tracking -----
  const tracking = (typeof dash !== 'undefined' && dash && dash.mode === 'drills' && dash.plan)
    ? `<div class="rpt__stats">
         ${[[weekPct() + '%', 'Weekly completion'], [dash.streak + 'd', 'Current streak'], [weekScore(), 'Weekly score'], [goalCompletion() + '%', 'Goal progress']].map(s => `<div class="rpt__stat"><b>${e(String(s[0]))}</b><span>${e(s[1])}</span></div>`).join('')}
       </div>
       <p class="rpt__muted">Completed ${dash.workoutsCompleted || 0} workouts · best streak ${dash.bestStreak || 0} days.</p>`
    : `<p class="rpt__muted">Start tracking this plan in the app to fill in your completion %, streaks, weekly score, and goal progress — they update automatically as you check off drills.</p>`;
  const progPage = rptPage('Progress tracking', `<h1 class="rpt__h1">Progress tracking</h1>${tracking}`);

  // ----- Next steps -----
  const nextPage = rptPage('Next steps', `
    <h1 class="rpt__h1">⏭Next steps</h1>
    <ul>
      <li><b>This week:</b> complete each day's checklist in the app — consistency matters more than perfection.</li>
      <li><b>If you complete most drills:</b> next week's plan steps up — harder variations, an extra set, shorter rest.</li>
      <li><b>If you miss drills:</b> the plan adapts — it repeats the missed work in shorter, easier sessions so you catch up.</li>
      ${ctx.multiSport ? '<li><b>Two sports:</b> keep the crossover day — it’s the most efficient way to improve both at once.</li>' : ''}
    </ul>
    <div class="rpt__motivate">${e((d.name || 'Athlete').trim())}, champions are built one session at a time. Show up, track it, and let the plan grow with you.</div>
    <p class="rpt__foot2">Generated by Sporve · for guidance only, not medical advice.</p>`);

  report.innerHTML = cover + profilePage + summaryPage + breakdowns + combinedPage + calPage + libPage + progPage + nextPage;
}

// ---- Training Plan PDF: practical, workout-focused (checkboxes, sets/reps) ----
function trainingDrillRow(item, n, level) {
  const d = item.d;
  const equip = (d.equipment_needed && d.equipment_needed.length) ? d.equipment_needed.join(', ')
    : (d.equipment && d.equipment.length ? d.equipment.join(', ') : '');
  const bmVal = d.benchmarks && d.benchmarks[level];
  const bits = [];
  bits.push(`<span class="tp__sets">${e(item.sets)} · ${d.estimated_duration_minutes} min</span>`);
  return `
    <div class="tp__drill">
      <span class="tp__check"></span>
      <div class="tp__drillbody">
        <div class="tp__drillhd"><b>${n}. ${e(d.drill_name)}</b> ${bits.join('')}</div>
        ${d.how_to ? `<p>${e(d.how_to)}</p>` : ''}
        ${item.reasons && item.reasons.length ? `<p class="tp__why"><b>Why:</b> it ${e(item.reasons.slice(0, 2).join(', and '))}.</p>` : ''}
        ${equip ? `<p class="tp__eq"><b>Equipment:</b> ${e(equip)}</p>` : ''}
        ${bmVal ? `<p class="tp__bm"><b>Goal:</b> ${e(bmVal)}</p>` : ''}
        ${d.safety ? `<p class="tp__safe"><b>Safety:</b> ${e(d.safety)}</p>` : ''}
      </div>
    </div>`;
}
function trainingDayCard(s, level) {
  return `
    <div class="tp__day">
      <div class="tp__dayhd"><b>${e(s.dayName)} · Day ${s.day}</b><span>${e(s.focus)} · ~${s.total} min</span></div>
      ${s.warmup ? `<div class="tp__phase"><span class="tp__check"></span> Warmup — ${e(s.warmup)}</div>` : ''}
      ${s.drills.map((x, i) => trainingDrillRow(x, i + 1, level)).join('')}
      ${s.cooldown ? `<div class="tp__phase"><span class="tp__check"></span> Cooldown — ${e(s.cooldown)}</div>` : ''}
      <p class="tp__bench"><b>Weekly benchmark:</b> ${e(s.benchmark)}</p>
    </div>`;
}
function renderTrainingPlanReport() {
  const report = document.getElementById('report');
  report.dataset.doc = 'training';
  const ctx = reportCtx();
  const d = data();
  const level = (ctx.profile && ctx.profile.level) || String(ctx.level || 'beginner').toLowerCase();
  const name = (d.name || '').trim();

  if (!(ctx.plan && ctx.plan.week && ctx.plan.week.length)) {
    // Persona / no-library fallback: a simple weekly schedule.
    const sched = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].slice(0, ctx.sessions)
      .map((day, i) => { const r = ['Skill & technique', 'Strength', 'Speed & conditioning', 'Skill + play', 'Recovery & mobility', 'Competition'][i % 6]; return `<div class="tp__phase"><span class="tp__check"></span> <b>${day}:</b> ${r}</div>`; }).join('');
    report.innerHTML = `
      <div class="report__page">
        <div class="report__brand">Sporve</div>
        <h1>Training Plan</h1>
        <p class="report__meta">${name ? e(name) + ' · ' : ''}${e(ctx.focus || 'Athletic development')} · ${e(cap(level))} · ${ctx.sessions}×/week</p>
        <h2>Weekly schedule</h2>${sched}
        <p class="report__foot">Generated by Sporve · for guidance only, not medical advice.</p>
      </div>`;
    return;
  }

  report.innerHTML = `
    <div class="report__page">
      <div class="report__brand">Sporve</div>
      <h1>Training Plan</h1>
      <p class="report__meta">${name ? e(name) + ' · ' : ''}${e(ctx.focus)} · ${e(cap(level))} · ${ctx.sessions}×/week · ${e(ctx.duration)}</p>
      <p class="tp__lead"><b>Main goal:</b> ${e((ctx.goals && ctx.goals[0]) || 'Overall development')} &nbsp;·&nbsp; <b>Focus:</b> ${e((ctx.plan.focus || []).join(', ') || 'Balanced development')}</p>
      <h2>Weekly workouts <span class="report__sub">— check off each item as you complete it</span></h2>
      ${ctx.plan.week.map(s => trainingDayCard(s, level)).join('')}
      <h2>Safety</h2>
      <ul>
        <li>Warm up fully before every session and cool down after.</li>
        <li>Stop any drill that causes pain; rest when sore or fatigued.</li>
        <li>Keep jumping/throwing volume age-appropriate.</li>
      </ul>
      <p class="report__foot">Generated by Sporve · for guidance only, not medical advice.</p>
    </div>`;
}

// Download a document as PDF: render → branded filename → print → save snapshot.
function downloadReport(docType, thenTrack) {
  const isTraining = docType === 'training';
  if (isTraining) renderTrainingPlanReport(); else renderReport();

  // Persist a snapshot of the document when signed in (best-effort).
  if (window.API && API.isAuthed()) {
    const ctx = reportCtx();
    const planId = dash && dash._planId ? dash._planId : null;
    const athleteId = dash && dash._athleteId ? dash._athleteId : null;
    API.saveReport({
      plan_id: planId, athlete_id: athleteId,
      doc_type: isTraining ? 'training' : 'full',
      title: (isTraining ? 'Training Plan' : 'Athletic Blueprint') + (ctx.focus ? ' — ' + ctx.focus : ''),
      report: ctx
    }).catch(() => {});
  }

  const prevTitle = document.title;
  const aName = (data().name || '').trim();
  document.title = (aName ? aName.replace(/\s+/g, '-') + '-' : '') + (isTraining ? 'Sporve-Training-Plan' : 'Sporve-Athletic-Blueprint');
  let done = false;
  const finish = () => {
    if (done) return;
    done = true;
    document.title = prevTitle;
    window.removeEventListener('afterprint', finish);
    if (thenTrack) startTrackingPlan(thenTrack === 'member' ? 'member' : 'free', true);
  };
  window.addEventListener('afterprint', finish);
  window.print();
  setTimeout(finish, 1500);
}

/* =========================================================
   Results plan-summary + action buttons (above the paywall tiers)
   ========================================================= */
function renderResultsSummary() {
  const host = document.getElementById('planSummary');
  if (!host) return;
  const ctx = buildCtx();
  const d = data();
  const athlete = (d.name || '').trim() || 'Your athlete';
  const sportOrPersona = ctx.path === 'persona' && ctx.persona ? ctx.persona.name : (ctx.focus || 'Athletic development');
  const level = ctx.level ? cap(String(ctx.level)) : 'Beginner';
  const mainGoal = (ctx.goals && ctx.goals[0]) || 'Overall development';
  const focusList = (ctx.plan && ctx.plan.focus && ctx.plan.focus.length) ? ctx.plan.focus.join(', ')
    : (ctx.goals || []).join(', ') || 'Balanced development';
  const signedIn = window.API && API.isAuthed();
  const userEmail = signedIn ? (API.getUser() || {}).email : '';

  host.innerHTML = `
    <div class="psum">
      <div class="psum__head">
        <div>
          <span class="psum__eyebrow">${e(athlete)}'s plan</span>
          <h2 class="psum__title">${e(planName(ctx))}</h2>
          ${ctx.multiSport ? `<p class="psum__multi">Unified multi-sport plan — ${e((ctx.sports || []).join(' + '))}. One balanced program with crossover drills that build both sports.</p>` : ''}
          <p class="psum__focus"><b>Primary focus:</b> ${e(focusList)}</p>
        </div>
        <div class="psum__session">
          <span class="psum__acct">${signedIn ? 'Signed in' + (userEmail ? ' · ' + e(userEmail) : '') : 'Not signed in'}</span>
          ${signedIn ? '<button type="button" class="linkbtn linkbtn--sm" id="psumLogout">Log out</button>' : ''}
        </div>
      </div>

      <div class="psum__grid">
        ${psumStat('Athlete', e(athlete))}
        ${psumStat(ctx.path === 'persona' ? 'Persona' : 'Sport', e(sportOrPersona))}
        ${psumStat('Skill level', e(level))}
        ${psumStat('Main goal', e(mainGoal))}
        ${psumStat('Duration', e(ctx.duration || '12 weeks'))}
        ${psumStat('Start', e(todayStr()))}
        ${psumStat('Current week', 'Week 1')}
        ${psumStat('Sessions', (ctx.sessions || 3) + '×/week')}
      </div>

      ${ctx.multiSport ? psumSportCards(ctx) : ''}

      <div class="psum__actions">
        <button type="button" class="btn btn--solid psum__cta" id="psStart">▶ Start Tracking This Plan</button>
        <button type="button" class="btn btn--ghost" id="psFullPdf">Download Full Report PDF</button>
        <button type="button" class="btn btn--ghost" id="psTrainPdf">Download Training Plan PDF</button>
        <button type="button" class="btn btn--ghost" id="psSave">Save to Dashboard</button>
        <button type="button" class="btn btn--ghost" id="psRegen">↻ Regenerate Plan</button>
        <button type="button" class="btn btn--ghost" id="psEdit">Edit Athlete Info</button>
        ${signedIn ? '<button type="button" class="btn btn--ghost" id="psLibrary">My saved plans</button>' : ''}
      </div>
    </div>`;

  const on = (id, fn) => { const el = host.querySelector('#' + id); if (el) el.addEventListener('click', fn); };
  on('psStart', () => startTrackingPlan('free', true));
  on('psFullPdf', () => downloadReport('full', false));
  on('psTrainPdf', (e) => {
    const btn = e.currentTarget || e.target;
    if (typeof state !== 'undefined' && state.path === 'persona' && window.downloadReportPdf) return window.downloadReportPdf(btn);
    if (window.downloadPlanPdf) return window.downloadPlanPdf(btn);
    downloadReport('training', false);
  });
  on('psSave', () => startTrackingPlan('free', false).then(ok => { if (ok) toast('Saved to your dashboard.'); }));
  on('psRegen', () => {
    if (ctx.path === 'persona') { if (typeof renderPlan === 'function') renderPlan(); }
    else if (typeof renderDrillPlan === 'function') renderDrillPlan();
    renderResultsSummary();
    toast('Plan regenerated from your latest profile.');
  });
  on('psEdit', () => {
    showScreen('wizard');
    const idx = state.path === 'sport' ? 1 : 0;   // the "about the athlete" step holds name/metrics
    if (typeof showStep === 'function') showStep(idx, 'back');
  });
  on('psLogout', () => { API.logout(); if (window.refreshReturnButton) window.refreshReturnButton(); renderResultsSummary(); });
  on('psLibrary', () => openLibrary());
}
function psumStat(label, value) {
  return `<div class="psum__stat"><span>${e(label)}</span><b>${value}</b></div>`;
}
// Per-sport breakdown cards for the dual-sport results summary.
function psumSportCards(ctx) {
  const keys = ctx.sportKeys || [];
  const labels = ctx.sports || [];
  const icon = l => (typeof RPT_ICON !== 'undefined' && RPT_ICON[l]) || '';
  const cards = keys.slice(0, 2).map((k, i) => {
    const sub = (ctx.perSport && ctx.perSport[k]) || {};
    const pos = (typeof posLabelFor === 'function') ? posLabelFor(k, sub.position) : (sub.position || 'Not sure');
    const weak = (sub.weaknesses && sub.weaknesses.length) ? sub.weaknesses.join(', ') : 'None flagged';
    const str = (sub.strengths && sub.strengths.length) ? sub.strengths.join(', ') : '—';
    return `
      <div class="psport">
        <div class="psport__hd">${icon(labels[i])} <b>${e(labels[i])}</b> <span class="psport__tag">${i === 0 ? 'Primary' : 'Secondary'}</span></div>
        <div class="psport__row"><span>Level</span><b>${e(cap(sub.level || ctx.level || 'beginner'))}</b></div>
        <div class="psport__row"><span>Position</span><b>${e(pos)}</b></div>
        <div class="psport__row"><span>Goal</span><b>${e(sub.mainGoal || 'Overall')}</b></div>
        <div class="psport__row"><span>Strengths</span><b>${e(str)}</b></div>
        <div class="psport__row psport__row--weak"><span>Weaknesses</span><b>${e(weak)}</b></div>
      </div>`;
  }).join('');
  return `<div class="psum__sports"><div class="psum__sportstitle">Per-sport breakdown</div><div class="psport__grid">${cards}</div></div>`;
}

// Lightweight toast (auto-dismiss) for non-blocking confirmations.
function toast(msg) {
  let t = document.getElementById('trfToast');
  if (!t) { t = document.createElement('div'); t.id = 'trfToast'; t.className = 'toast'; document.body.appendChild(t); }
  t.textContent = msg;
  t.classList.add('show');
  clearTimeout(t._timer);
  t._timer = setTimeout(() => t.classList.remove('show'), 2600);
}

/* =========================================================
   Saved plans & reports library (modal)
   ========================================================= */
async function openLibrary() {
  if (!(window.API && API.isAuthed())) { window.Auth.requireAuth(() => openLibrary()); return; }
  modalBody.innerHTML = `<div class="lib"><h3>Your saved plans</h3><div class="dash-state"><div class="dash-state__spin"></div><p>Loading…</p></div></div>`;
  openModalA11y();
  let plans = [];
  try { plans = await API.listPlans(); } catch (e2) {
    modalBody.innerHTML = `<div class="lib"><h3>Your saved plans</h3><p class="muted">Couldn't load your plans. Try again.</p></div>`;
    return;
  }
  if (!plans.length) {
    modalBody.innerHTML = `<div class="lib"><h3>Your saved plans</h3><p class="muted">No saved plans yet. Generate a plan and tap “Start Tracking”.</p></div>`;
    return;
  }
  const rows = plans.map(p => `
    <div class="lib__row">
      <div class="lib__info">
        <b>${e(p.name || (p.focus || 'Training') + ' plan')}</b>
        <span class="lib__meta">${e(p.focus || '')} · ${e(cap(p.level || ''))} · ${p.status === 'active' ? '<i class="lib__active">Active</i>' : 'Past'} · ${e((p.created_at || '').slice(0, 10))}</span>
      </div>
      <div class="lib__actions">
        <button type="button" class="btn btn--ghost btn--sm" data-open="${p.id}">Open</button>
        ${p.status !== 'active' ? `<button type="button" class="btn btn--solid btn--sm" data-activate="${p.id}">Track</button>` : ''}
        <button type="button" class="linkbtn linkbtn--sm" data-del="${p.id}">delete</button>
      </div>
    </div>`).join('');
  modalBody.innerHTML = `<div class="lib"><h3>Your saved plans</h3><div class="lib__list">${rows}</div></div>`;

  modalBody.querySelectorAll('[data-open]').forEach(b => b.addEventListener('click', () => loadPlanIntoDashboard(b.dataset.open)));
  modalBody.querySelectorAll('[data-activate]').forEach(b => b.addEventListener('click', async () => {
    try { await API.activatePlan(b.dataset.activate); await loadPlanIntoDashboard(b.dataset.activate); } catch (e2) { alert(e2.message || 'Could not activate.'); }
  }));
  modalBody.querySelectorAll('[data-del]').forEach(b => b.addEventListener('click', async () => {
    if (!confirm('Delete this saved plan? This cannot be undone.')) return;
    try { await API.deletePlan(b.dataset.del); openLibrary(); } catch (e2) { alert(e2.message || 'Could not delete.'); }
  }));
}
async function loadPlanIntoDashboard(id) {
  try {
    const sp = await API.getPlan(id);
    hydrateFromServerPlan(sp);
    closeModal();
    setAccent(DASH_ACCENT); showScreen('dash'); activeTab = 'week'; syncTabs(); renderDashboard();
  } catch (e2) { alert(e2.message || 'Could not open that plan.'); }
}
window.openLibrary = openLibrary;

/* =========================================================
   Results-screen wiring
   ========================================================= */
function wireResults() {
  const billToggle = document.getElementById('billToggle');
  const memberPrice = document.getElementById('memberPrice');
  const monthlyHtml = `${fmtMoney(PRICING.monthly)} <span>/mo</span>`;
  const annualHtml = `${fmtMoney(Number(PRICING.annualMonthly))} <span>/mo billed annually</span>`;
  // derive all displayed pricing from the single PRICING config
  const annualSave = document.getElementById('annualSave');
  if (annualSave) annualSave.textContent = `save ${PRICING.savePct}%`;
  if (memberPrice) memberPrice.innerHTML = monthlyHtml;
  if (billToggle) {
    billToggle.querySelectorAll('button').forEach(b => b.addEventListener('click', () => {
      billToggle.querySelectorAll('button').forEach(x => x.classList.remove('active'));
      b.classList.add('active');
      memberPrice.innerHTML = b.dataset.bill === 'annual' ? annualHtml : monthlyHtml;
    }));
  }
  const dl = document.getElementById('downloadBtn');
  if (dl) dl.addEventListener('click', () => downloadReport('full', false));
  const mb = document.getElementById('memberBtn');
  if (mb) mb.addEventListener('click', () => startTrackingPlan('member', true));
  const fb = document.getElementById('freeBtn');
  if (fb) fb.addEventListener('click', () => startTrackingPlan('free', true));
  const so = document.getElementById('resultsStartOver');
  if (so) so.addEventListener('click', () => resetAll());
}

/* =========================================================
   Global wiring
   ========================================================= */
dashTabs.querySelectorAll('button').forEach(b => b.addEventListener('click', () => {
  activeTab = b.dataset.tab; syncTabs(); renderDashboard();
}));
// delegate "go to tab" buttons rendered inside content
dashMain.addEventListener('click', ev => {
  const t = ev.target.closest('[data-goto]');
  if (t) { activeTab = t.dataset.goto; syncTabs(); renderDashboard(); }
});
document.getElementById('modalX').addEventListener('click', closeModal);
modal.addEventListener('click', ev => { if (ev.target === modal) closeModal(); });
document.addEventListener('keydown', ev => { if (ev.key === 'Escape' && !modal.hidden) closeModal(); });
document.getElementById('dashBrand').addEventListener('click', e2 => { e2.preventDefault(); saveDash(); showLanding(); });

wireResults();

// Returning signed-in users get a persistent shortcut back into their dashboard.
// CSS hides it on the wizard/dash screens (keyed off body[data-screen]).
(function mountReturnButton() {
  function ensure() {
    if (!(window.API && API.isAuthed())) { const ex = document.getElementById('returnDash'); if (ex) ex.remove(); return; }
    if (document.getElementById('returnDash')) return;
    const b = document.createElement('button');
    b.id = 'returnDash';
    b.type = 'button';
    b.className = 'btn btn--solid btn--sm';
    b.textContent = 'My Dashboard →';
    b.addEventListener('click', () => enterDashboard());
    document.body.appendChild(b);
  }
  ensure();
  window.refreshReturnButton = ensure;   // call after login/logout
})();
