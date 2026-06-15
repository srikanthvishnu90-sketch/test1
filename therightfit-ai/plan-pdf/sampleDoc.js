/* =========================================================
   Sporve plan-PDF — generic placeholder PlanDocument (Phase 5).
   Lets every sport render without real plan data. The exact data
   contract lives in the JSDoc below (Phase 1 of the spec).
   ========================================================= */
const { SPORT_THEMES } = (typeof require !== 'undefined') ? require('./themes.js') : window.PlanPdfThemes;

/**
 * @typedef {Object} PlanDocument
 * planId, sportId, issuedDate, blockLabel,
 * athlete:{name,descriptor,sectionWord}, coverLead?,
 * goal:{chipLabel,chipValue,statement}, blockMeta:{weeks,phasesCount,sessionsPerWeek,phaseFlow},
 * metrics:[{key,value,unit}] (<=6), focusAreas:[{label,severity 1..5}] (<=4),
 * phases:[{weeksLabel,name,desc,loadLabel}] (4), weeklyRhythm?:[{key,count,note}] (<=3),
 * fullPlan:[{week,phaseShort,focus,load}], detailedWeek:{weekNumber,phaseName,intro,days:[{day,title,tag,set}]x7,loadSummary},
 * drills:[{tag,name,cue,rx}] (<=6), test:{title,body,targets:[{metric,now,goal}]}, closing:{line}
 * Accent-highlight inline text by wrapping it in <<...>>.
 */
function sampleDoc(sportId) {
  const t = SPORT_THEMES[sportId];
  return {
    planId: `SP-DEMO-${sportId.slice(0, 3).toUpperCase()}`, sportId, issuedDate: '06.14.26', blockLabel: 'BLOCK 01 / 04',
    athlete: { name: 'Sample Athlete', descriptor: `AGE 16 · ${t.label.split(' ')[0]} · SAMPLE`, sectionWord: 'The Athlete' },
    coverLead: `Twelve weeks built around your game — not a generic workout. Targeted to your weak points and re-tested at the end.`,
    goal: { chipLabel: 'The Target', chipValue: 'Reach the next level', statement: `Close the gap to your goal by fixing the <<top weakness>> and holding form when <<fatigue>> sets in.` },
    blockMeta: { weeks: 12, phasesCount: 4, sessionsPerWeek: 6, phaseFlow: 'FOUNDATION → BUILD → POWER → SHARPEN' },
    metrics: [{ key: 'Metric A', value: '28.5', unit: 'UNIT' }, { key: 'Metric B', value: '3.41', unit: 'UNIT' }, { key: 'Metric C', value: '11.6', unit: 'UNIT' }, { key: 'Metric D', value: '71%', unit: 'UNIT' }, { key: 'Metric E', value: '62%', unit: 'UNIT' }, { key: 'Metric F', value: '38', unit: 'UNIT' }],
    focusAreas: [{ label: 'Primary weakness', severity: 5 }, { label: 'Secondary weakness', severity: 4 }, { label: 'Third focus', severity: 3 }, { label: 'Fourth focus', severity: 2 }],
    phases: [{ weeksLabel: 'WK\n01–03', name: 'Foundation', desc: 'Movement quality, technical rebuild, base conditioning.', loadLabel: 'LOW' }, { weeksLabel: 'WK\n04–07', name: 'Build', desc: 'Skill volume and strength under progressive overload.', loadLabel: 'MOD' }, { weeksLabel: 'WK\n08–11', name: 'Power', desc: 'Convert base to explosive, game-speed application.', loadLabel: 'HIGH' }, { weeksLabel: 'WK\n12', name: 'Sharpen', desc: 'Taper: speed stays, volume drops, full recovery.', loadLabel: 'PEAK' }],
    weeklyRhythm: [{ key: 'Skill', count: '3×', note: 'TECHNICAL REPS' }, { key: 'Strength/Power', count: '2×', note: 'LIFT + PLYO' }, { key: 'Conditioning', count: '1×', note: 'ENERGY SYSTEM' }],
    fullPlan: Array.from({ length: 12 }, (_, i) => ({ week: String(i + 1).padStart(2, '0'), phaseShort: i < 3 ? 'FOUND.' : i < 7 ? 'BUILD' : i < 11 ? 'POWER' : 'SHARPEN', focus: "Weekly focus summary line for this week's primary work", load: i < 3 ? 'LOW' : i < 7 ? 'MOD' : i < 11 ? 'HIGH' : 'PEAK' })),
    detailedWeek: { weekNumber: '06', phaseName: 'BUILD', intro: 'A representative week, fully prescribed. Follow as-is or log it in the app to auto-adjust.', days: [{ day: 'MON', title: 'Skill + Lift', tag: '90 MIN', set: '<<Primary skill block>> · main lift 4×5 · accessory 3×8' }, { day: 'TUE', title: 'Skill + Agility', tag: '75 MIN', set: 'Technical series · <<key drill 5×10>> · agility 6 reps' }, { day: 'WED', title: 'Conditioning', tag: '45 MIN', set: '<<Interval set>> · movement circuit · core' }, { day: 'THU', title: 'Skill Volume', tag: '60 MIN', set: '<<High-rep technical work>> · situational reps' }, { day: 'FRI', title: 'Strength + Power', tag: '80 MIN', set: 'Main lift <<4×4>> · plyo · finishing work 4×8' }, { day: 'SAT', title: 'Live Reps', tag: '90 MIN', set: '<<Game-speed application>> · keep score' }, { day: 'SUN', title: 'Recovery', tag: 'OFF · mobility + film', set: 'Full rest. 20-min mobility + review film.' }], loadSummary: '6 SESSIONS' },
    drills: [{ tag: 'Focus 1', name: 'Drill One', cue: 'Cue for the first drill, aimed at the primary weakness.', rx: '5 × 10' }, { tag: 'Focus 1', name: 'Drill Two', cue: 'Progression of the first focus under added difficulty.', rx: '5 × 10 · L/R' }, { tag: 'Focus 2', name: 'Drill Three', cue: 'Targets the secondary weakness with controlled reps.', rx: '4 × 8' }, { tag: 'Focus 3', name: 'Drill Four', cue: 'Builds the third focus area with timed sets.', rx: '8 reps · timed' }, { tag: 'Handle', name: 'Drill Five', cue: 'Technical control work to free up the fundamentals.', rx: '6 patterns · 30s' }, { tag: 'Conditioning', name: 'Drill Six', cue: 'Fatigue work so skill holds late in competition.', rx: '5 rounds · 10 reps' }],
    test: { title: 'Benchmark Test — Week 12', body: `Re-run the week-one test. Target <<primary metric>> improvement and hold <<form under fatigue>>.`, targets: [{ metric: 'Primary metric', now: '31%', goal: '38%' }, { metric: 'Power metric', now: '28.5', goal: '32.5' }, { metric: 'Speed metric', now: '11.6s', goal: '10.9s' }, { metric: 'Skill metric', now: '62%', goal: '80%' }] },
    closing: { line: `Work is done in the <<dark gym.>>` },
  };
}

if (typeof module !== 'undefined' && module.exports) module.exports = { sampleDoc };
if (typeof window !== 'undefined') window.PlanPdfSample = { sampleDoc };
