/* =========================================================
   Sporve plan-PDF — READ-ONLY mapper: app plan/profile/allocation
   → PlanDocument. Computes nothing new, writes nothing back (Part A).
   Handles single- AND multi-sport (Part B). browser + node.
   ========================================================= */
(function (root) {
  const THEMES = (typeof require !== 'undefined') ? require('./themes.js') : root.PlanPdfThemes;
  const SPORT_THEMES = THEMES.SPORT_THEMES, K2T = THEMES.SPORT_KEY_TO_THEME;

  const up = (s) => String(s == null ? '' : s).toUpperCase();
  const trunc = (s, n) => { s = String(s == null ? '' : s); return s.length > n ? s.slice(0, n - 1) + '…' : s; };
  const themeKeyOf = (k) => K2T[k] || (SPORT_THEMES[k] ? k : 'general_athletic');
  function today() {
    try { const d = new Date(); const p = (n) => String(n).padStart(2, '0'); return p(d.getMonth() + 1) + '.' + p(d.getDate()) + '.' + String(d.getFullYear()).slice(2); }
    catch (e) { return ''; }
  }
  const SEASON_LABEL = { in_season: 'IN-SEASON', pre_season: 'PRE-SEASON', off_season: 'OFF-SEASON', maintenance: 'MAINTENANCE' };
  const PHASES = [
    { weeksLabel: 'WK\n01–03', name: 'Foundation', desc: 'Movement quality, technical rebuild, base conditioning.', loadLabel: 'LOW' },
    { weeksLabel: 'WK\n04–07', name: 'Build', desc: 'Skill volume and strength under progressive overload.', loadLabel: 'MOD' },
    { weeksLabel: 'WK\n08–11', name: 'Power', desc: 'Convert base to explosive, game-speed application.', loadLabel: 'HIGH' },
    { weeksLabel: 'WK\n12', name: 'Sharpen', desc: 'Taper: speed stays, volume drops, full recovery.', loadLabel: 'PEAK' },
  ];

  // opts: { labelFn(key)->label, name, weeks, planId, issuedDate }
  function fromPlanJson(plan, p, opts) {
    opts = opts || {};
    plan = plan || {}; p = p || {};
    const labelFn = opts.labelFn || ((k) => up(k));
    const alloc = plan.allocation || null;
    const sportKeys = (p.sports && p.sports.length) ? p.sports.slice(0, 3) : [p.sport].filter(Boolean);
    const anchorKey = (alloc && alloc.anchorSportId) || sportKeys[0] || p.sport || 'general_athletic';
    const anchorTheme = themeKeyOf(anchorKey);
    const weeks = opts.weeks || 12;
    const ageBand = p.age != null ? ('AGE ' + p.age) : 'ALL AGES';

    // ---- Part B: per-sport allocation summary ----
    let sports = [], baseTrack = { theme: [], sessions: 0 }, allocationNote = '';
    if (alloc && alloc.skill && sportKeys.length >= 2) {
      const meta = p.sportMeta || {};
      sports = alloc.skill.map((s, i) => ({
        sportId: themeKeyOf(s.sportId), label: up(labelFn(s.sportId)),
        priority: i + 1, season: SEASON_LABEL[(meta[s.sportId] || {}).season] || 'OFF-SEASON',
        sessions: s.sessions, mode: up(s.mode || 'development'),
      }));
      baseTrack = { theme: (alloc.baseTheme || []).map(q => q.replace(/_/g, ' ')), sessions: alloc.baseSessions || 0 };
      const totalSkill = alloc.skill.reduce((a, s) => a + s.sessions, 0) || 1;
      const split = alloc.skill.map(s => Math.round((s.sessions / totalSkill) * 100) + '% ' + labelFn(s.sportId)).join(' / ');
      allocationNote = 'This block: ' + split + ' · shared base ×' + (alloc.baseSessions || 0) + '/wk';
    } else {
      sports = [{ sportId: anchorTheme, label: up(labelFn(anchorKey)), priority: 1, season: SEASON_LABEL[(p.sportMeta && p.sportMeta[anchorKey] || {}).season] || 'OFF-SEASON', sessions: p.dayCount || 0, mode: 'DEVELOPMENT' }];
    }

    // ---- metrics: percentiles when baseline-tested, else plan facts ----
    let metrics = [];
    if (p.percentiles && typeof p.percentiles === 'object') {
      metrics = Object.keys(p.percentiles).slice(0, 6).map(k => ({ key: k.replace(/_/g, ' '), value: String(Math.round(p.percentiles[k])), unit: '%ILE' }));
    }
    if (metrics.length < 3) {
      metrics = [
        { key: 'Level', value: up(p.level || 'BEGINNER'), unit: 'STAGE' },
        { key: 'Days / week', value: String(p.dayCount || 3), unit: 'SESSIONS' },
        { key: 'Session', value: String(p.minutes || 35), unit: 'MIN' },
        { key: 'Block', value: String(weeks), unit: 'WEEKS' },
        { key: 'Sports', value: String(sportKeys.length), unit: sportKeys.length > 1 ? 'MULTI' : 'FOCUS' },
        { key: 'Drills matched', value: String(plan.eligibleCount || (plan.week ? plan.week.reduce((a, s) => a + (s.drills ? s.drills.length : 0), 0) : 0)), unit: 'IN LIBRARY' },
      ];
    }

    // ---- focus areas from weaknesses ----
    const wk = (p.weaknesses || []).slice(0, 4);
    const focusAreas = wk.length
      ? wk.map((w, i) => ({ label: w, severity: Math.max(2, 5 - i) }))
      : [{ label: 'Overall development', severity: 4 }, { label: 'Consistency', severity: 3 }, { label: 'Conditioning', severity: 3 }, { label: 'Confidence', severity: 2 }];

    // ---- weekly rhythm (multi-sport = the split; single = generic) ----
    let weeklyRhythm;
    if (sportKeys.length >= 2 && alloc) {
      weeklyRhythm = alloc.skill.slice(0, 2).map(s => ({ key: labelFn(s.sportId), count: s.sessions + '×', note: 'SKILL' }));
      weeklyRhythm.push({ key: 'Shared base', count: (alloc.baseSessions || 0) + '×', note: (baseTrack.theme[0] || 'ATHLETIC BASE').toUpperCase() });
    } else {
      weeklyRhythm = [{ key: 'Skill', count: Math.max(1, Math.round((p.dayCount || 3) * 0.6)) + '×', note: 'TECHNICAL' }, { key: 'Strength/Power', count: '1×', note: 'LIFT + PLYO' }, { key: 'Conditioning', count: '1×', note: 'ENERGY SYSTEM' }];
    }

    // ---- full plan grid: per-week focus (multi = split string) ----
    const splitStr = (alloc && sportKeys.length >= 2)
      ? alloc.skill.map(s => s.sessions + ' ' + up(labelFn(s.sportId))).join(' · ') + ' · ' + (alloc.baseSessions || 0) + ' BASE'
      : null;
    const planFocus0 = (plan.focus && plan.focus[0]) || 'Primary development';
    const fullPlan = Array.from({ length: weeks }, (_, i) => ({
      week: String(i + 1).padStart(2, '0'),
      phaseShort: i < 3 ? 'FOUND.' : i < 7 ? 'BUILD' : i < 11 ? 'POWER' : 'SHARPEN',
      focus: splitStr || trunc(planFocus0, 60),
      load: i < 3 ? 'LOW' : i < 7 ? 'MOD' : i < 11 ? 'HIGH' : 'PEAK',
    }));

    // ---- detailed week from the actual plan.week ----
    const sessFor = (s) => {
      const names = (s.drills || []).map(x => x.d && x.d.drill_name).filter(Boolean);
      let set = names.slice(0, 3).join(' · ');
      if (names[0]) set = '<<' + names[0] + '>>' + (names.length > 1 ? ' · ' + names.slice(1, 3).join(' · ') : '');
      return trunc(set, 118);
    };
    const dayTitle = (s) => s.recovery ? 'Recovery' : s.crossover ? 'Shared Base' : (s.sportLabel ? up(s.sportLabel) + ' Skill' : (s.focus || 'Training'));
    const dayTag = (s) => s.recovery ? 'OFF · mobility + film' : ('~' + (s.total || 0) + ' MIN');
    const wkArr = (plan.week || []).slice(0, 7);
    // case-insensitive label→key match so a day's sport chip themes correctly
    // regardless of the labelFn's casing (falls back to the anchor sport).
    const keyForLabel = (lbl) => {
      if (!lbl) return anchorKey;
      const low = String(lbl).toLowerCase();
      const i = (p.sports || []).map(k => String(labelFn(k)).toLowerCase()).indexOf(low);
      return (i >= 0 && p.sports[i]) || anchorKey;
    };
    const days = wkArr.map(s => ({
      day: up(String(s.dayName || '').slice(0, 3)), title: dayTitle(s), tag: dayTag(s), set: s.recovery ? 'Full rest. 20-min mobility + review film.' : sessFor(s),
      sportId: s.crossover || s.recovery ? null : (s.sportLabel ? themeKeyOf(keyForLabel(s.sportLabel)) : anchorTheme),
    }));
    while (days.length < 7) days.push({ day: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][days.length], title: 'Recovery', tag: 'OFF · mobility', set: 'Full rest. Light mobility.' });
    const detailedWeek = { weekNumber: '06', phaseName: 'BUILD', intro: 'A representative week, fully prescribed. Follow as-is or log it in the app to auto-adjust.', days, loadSummary: (wkArr.length || (p.dayCount || 0)) + ' SESSIONS' };

    // ---- drills (top 6) + per-sport skill sections (multi) ----
    const flatDrills = [];
    (plan.week || []).forEach(s => (s.drills || []).forEach(x => { if (x.d) flatDrills.push({ d: x.d, sets: x.sets, sportLabel: s.sportLabel, crossover: s.crossover }); }));
    const seen = {};
    const drillCard = (it) => ({ tag: it.d.skill_category || 'Skill', name: it.d.drill_name, cue: trunc(it.d.coaching_notes || it.d.how_to || '', 90), rx: String(it.sets || '').replace(/ · (eased|lighter \(full rest\)|\+1 set)$/, '') });
    const drills = [];
    flatDrills.forEach(it => { if (drills.length < 6 && !seen[it.d.id]) { seen[it.d.id] = 1; drills.push(drillCard(it)); } });

    let skillSections = null;
    if (sportKeys.length >= 2) {
      skillSections = [];
      sports.forEach(sp => {
        const cards = [], used = {};
        flatDrills.forEach(it => { if (!it.crossover && up(it.sportLabel) === sp.label && cards.length < 4 && !used[it.d.id]) { used[it.d.id] = 1; cards.push(drillCard(it)); } });
        if (cards.length) skillSections.push({ sportId: sp.sportId, label: sp.label, drills: cards });
      });
      const baseCards = []; const usedB = {};
      flatDrills.forEach(it => { if (it.crossover && baseCards.length < 4 && !usedB[it.d.id]) { usedB[it.d.id] = 1; baseCards.push(drillCard(it)); } });
      if (baseCards.length) skillSections.push({ sportId: anchorTheme, label: 'SHARED BASE', drills: baseCards, isBase: true });
    }

    // ---- test/targets ----
    const targets = (p.percentiles ? Object.keys(p.percentiles).slice(0, 4).map(k => ({ metric: k.replace(/_/g, ' '), now: Math.round(p.percentiles[k]) + '%ile', goal: Math.min(95, Math.round(p.percentiles[k]) + 12) + '%ile' })) : []);
    if (!targets.length) (wk.length ? wk : ['Primary skill', 'Consistency']).slice(0, 4).forEach(w => targets.push({ metric: w, now: 'baseline', goal: 'improved' }));

    const goalText = p.mainGoal || 'Reach the next level';
    const lead = sportKeys.length >= 2
      ? ('A ' + weeks + '-week unified plan across ' + sports.map(s => s.label).join(' + ') + ' — one shared athletic base, skill work allocated by priority and season.')
      : ('A ' + weeks + '-week plan built around your game — targeted to your weak points and re-tested at the end.');

    return {
      planId: opts.planId || ('SP-' + String(Math.abs(hash(anchorKey + (opts.name || '') + weeks)) % 9000 + 1000)),
      sportId: anchorTheme, issuedDate: opts.issuedDate || today(), blockLabel: 'BLOCK 01 / ' + String(Math.ceil(weeks / 4)).padStart(2, '0'),
      athlete: { name: up(opts.name || 'Your Athlete'), descriptor: ageBand + ' · ' + up(labelFn(anchorKey)) + ' · ' + up(p.level || 'beginner'), sectionWord: 'The Athlete' },
      coverLead: lead,
      goal: { chipLabel: 'The Target', chipValue: trunc(goalText, 26), statement: 'Close the gap to your goal by fixing ' + (wk[0] ? '<<' + wk[0].toLowerCase() + '>>' : '<<your top weakness>>') + ' and holding form when <<fatigue>> sets in.' },
      blockMeta: { weeks, phasesCount: 4, sessionsPerWeek: p.dayCount || 0, phaseFlow: 'FOUNDATION → BUILD → POWER → SHARPEN' },
      metrics, focusAreas, phases: PHASES, weeklyRhythm, fullPlan, detailedWeek, drills, skillSections,
      sports, baseTrack, allocationNote,
      test: { title: 'Benchmark Test — Week ' + weeks, body: 'Re-run the week-one test under the same conditions. Target <<measurable improvement>> on your focus areas and hold <<form under fatigue>>.', targets },
      closing: { line: sportKeys.length >= 2 ? 'Two sports. <<One engine.>>' : 'Work is done in the <<dark gym.>>' },
    };
  }
  function hash(s) { let h = 0; for (let i = 0; i < s.length; i++) { h = (h << 5) - h + s.charCodeAt(i); h |= 0; } return h; }

  const API = { fromPlanJson };
  if (typeof module !== 'undefined' && module.exports) module.exports = API;
  if (typeof window !== 'undefined') window.PlanPdfMap = API;
})(typeof window !== 'undefined' ? window : globalThis);
