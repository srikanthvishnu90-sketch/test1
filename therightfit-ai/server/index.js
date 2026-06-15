/* =========================================================
   TheRightFit AI — Express server.
   Serves the static frontend AND the JSON API from one origin
   (so the browser uses relative /api/... URLs with no CORS).
   ========================================================= */
require('dotenv').config(); // load .env (ANTHROPIC_API_KEY etc.) before anything reads process.env
const path = require('path');
const express = require('express');

require('./db'); // runs migrations + seeds on require
const { router: authRouter } = require('./auth');

const app = express();
const PORT = process.env.PORT || 3000;
const ROOT = path.join(__dirname, '..');

app.use(express.json({ limit: '2mb' }));

// ---- API ----
app.use('/api/auth', authRouter);
app.use('/api/athletes', require('./routes/athletes'));
app.use('/api/plans', require('./routes/plans'));
app.use('/api/reports', require('./routes/reports'));
app.use('/api/progress', require('./routes/progress'));
app.use('/api/ai', require('./routes/ai'));
app.use('/api/drills', require('./routes/drills'));
app.get('/api/health', (_req, res) => res.json({ ok: true }));

// Isolated, read-only themed plan-PDF export (renders a PlanDocument → PDF and
// records it in its own plan_pdfs table). Additive; touches no existing table.
app.use('/api/plan-pdf', require('./routes/plan-pdf'));

// Stateless branded PDF of the client-built plan (no auth/DB — works anonymously).
app.post('/api/report/pdf', async (req, res) => {
  try {
    const { buildPlanPdf, buildReportPdf } = require('./pdf');
    const body = req.body || {};
    const isReport = body.kind === 'report';
    const bytes = await (isReport ? buildReportPdf(body) : buildPlanPdf(body));
    const a = body.athlete || {};
    const base = isReport ? (body.title || 'Report') : ('Sporve-' + String(a.sport || 'Training') + '-Plan');
    const fname = String(base).replace(/[^a-z0-9]+/gi, '-').replace(/^-|-$/g, '') + '.pdf';
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', 'attachment; filename="' + fname + '"');
    res.send(Buffer.from(bytes));
  } catch (e) {
    console.error('[pdf] generation failed:', e);
    res.status(500).json({ error: 'PDF generation failed.' });
  }
});

// Coming-soon sport demand capture (public; no auth).
app.post('/api/notify', (req, res) => {
  try {
    const { sport, email } = req.body || {};
    if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(String(email))) return res.status(400).json({ error: 'Valid email required.' });
    const { db } = require('./db');
    db.prepare('CREATE TABLE IF NOT EXISTS notify_signups (id INTEGER PRIMARY KEY AUTOINCREMENT, sport TEXT, email TEXT, created_at TEXT DEFAULT CURRENT_TIMESTAMP)').run();
    db.prepare('INSERT INTO notify_signups (sport, email) VALUES (?, ?)').run(String(sport || '').slice(0, 80), String(email).slice(0, 160));
    res.json({ ok: true });
  } catch (e) { console.error('[notify]', e.message); res.status(500).json({ error: 'Could not save signup.' }); }
});

// Unknown API routes → JSON 404 (never fall through to the SPA shell).
app.use('/api', (_req, res) => res.status(404).json({ error: 'Not found.' }));

// ---- Static frontend ----
app.use(express.static(ROOT, { extensions: ['html'] }));

// Catch-all → serve the app shell for any non-API GET.
app.get('*', (_req, res) => res.sendFile(path.join(ROOT, 'index.html')));

// ---- JSON error handler ----
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Something went wrong on the server.' });
});

const aiStatus = require('./ai/provider').status();
const server = app.listen(PORT, () => {
  console.log(`Sporve running → http://localhost:${PORT}`);
  console.log(aiStatus.configured
    ? `AI: ${aiStatus.provider} (${aiStatus.model}) — live`
    : 'AI: no key found — running on the deterministic fallback. Add ANTHROPIC_API_KEY to .env to go live.');
});
server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`\nPort ${PORT} is already in use — another server is running.`);
    console.error(`Fix: stop it (lsof -ti tcp:${PORT} | xargs kill) or run with a different port: PORT=3001 npm start\n`);
    process.exit(1);
  }
  throw err;
});

// Never let a stray rejection (e.g. an aborted upstream fetch) crash the process.
process.on('unhandledRejection', (reason) => { console.error('[unhandledRejection]', reason); });
process.on('uncaughtException', (err) => { console.error('[uncaughtException]', err); });

// Graceful shutdown: stop accepting connections, then close the DB.
['SIGINT', 'SIGTERM'].forEach((sig) => process.on(sig, () => {
  console.log(`\n${sig} received — shutting down…`);
  server.close(() => {
    try { const { db } = require('./db'); if (db && db.close) db.close(); } catch (_e) {}
    process.exit(0);
  });
  setTimeout(() => process.exit(0), 5000).unref();
}));
