/* =========================================================
   ai-client.js — Module 1 (client). Talks to the server AI
   endpoints and renders the AI plan JSON in the Athlon
   monochrome style. The API key lives only on the server;
   the browser just POSTs the assessment and renders JSON.
   Exposes window.Athlon = { generatePlan, coach, renderAIPlan, lastPlan }.
   ========================================================= */
(function () {
  const E = s => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');

  async function postJSON(path, body, signal) {
    const res = await fetch('/api' + path, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body || {}), signal,
    });
    if (!res.ok) {
      let msg = 'Request failed (' + res.status + ').';
      try { const j = await res.json(); msg = j.error || j.detail || msg; } catch (_e) {}
      throw new Error(msg);
    }
    return res.json();
  }

  /* Request a real, validated plan. Resolves to { ok, source, plan, meta }.
     Throws only on a network/server error (the server itself always returns a
     plan — AI or deterministic fallback). */
  async function generatePlan(assessment, history) {
    console.log('[Sporve] generating plan — payload:', assessment);
    // Hard client-side timeout so a slow/hanging server can never freeze the
    // processing screen. On abort/error we throw → the caller renders the
    // built-in offline fallback report. A report is ALWAYS produced.
    const ctrl = new AbortController();
    const TIMEOUT_MS = 40000;
    const timer = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
    try {
      const out = await postJSON('/ai/training-plan', { assessment: assessment || {}, history: history || [] }, ctrl.signal);
      Athlon.lastPlan = out.plan;
      Athlon.lastPlanSource = out.source;
      console.log('[Sporve] plan received — source:', out.source);
      return out;
    } catch (err) {
      console.warn('[Sporve] plan request failed/timed out — using offline fallback:', err && err.message);
      throw err;
    } finally {
      clearTimeout(timer);
    }
  }

  async function coach(payload, signal) {
    return postJSON('/ai/coach', payload || {}, signal);
  }

  /* Grounded enrichment: send the ALREADY-built plan context, get back a
     coach summary + parent note. Fully optional — resolves to null on any
     failure/timeout so it can never block or break the rendered plan. */
  async function enrichPlan(ctx) {
    const c = new AbortController();
    const timer = setTimeout(() => c.abort(), 22000);
    try { return await postJSON('/ai/enrich-plan', ctx || {}, c.signal); }
    catch (e) { console.warn('[Sporve] plan enrichment skipped:', e && e.message); return null; }
    finally { clearTimeout(timer); }
  }

  /* Grounded weekly NARRATION: the deterministic engine (adaptWeek) already
     decided the next week; this asks the server AI to write the coach voice over
     those decisions. Optional — resolves to null on any failure/timeout so the
     deterministic review text always stands. */
  async function coachReview(payload) {
    const c = new AbortController();
    const timer = setTimeout(() => c.abort(), 20000);
    try { return await postJSON('/ai/update-progress', payload || {}, c.signal); }
    catch (e) { console.warn('[Sporve] coach review narration skipped:', e && e.message); return null; }
    finally { clearTimeout(timer); }
  }

  /* ---------- renderer: AI plan JSON → existing .bp markup (monochrome) ---------- */
  function renderAIPlan(plan, hostEl, opts) {
    opts = opts || {};
    if (!plan || !plan.planMeta) { if (hostEl) hostEl.innerHTML = ''; return; }
    const m = plan.planMeta;
    const tag = arr => `<div class="bp__tags">${(arr || []).map(x => `<span class="bp__tag">${E(x)}</span>`).join('')}</div>`;

    const drill = (d, n) => `
      <div class="drillrow">
        <label class="drillrow__check"><input type="checkbox" disabled /><span></span></label>
        <div class="drillrow__body">
          <div class="drillrow__hd"><h5>${n}. ${E(d.name)}</h5></div>
          <div class="drillrow__meta"><span>${E(d.prescription)}</span>${(d.equipment && d.equipment.length) ? `<span>·</span><span>${E(d.equipment.join(', '))}</span>` : ''}</div>
          <p class="drillrow__why"><b>Purpose:</b> ${E(d.purpose)}</p>
          <p class="drillrow__focus"><b>Coaching cues:</b> ${E((d.cues || []).join(' · '))}</p>
          <p class="drillrow__prog"><b>Progress to:</b> ${E(d.progression)}</p>
          <p class="drillrow__miss"><b>Easier:</b> ${E(d.regression)}</p>
        </div>
      </div>`;

    const session = (s) => `
      <div class="daycard daycard--live">
        <div class="daycard__hd"><span class="daycard__day">${E(s.day)}</span><b>${E(s.title)}</b><span class="daycard__time">~${E(s.durationMin)} min</span></div>
        <p class="daycard__phase"><b>Goal:</b> ${E(s.goalServed)}</p>
        ${s.warmup ? `<p class="daycard__phase"><b>Warmup:</b> ${E(s.warmup.name)} — ${E(s.warmup.durationMin)} min</p>` : ''}
        <div class="drillrows">${(s.drills || []).map((d, i) => drill(d, i + 1)).join('')}</div>
        ${s.cooldown ? `<p class="daycard__phase"><b>Cooldown:</b> ${E(s.cooldown.name)} — ${E(s.cooldown.durationMin)} min</p>` : ''}
      </div>`;

    const week = (w) => `
      <div class="bp__section">
        <h4>Week ${E(w.week)} — ${E(w.theme)} <span class="muted">(rest: ${E((w.restDays || []).join(', ') || 'as needed')})</span></h4>
        <div class="daycards daycards--live">${(w.sessions || []).map(session).join('')}</div>
      </div>`;

    const benchmarks = (plan.benchmarks || []).map(b => `<li><b>${E(b.name)}</b> — ${E(b.target)} <span class="muted">(${E(b.measureAt)})</span></li>`).join('');

    hostEl.innerHTML = `
      <div class="bp">
        <div class="bp__head">
          <h3>${E(m.sport)} Training Plan</h3>
          <span>${E(m.ageBand)} · ${E(m.daysPerWeek)}×/week · ${E(m.weeks)} weeks</span>
        </div>
        <div class="bp__section"><h4>Focus</h4><p>A ${E(m.weeks)}-week plan for <strong>${E(m.sport)}</strong>, built for the ${E(m.ageBand)} age band, training ${E(m.daysPerWeek)}×/week toward ${E((m.primaryGoals || []).join(', '))}.</p>${tag(m.primaryGoals)}</div>
        ${(plan.weeks || []).map(week).join('')}
        ${benchmarks ? `<div class="bp__section"><h4>Progress benchmarks</h4><ul class="plan-list">${benchmarks}</ul></div>` : ''}
        ${plan.parentNotes ? `<div class="bp__section"><h4>Parent recommendations</h4><p>${E(plan.parentNotes)}</p></div>` : ''}
        <div class="ai-note"><b>${Athlon.lastPlanSource === 'ai' ? 'Generated by Sporve AI' : 'Offline plan'}</b> ${Athlon.lastPlanSource === 'ai' ? 'from your athlete’s metrics, age, and goals.' : 'a built-in starter plan — add an API key for fully AI-personalized plans.'}</div>
        <div class="bp__cta">
          <strong>Keep this plan working for your athlete</strong>
          <span>Unlock auto-progressing plans, a downloadable report &amp; the AI coach.</span>
          <div class="bp__price">
            <button type="button" class="btn btn--ghost" data-goresults>See my options →</button>
          </div>
        </div>
      </div>`;
  }

  window.Athlon = { generatePlan, coach, enrichPlan, coachReview, renderAIPlan, lastPlan: null, lastPlanSource: null };
})();
