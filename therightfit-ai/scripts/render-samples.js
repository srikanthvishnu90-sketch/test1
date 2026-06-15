/* =========================================================
   Sporve plan-PDF — render one sample HTML per sport (Phase 5,
   zero-dependency). Open pdf-samples/index.html (or each file) in
   a browser to visually verify all 27 sports — this is the exact
   HTML/CSS the PDF will render from. PDF bytes come when puppeteer
   is wired (Phase 6, after visual sign-off).
   Run: node scripts/render-samples.js
   ========================================================= */
const fs = require('fs');
const path = require('path');
const { SPORT_THEMES } = require('../plan-pdf/themes.js');
const { buildHtml } = require('../plan-pdf/template.js');
const { sampleDoc } = require('../plan-pdf/sampleDoc.js');

const out = path.join(__dirname, '..', 'pdf-samples');
fs.mkdirSync(out, { recursive: true });

const ids = Object.keys(SPORT_THEMES);
ids.forEach(id => {
  const html = buildHtml(sampleDoc(id), SPORT_THEMES[id]);
  fs.writeFileSync(path.join(out, id + '.html'), html);
});

// simple index for eyeballing
const links = ids.map(id =>
  `<li><a href="${id}.html">${id}</a> <span style="display:inline-block;width:14px;height:14px;border-radius:3px;background:${SPORT_THEMES[id].accent};vertical-align:middle"></span></li>`).join('');
fs.writeFileSync(path.join(out, 'index.html'),
  `<!doctype html><meta charset="utf-8"><title>Sporve plan-PDF samples</title>`
  + `<body style="font-family:system-ui;padding:32px;max-width:640px"><h1>Plan-PDF samples — ${ids.length} sports</h1>`
  + `<p>Each opens the exact 7-page HTML the PDF renders from. Print to PDF (Cmd+P) to preview the document.</p><ul style="line-height:2">${links}</ul></body>`);

console.log('Rendered ' + ids.length + ' sample HTML files → pdf-samples/');
console.log('Sports:', ids.join(', '));
