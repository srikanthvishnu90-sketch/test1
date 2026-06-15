/* =========================================================
   Sporve plan-PDF — isolated HTML→PDF renderer (Phase 6).
   READ-ONLY export: takes a PlanDocument, returns PDF bytes. Drives
   the system Chrome via puppeteer-core (no bundled Chromium). Reuses
   one warm browser. Touches NO app state and NO existing tables.
   ========================================================= */
const puppeteer = require('puppeteer-core');
const path = require('path');
const { SPORT_THEMES } = require(path.join(__dirname, '..', 'plan-pdf', 'themes.js'));
const { buildHtml } = require(path.join(__dirname, '..', 'plan-pdf', 'template.js'));

function chromePath() {
  if (process.env.CHROME_LOCAL_PATH) return process.env.CHROME_LOCAL_PATH;
  const candidates = [
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
    '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
    '/usr/bin/google-chrome', '/usr/bin/chromium-browser', '/usr/bin/chromium',
  ];
  for (const c of candidates) { try { if (require('fs').existsSync(c)) return c; } catch (e) {} }
  return candidates[0];
}

let _browser = null;
async function getBrowser() {
  if (_browser && _browser.connected) return _browser;
  _browser = await puppeteer.launch({
    headless: true, executablePath: chromePath(),
    args: ['--no-sandbox', '--disable-dev-shm-usage', '--disable-gpu'],
  });
  return _browser;
}

async function renderPlanPdf(doc) {
  if (!doc || !doc.sportId) throw new Error('PlanDocument with sportId required.');
  const theme = SPORT_THEMES[doc.sportId];
  if (!theme) throw new Error('unknown sportId: ' + doc.sportId);
  const html = buildHtml(doc, theme);
  const browser = await getBrowser();
  const page = await browser.newPage();
  try {
    page.setDefaultNavigationTimeout(15000);
    // Load DOM, then give webfonts a bounded window — never hang if the font CDN
    // is slow/unreachable (renders with graceful fallback fonts in that case).
    await page.setContent(html, { waitUntil: 'domcontentloaded' });
    await Promise.race([
      page.evaluate('document.fonts && document.fonts.ready'),
      new Promise((r) => setTimeout(r, 4000)),
    ]).catch(() => {});
    await page.emulateMediaType('print');
    const pdf = await page.pdf({ preferCSSPageSize: true, printBackground: true });
    return Buffer.from(pdf);
  } finally { await page.close().catch(() => {}); }
}

module.exports = { renderPlanPdf, chromePath };
