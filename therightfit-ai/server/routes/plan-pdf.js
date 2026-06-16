/* =========================================================
   Sporve plan-PDF — ISOLATED export route (Phase 6 / Addendum Part A).
   READ-ONLY, additive, leaf-level. It renders a PlanDocument to PDF
   and records it in its OWN table (plan_pdfs). It NEVER reads or
   writes any existing table, app state, plan, or progress. Removing
   this file + plan-pdf-render.js + plan-pdf/** leaves the app intact.
   ========================================================= */
const express = require('express');
const { renderPlanPdf } = require('../plan-pdf-render');

const router = express.Router();

// Lightweight in-memory rate limit — PDF rendering spins up Chrome, so cap it
// per client to avoid CPU exhaustion / abuse. 12 renders / 5 min per IP.
const _hits = new Map();
function rateLimit(max, windowMs) {
  return (req, res, next) => {
    const key = req.ip || (req.headers['x-forwarded-for'] || '').split(',')[0] || 'anon';
    const now = Date.now();
    const arr = (_hits.get(key) || []).filter(t => now - t < windowMs);
    if (arr.length >= max) return res.status(429).json({ error: 'Too many PDF requests — please wait a minute and try again.' });
    arr.push(now); _hits.set(key, arr);
    if (_hits.size > 5000) { for (const [k, v] of _hits) if (!v.some(t => now - t < windowMs)) _hits.delete(k); }
    next();
  };
}
router.post('/', rateLimit(12, 5 * 60 * 1000));

// Persistence is optional + fully isolated: a single NEW table, insert + read only.
let db = null, ready = false;
function store() {
  if (ready) return db;
  ready = true;
  try {
    db = require('../db').db;
    db.exec(`CREATE TABLE IF NOT EXISTS plan_pdfs (
      id TEXT PRIMARY KEY,
      user_id INTEGER,
      plan_id TEXT,
      sport_id TEXT,
      doc_json TEXT,
      pdf BLOB,
      created_at TEXT DEFAULT (datetime('now'))
    )`);
  } catch (e) { db = null; }   // DB optional — render still works without persistence
  return db;
}
function newId() { return 'pdf_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 8); }
const fileName = (doc) => ('Sporve-' + String((doc.sports && doc.sports[0] && doc.sports[0].label) || doc.sportId || 'Plan')
  + '-Plan').replace(/[^a-z0-9]+/gi, '-').replace(/^-|-$/g, '') + '.pdf';

// POST /api/plan-pdf  { doc: PlanDocument, planId?, userId? } → renders, stores, streams the PDF.
router.post('/', async (req, res) => {
  const body = req.body || {};
  const doc = body.doc;
  if (!doc || !doc.sportId) return res.status(400).json({ error: 'A PlanDocument with sportId is required.' });
  let pdf;
  try {
    pdf = await renderPlanPdf(doc);                 // read-only render
  } catch (e) {
    console.error('[plan-pdf] render failed:', e.message);
    return res.status(500).json({ error: 'PDF render failed.', detail: e.message });   // FAILURE ISOLATION
  }
  // Record in the isolated table (best-effort; never blocks the download).
  let id = newId();
  try {
    const d = store();
    if (d) d.prepare('INSERT INTO plan_pdfs (id, user_id, plan_id, sport_id, doc_json, pdf) VALUES (?,?,?,?,?,?)')
      .run(id, body.userId || null, body.planId || null, doc.sportId, JSON.stringify(doc), pdf);
  } catch (e) { console.error('[plan-pdf] store skipped:', e.message); }
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', 'attachment; filename="' + fileName(doc) + '"');
  res.setHeader('X-Plan-Pdf-Id', id);              // for re-download
  res.send(pdf);
});

// GET /api/plan-pdf/:id → re-download a previously stored PDF (read-only).
router.get('/:id', (req, res) => {
  const d = store();
  if (!d) return res.status(404).json({ error: 'Not found.' });
  const row = d.prepare('SELECT sport_id, doc_json, pdf FROM plan_pdfs WHERE id = ?').get(req.params.id);
  if (!row || !row.pdf) return res.status(404).json({ error: 'Not found.' });
  let name = 'Sporve-Plan.pdf';
  try { name = fileName(JSON.parse(row.doc_json || '{}')); } catch (e) {}
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', 'attachment; filename="' + name + '"');
  res.send(row.pdf);
});

module.exports = router;
