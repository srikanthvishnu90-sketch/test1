/* =========================================================
   Sporve plan-PDF — HTML template (Phase 4). Vanilla port of the
   KINETIK spec. Fonts load via Google Fonts (Archivo + Archivo
   Expanded + JetBrains Mono); swap to base64 @font-face for a
   zero-network serverless render later (PRODUCTION NOTE in the spec).
   ========================================================= */
const { CSS } = (typeof require !== 'undefined') ? require('./css.js') : window.PlanPdfCss;

const FONTS_LINK = '<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>'
  + '<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@100..900&family=Archivo+Expanded:wght@100..900&family=JetBrains+Mono:wght@100..800&display=swap" rel="stylesheet">';

const PLAY = `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M5 3l16 9-16 9z"/></svg>`;
const esc = (s) => (s == null ? '' : String(s)).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const hl = (s) => esc(s).replace(/&lt;&lt;(.+?)&gt;&gt;/g, '<span class="sp">$1</span>');
const em = (s) => esc(s).replace(/&lt;&lt;(.+?)&gt;&gt;/g, '<em>$1</em>');
const strip = (s) => esc(s).replace(/&lt;&lt;|&gt;&gt;/g, '');
const motif = (t, style, op) => t.motif
  ? `<svg class="court" style="${style};opacity:${op}" viewBox="0 0 500 470">${t.motif}</svg>` : '';

