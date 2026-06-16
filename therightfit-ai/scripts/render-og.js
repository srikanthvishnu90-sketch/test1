/* =========================================================
   Render a 1200×630 social card → assets/og.png (PNG; SVG OG
   images don't preview on most platforms). EPE Void & Light look.
   Run on a machine with the webfonts available for the exact brand
   type; falls back to system fonts otherwise. Run: node scripts/render-og.js
   ========================================================= */
const path = require('path');
const puppeteer = require('puppeteer-core');
const { chromePath } = require('../server/plan-pdf-render');

const HTML = `<!doctype html><html><head><meta charset="utf-8">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Anybody:ital,wght@1,900&family=JetBrains+Mono:wght@500;700&display=swap" rel="stylesheet">
<style>
  *{margin:0;box-sizing:border-box}
  html,body{width:1200px;height:630px}
  body{background:#000;color:#e2e2e2;font-family:'Anybody',-apple-system,'Segoe UI Black',sans-serif;
    position:relative;overflow:hidden;padding:72px 80px;display:flex;flex-direction:column;justify-content:space-between}
  .accent{position:absolute;right:-120px;top:-120px;width:520px;height:520px;border-radius:50%;
    background:radial-gradient(circle,#FF5A1F 0%,rgba(255,90,31,.0) 62%);opacity:.5;mix-blend-mode:screen}
  .eyebrow{font-family:'JetBrains Mono',ui-monospace,monospace;font-size:18px;letter-spacing:.28em;text-transform:uppercase;color:#988e90}
  h1{font-style:italic;font-weight:900;text-transform:uppercase;letter-spacing:-.03em;line-height:.86;font-size:188px;color:#fff}
  .tag{font-size:30px;font-weight:700;color:#cfc4c5;max-width:760px;line-height:1.2;font-style:normal}
  .foot{display:flex;justify-content:space-between;align-items:center;border-top:1px solid #222;padding-top:22px;
    font-family:'JetBrains Mono',ui-monospace,monospace;font-size:16px;letter-spacing:.12em;text-transform:uppercase;color:#988e90}
  .foot b{color:#FF5A1F}
</style></head>
<body>
  <div class="accent"></div>
  <div><div class="eyebrow">Sporve · Performance Engine</div></div>
  <div><h1>Sporve</h1><p class="tag">AI training plans for young athletes — built for their sport, age &amp; goals, then tracked as they grow.</p></div>
  <div class="foot"><span>AGES 8–18 · SPORT-SPECIFIC · AGE-SAFE</span><span><b>●</b> YOUR METRICS · YOUR COACH</span></div>
</body></html>`;

(async () => {
  const browser = await puppeteer.launch({ headless: true, executablePath: chromePath(), args: ['--no-sandbox', '--disable-gpu'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 1200, height: 630, deviceScaleFactor: 2 });
  await page.setContent(HTML, { waitUntil: 'domcontentloaded' });
  await Promise.race([page.evaluate('document.fonts && document.fonts.ready'), new Promise(r => setTimeout(r, 4000))]).catch(() => {});
  await page.screenshot({ path: path.join(__dirname, '..', 'assets', 'og.png'), type: 'png', clip: { x: 0, y: 0, width: 1200, height: 630 } });
  await browser.close();
  console.log('wrote assets/og.png (1200×630)');
})().catch(e => { console.error('og render failed:', e.message); process.exit(1); });
