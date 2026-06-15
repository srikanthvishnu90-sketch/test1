/* =========================================================
   Sporve — Multi-Sport Training Allocation Engine
   Adapted from the KINETIK spec (§2 demand profiles, §3 allocation,
   §4 scheduler) to Sporve's vanilla-JS stack. Pure, testable; runs in
   the browser (window.Allocate) and in Node (module.exports).

   Core principle: a multi-sport athlete has ONE finite weekly budget.
   Allocate it by priority + season, build the physical BASE once (it
   transfers), and split only SKILL work per sport. Never sum two plans.
   ========================================================= */
(function (root) {
  'use strict';

  /* ---------- §2  SPORT DEMAND PROFILES ---------- */
  // primaryAxis: what the sport competes for in the shared base.
  // baseQualities: transferable physical qualities the base should emphasize.
  const DEMAND = {
    basketball:        { dominant: 'power/agility',     energy: 'anaerobic', primaryAxis: 'neutral',        baseQualities: ['lower_body_power', 'lateral_agility', 'anaerobic_conditioning', 'core_stability'] },
    soccer:            { dominant: 'repeated-sprint',   energy: 'mixed',     primaryAxis: 'neutral',        baseQualities: ['aerobic_capacity', 'repeated_sprint', 'change_of_direction', 'posterior_chain'] },
    baseball_softball: { dominant: 'rotational power',  energy: 'alactic',   primaryAxis: 'strength_power', baseQualities: ['rotational_power', 'arm_care', 'sprint', 'mobility'] },
    football:          { dominant: 'strength/power',    energy: 'alactic',   primaryAxis: 'strength_power', baseQualities: ['max_strength', 'explosive_power', 'sprint', 'collision_prep'] },
    volleyball:        { dominant: 'jump power',        energy: 'alactic',   primaryAxis: 'strength_power', baseQualities: ['vertical_power', 'shoulder_health', 'agility', 'core_stability'] },
    lacrosse:          { dominant: 'mixed',             energy: 'mixed',     primaryAxis: 'neutral',        baseQualities: ['aerobic_capacity', 'repeated_sprint', 'change_of_direction', 'core_stability'] },
    ice_hockey:        { dominant: 'power/anaerobic',   energy: 'anaerobic', primaryAxis: 'strength_power', baseQualities: ['lower_body_power', 'anaerobic_conditioning', 'core_stability', 'mobility'] },
    rugby:             { dominant: 'strength/power',    energy: 'mixed',     primaryAxis: 'strength_power', baseQualities: ['max_strength', 'explosive_power', 'collision_prep', 'conditioning'] },
    distance_running:  { dominant: 'endurance',         energy: 'aerobic',   primaryAxis: 'endurance',      baseQualities: ['aerobic_capacity', 'running_economy', 'durability', 'mobility'] },
    track_sprints:     { dominant: 'speed/power',       energy: 'alactic',   primaryAxis: 'strength_power', baseQualities: ['max_velocity', 'explosive_strength', 'plyometrics', 'mobility'] },
    cycling:           { dominant: 'endurance',         energy: 'aerobic',   primaryAxis: 'endurance',      baseQualities: ['aerobic_capacity', 'threshold', 'leg_strength', 'durability'] },
    swimming:          { dominant: 'endurance/mixed',   energy: 'mixed',     primaryAxis: 'neutral',        baseQualities: ['aerobic_capacity', 'shoulder_health', 'core_stability', 'power'] },
    rowing:            { dominant: 'endurance/strength', energy: 'mixed',    primaryAxis: 'endurance',      baseQualities: ['aerobic_power', 'max_strength', 'posterior_chain', 'durability'] },
    tennis:            { dominant: 'power/agility',     energy: 'mixed',     primaryAxis: 'neutral',        baseQualities: ['repeated_power', 'change_of_direction', 'shoulder_health', 'aerobic_capacity'] },
    pickleball:        { dominant: 'agility/skill',     energy: 'anaerobic', primaryAxis: 'neutral',        baseQualities: ['agility', 'anaerobic_conditioning', 'mobility', 'core_stability'] },
    badminton:         { dominant: 'speed/agility',     energy: 'anaerobic', primaryAxis: 'neutral',        baseQualities: ['agility', 'repeated_power', 'anaerobic_conditioning', 'mobility'] },
    table_tennis:      { dominant: 'skill/agility',     energy: 'alactic',   primaryAxis: 'neutral',        baseQualities: ['agility', 'reaction', 'mobility', 'core_stability'] },
    strength_training: { dominant: 'strength',          energy: 'alactic',   primaryAxis: 'strength_power', baseQualities: ['max_strength', 'hypertrophy', 'mobility', 'core_stability'] },
    powerlifting:      { dominant: 'max strength',      energy: 'alactic',   primaryAxis: 'strength_power', baseQualities: ['max_strength', 'technique', 'mobility', 'core_stability'] },
    functional_fitness: { dominant: 'mixed',            energy: 'mixed',     primaryAxis: 'neutral',        baseQualities: ['strength', 'conditioning', 'gymnastics', 'mobility'] },
    boxing:            { dominant: 'power/anaerobic',   energy: 'mixed',     primaryAxis: 'neutral',        baseQualities: ['anaerobic_conditioning', 'power', 'aerobic_base', 'core_stability'] },
    wrestling:         { dominant: 'strength/anaerobic', energy: 'anaerobic', primaryAxis: 'strength_power', baseQualities: ['max_strength', 'anaerobic_conditioning', 'grip', 'mobility'] },
    martial_arts:      { dominant: 'mixed',             energy: 'mixed',     primaryAxis: 'neutral',        baseQualities: ['power', 'conditioning', 'mobility', 'core_stability'] },
    golf:              { dominant: 'rotational skill',  energy: 'alactic',   primaryAxis: 'neutral',        baseQualities: ['rotational_power', 'mobility', 'core_stability', 'stability'] },
    gymnastics:        { dominant: 'relative strength', energy: 'alactic',   primaryAxis: 'strength_power', baseQualities: ['relative_strength', 'power', 'mobility', 'core_stability'] },
    rock_climbing:     { dominant: 'strength/endurance', energy: 'mixed',    primaryAxis: 'neutral',        baseQualities: ['relative_strength', 'grip_endurance', 'mobility', 'core_stability'] },
    general_athletic:  { dominant: 'mixed',             energy: 'mixed',     primaryAxis: 'neutral',        baseQualities: ['strength', 'conditioning', 'speed', 'mobility'] },
  };

  /* ---------- §3  ALLOCATION ENGINE ---------- */
  const PRIORITY = { 1: 3, 2: 2, 3: 1 };
  const SEASON_Q = { in_season: 1.3, pre_season: 1.1, off_season: 1.0, maintenance: 0.5 };
  const clamp = (n, lo, hi) => Math.max(lo, Math.min(hi, n));

  function skillMode(s) {
    if (s.season === 'in_season') return (s.weeksToCompetition == null ? 99 : s.weeksToCompetition) <= 3 ? 'sharpen' : 'maintenance';
    if (s.season === 'maintenance') return 'maintenance';
    return 'development'; // off_season / pre_season = build
  }

  // largest-remainder apportionment so sum(out) === K exactly
  function apportion(shares, K) {
    const raw = shares.map(s => s * K);
    const floor = raw.map(Math.floor);
    const rem = K - floor.reduce((a, b) => a + b, 0);
    const order = raw.map((r, i) => ({ i, frac: r - Math.floor(r) })).sort((a, b) => b.frac - a.frac);
    const out = floor.slice();
    for (let j = 0; j < rem; j++) out[order[j % order.length].i]++;
    return out;
  }

  function allocate(intake) {
    const a = intake.availability, sports = intake.sports;
    const D = clamp(a.daysPerWeek, 2, 7);

    // 1) weights = priority × season quality → shares
    const W = sports.map(s => PRIORITY[s.priorityRank] * (SEASON_Q[s.season] != null ? SEASON_Q[s.season] : 1));
    const sumW = W.reduce((x, y) => x + y, 0) || 1;
    const shares = W.map(w => w / sumW);

    // 2) budget split: ~40% shared base, rest skill (ensure each sport can get ≥1)
    const baseSessions = clamp(Math.round(0.4 * D), 1, 3);
    const K = Math.max(D - baseSessions, sports.length);
    const realBase = clamp(D - K, 1, 3);

    // 3) per-sport skill sessions
    const k = apportion(shares, D - realBase);
    for (let i = 0; i < k.length; i++) if (k[i] === 0 && (D - realBase) >= sports.length) k[i] = 1;
    let total = k.reduce((x, y) => x + y, 0);
    while (total > D - realBase) {
      const cand = k.map((v, i) => ({ v, i, p: sports[i].priorityRank }))
        .filter(o => o.v > 1).sort((x, y) => y.p - x.p)[0];
      const idx = cand ? cand.i : 0;
      k[idx]--; total--;
    }

    // 4) anchor: highest-priority in-season sport, else highest priority overall
    const anchorEntry = sports.slice().sort((x, y) => {
      const ix = x.season === 'in_season' ? 0 : 1, iy = y.season === 'in_season' ? 0 : 1;
      return ix - iy || x.priorityRank - y.priorityRank;
    })[0];

    // 5) interference: an endurance-axis sport AND a strength_power-axis sport both present
    const axes = sports.map(s => DEMAND[s.sportId] && DEMAND[s.sportId].primaryAxis);
    const interference = axes.indexOf('endurance') !== -1 && axes.indexOf('strength_power') !== -1;
    const appliedRules = [];

    // 6) base theme — weighted merge of baseQualities, biased to anchor (more under interference)
    const score = {};
    sports.forEach((s, i) => {
      const bias = s.sportId === anchorEntry.sportId ? (interference ? 2 : 1.3) : 1;
      ((DEMAND[s.sportId] && DEMAND[s.sportId].baseQualities) || []).forEach(q => { score[q] = (score[q] || 0) + shares[i] * bias; });
    });
    const baseTheme = Object.keys(score).map(q => [q, score[q]]).sort((x, y) => y[1] - x[1]).slice(0, 4).map(p => p[0]);

    // 7) skill alloc + interference downgrade of the conflicting non-anchor quality
    const skill = sports.map((s, i) => {
      let mode = skillMode(s);
      if (interference && s.sportId !== anchorEntry.sportId &&
        (DEMAND[s.sportId] && DEMAND[s.sportId].primaryAxis) !== (DEMAND[anchorEntry.sportId] && DEMAND[anchorEntry.sportId].primaryAxis)) {
        mode = 'maintenance'; // hold the conflicting secondary; don't develop it concurrently
      }
      return { sportId: s.sportId, sessions: k[i], mode };
    });
    if (interference) appliedRules.push(
      'Separate heavy strength and hard endurance onto different days.',
      'Bias shared base toward the in-season/primary sport (' + anchorEntry.sportId + ').',
      'Hold the conflicting secondary quality at maintenance (no concurrent development).');

    // capacity warning when budget can't give every sport a skill day
    if ((D - realBase) < sports.length) appliedRules.push(
      sports.length + ' sports on ' + D + ' days is maintenance-level — some sports share/forgo a weekly skill block.');

    // 8) youth high-intensity cap (whole week, base + skill combined)
    const highIntensityCap = a.age < 14 ? 2 : a.age < 18 ? 3 : (a.level === 'advanced' ? 4 : 3);

    return {
      anchorSportId: anchorEntry.sportId,
      baseSessions: realBase,
      baseTheme,
      skill,
      restDays: 7 - D,
      interference,
      appliedRules,
      highIntensityCap,
      replanTriggers: ['season_status_change', 'priority_change', 'availability_change', 'competition_within_3_weeks'],
    };
  }

  /* ---------- §4  WEEKLY SCHEDULER ---------- */
  const DAYS = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  const isOpp = (a, b) => (a === 'endurance' && b === 'strength_power') || (a === 'strength_power' && b === 'endurance');

  function pickSpread(n) {                  // choose n of 7 day-indexes, evenly spaced
    if (n >= 7) return [0, 1, 2, 3, 4, 5, 6].slice(0, n);
    const step = 7 / n, out = [];
    for (let i = 0; i < n; i++) out.push(Math.round(i * step));
    return out;
  }
  function separateAxes(arr) {              // greedy: avoid endurance/strength_power back-to-back
    const out = [], pool = arr.slice();
    while (pool.length) {
      const last = out.length ? out[out.length - 1].axis : undefined;
      let pick = pool.findIndex(s => !isOpp(last, s.axis));
      if (pick === -1) pick = 0;
      out.push(pool.splice(pick, 1)[0]);
    }
    return out;
  }

  function scheduleWeek(alloc) {
    // build session list; anchor skill first (gets the freshest post-rest days)
    const sessions = [];
    const anchorFirst = alloc.skill.slice().sort((a, b) => (a.sportId === alloc.anchorSportId ? -1 : 1));
    anchorFirst.forEach(s => { for (let i = 0; i < s.sessions; i++) sessions.push({ type: 'skill', sportId: s.sportId, axis: (DEMAND[s.sportId] && DEMAND[s.sportId].primaryAxis) || 'neutral' }); });
    for (let i = 0; i < alloc.baseSessions; i++) sessions.push({ type: 'base', axis: 'neutral' });

    const idxs = pickSpread(sessions.length);
    const ordered = separateAxes(sessions);

    const week = DAYS.map(d => ({ day: d, type: 'rest', axis: 'neutral', note: 'Recovery — mobility + film.' }));
    ordered.forEach((s, n) => {
      const di = idxs[n];
      week[di] = {
        day: DAYS[di], type: s.type, sportId: s.sportId, axis: s.axis,
        note: s.type === 'base' ? 'Shared athletic base — ' + alloc.baseTheme.slice(0, 2).join(', ') : s.sportId + ' skill block',
      };
    });
    return week;
  }

  const API = { DEMAND, allocate, scheduleWeek, apportion, skillMode, _internal: { pickSpread, separateAxes, isOpp } };
  if (typeof module !== 'undefined' && module.exports) module.exports = API;
  root.Allocate = API;
})(typeof window !== 'undefined' ? window : globalThis);