function buildHtml(doc, t) {
  const cells = doc.metrics.slice(0, 6).map(m =>
    `<div class="cell"><div class="k">${esc(m.key)}</div><div class="v">${hl(m.value)}</div><div class="u">${esc(m.unit)}</div></div>`).join('');
  const bars = doc.focusAreas.slice(0, 4).map(f =>
    `<div class="fitem"><div class="row"><span>${esc(f.label)}</span><span class="sev">SEV ${f.severity}</span></div><div class="bar"><i style="width:${f.severity * 19 + 4}%"></i></div></div>`).join('');
  const phaseRows = doc.phases.map(p =>
    `<div class="phase"><div class="d">${esc(p.weeksLabel)}</div><div><div class="nm">${esc(p.name)}</div><div class="desc">${esc(p.desc)}</div></div><div class="load"><div class="n">${esc(p.loadLabel)}</div><div class="l">INTENSITY</div></div></div>`).join('');
  const rhythm = (doc.weeklyRhythm || []).slice(0, 3).map(r =>
    `<div class="cell"><div class="k">${esc(r.key)}</div><div class="v" style="font-size:22px">${esc(r.count)}</div><div class="u">${esc(r.note)}</div></div>`).join('');
  const planRows = doc.fullPlan.map(w =>
    `<tr><td class="wk">${esc(w.week)}</td><td class="ph"><span class="phasebadge"></span>${esc(w.phaseShort)}</td><td>${esc(w.focus)}</td><td class="lo">${esc(w.load)}</td></tr>`).join('');
  const dayRows = doc.detailedWeek.days.map(d => {
    const rest = /rest|recovery|off/i.test(d.title) ? ' rest' : '';
    return `<div class="day${rest}"><div class="dn">${esc(d.day)}</div><div class="ti">${esc(d.title)}<span class="tag">${esc(d.tag)}</span></div><div class="set${rest ? ' mut' : ''}">${hl(d.set)}</div></div>`;
  }).join('');
  const drillCards = doc.drills.slice(0, 6).map(d =>
    `<div class="drill"><div class="play">${PLAY}</div><div class="tag">${esc(d.tag)}</div><div class="nm">${esc(d.name)}</div><div class="cue">${esc(d.cue)}</div><div class="rx">${esc(d.rx)}</div></div>`).join('');
  const targetRows = doc.test.targets.map(r =>
    `<tr><td class="metric">${esc(r.metric)}</td><td class="now">${esc(r.now)}</td><td class="goal">${esc(r.goal)}</td></tr>`).join('');

  const root = `:root{--ink:#0d0d0e;--paper:#fff;--accent:${t.accent};--accent-deep:${t.accentDeep};--soft:${t.accent}1A;--mut:#7a7a7e;--line:rgba(13,13,14,.16);--line-strong:rgba(13,13,14,.85);}`;
  const lead = doc.coverLead ? esc(doc.coverLead) : strip(doc.goal.statement);

  return `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">${FONTS_LINK}<style>${root}${CSS}</style></head><body>
<section class="page cover">${motif(t, 'top:-40px;right:-60px;width:560px;height:560px', 0.5)}
  <div class="frame"><div class="topline"><div class="eyebrow">Sporve · Personalized Plan</div>
    <div class="id">PLAN №&nbsp;${esc(doc.planId)}<br>ISSUED&nbsp;<b>${esc(doc.issuedDate)}</b><br>${esc(doc.blockLabel)}</div></div>
  <div><h1 class="display">${esc(t.coverWord)}<span class="sub">Performance Plan</span></h1>
    <p class="lead">${lead}</p>
    <div class="athlete"><span class="name">${esc(doc.athlete.name)}</span><span class="meta">${esc(doc.athlete.descriptor)}</span></div></div>
  <div class="footer"><div class="goalchip"><div class="k">${esc(doc.goal.chipLabel)}</div><div class="v">${esc(doc.goal.chipValue)}</div></div>
    <div class="block">${doc.blockMeta.weeks}-WEEK BLOCK<br><b>${doc.blockMeta.phasesCount} PHASES · ${doc.blockMeta.sessionsPerWeek} SESSIONS / WK</b><br>${esc(doc.blockMeta.phaseFlow)}</div></div></div></section>

<section class="page">${motif(t, 'bottom:-160px;left:-120px;width:420px;height:420px', 0.10)}
  <div class="frame"><div class="head"><div class="sec">${esc(doc.athlete.sectionWord)}</div><div class="num">01</div></div>
  <p class="subhead">Where you are today, measured. Every number here is re-tested at the end of the block to prove the work showed up.</p>
  <div class="board">${cells}</div>
  <div class="twocol"><div class="goalbox"><div class="k">${esc(doc.goal.chipLabel)}</div><p>${hl(doc.goal.statement)}</p></div>
    <div class="focus"><div class="k">Focus Areas — from your intake</div>${bars}</div></div></div></section>

<section class="page"><div class="frame"><div class="head"><div class="sec">The Arc</div><div class="num">02</div></div>
  <p class="subhead">Four phases, building from base to peak so you arrive sharp — not just fit.</p>
  <div class="phases">${phaseRows}</div>
  ${rhythm ? `<div style="margin-top:30px" class="head"><div class="sec" style="font-size:22px">Weekly Rhythm</div></div>
  <p class="subhead" style="margin-bottom:14px">The repeating weekly structure, progressively overloaded.</p>
  <div class="board" style="grid-template-columns:repeat(3,1fr)">${rhythm}</div>` : ''}</div></section>

<section class="page"><div class="frame"><div class="head"><div class="sec">The Full Plan</div><div class="num">03</div></div>
  <p class="subhead">All ${doc.blockMeta.weeks} weeks at a glance — the complete progression, week by week.</p>
  <table class="grid12"><tr><th style="width:42px">WK</th><th style="width:110px">Phase</th><th>Primary Focus</th><th style="width:80px;text-align:right">Load</th></tr>${planRows}</table></div></section>

<section class="page"><div class="frame"><div class="head"><div class="sec">Week ${esc(doc.detailedWeek.weekNumber)}</div><div class="num">04 · ${esc(doc.detailedWeek.phaseName)}</div></div>
  <p class="subhead">${esc(doc.detailedWeek.intro)}</p>
  <div class="week">${dayRows}</div>
  <div class="weektot"><span>WEEK ${esc(doc.detailedWeek.weekNumber)} · ${esc(doc.detailedWeek.phaseName)}</span><span>WEEKLY LOAD&nbsp;&nbsp;<b>${esc(doc.detailedWeek.loadSummary)}</b></span></div></div></section>

<section class="page"><div class="frame"><div class="head"><div class="sec">Skill Work</div><div class="num">05</div></div>
  <p class="subhead">The drills inside your week, each aimed at a focus area. Every drill has a demo — tap the marker to watch the exact rep first.</p>
  <div class="drills">${drillCards}</div>
  <div class="watchnote"><span class="dot"></span>EVERY DRILL LINKS TO A SINGLE-LIBRARY VIDEO DEMO · NO SEARCHING ACROSS PLATFORMS</div></div></section>

<section class="page">${motif(t, 'top:-80px;right:-90px;width:460px;height:460px', 0.08)}
  <div class="frame"><div class="head"><div class="sec">Prove It</div><div class="num">06</div></div>
  <p class="subhead">End of block, re-run the test below under the same conditions as week one.</p>
  <div class="testbox"><div class="k">${esc(doc.test.title)}</div><div class="set">${hl(doc.test.body)}</div></div>
  <table class="targets"><tr><th>Mark</th><th>Now</th><th>Block Target</th></tr>${targetRows}</table>
  <div class="closing"><div class="big">${em(doc.closing.line)}</div>
    <div class="brandfoot"><span>SPORVE · ${esc(t.label)}</span><span>PLAN ${esc(doc.planId)} · ${esc(doc.blockLabel)}</span></div></div></div></section>
</body></html>`;
}

if (typeof module !== 'undefined' && module.exports) module.exports = { buildHtml };
if (typeof window !== 'undefined') window.PlanPdfTemplate = { buildHtml };
