/* =========================================================
   Sporve plan-PDF — stylesheet (from the KINETIK spec, verbatim).
   Font names are aliased to Google-hosted families at the bottom:
   ArchivoX → "Archivo Expanded", JBMono → "JetBrains Mono".
   ========================================================= */
const RAW = `
*{margin:0;padding:0;box-sizing:border-box;}
@page{size:8.5in 11in;margin:0;}
html{-webkit-print-color-adjust:exact;print-color-adjust:exact;}
body{font-family:'Archivo',sans-serif;color:var(--ink);background:var(--paper);}
.page{position:relative;width:8.5in;height:11in;overflow:hidden;background:var(--paper);page-break-after:always;}
.page:last-child{page-break-after:auto;}
.frame{position:absolute;inset:0;padding:60px 70px 50px;display:flex;flex-direction:column;}
.eyebrow{font-family:'JBMono';font-size:10px;letter-spacing:.32em;text-transform:uppercase;color:var(--accent);}
.display{font-family:'ArchivoX';font-variation-settings:"wght" 820,"wdth" 125;text-transform:uppercase;line-height:.86;letter-spacing:-.01em;color:var(--ink);}
.mono{font-family:'JBMono';} .mut{color:var(--mut);}
.court{position:absolute;pointer-events:none;}
.court path,.court circle,.court line,.court rect,.court ellipse,.court polygon{fill:none;stroke:var(--accent);}
.court [fill="currentColor"]{fill:var(--accent);stroke:none;}
.head{display:flex;justify-content:space-between;align-items:baseline;border-bottom:2px solid var(--line-strong);padding-bottom:14px;}
.head .sec{font-family:'ArchivoX';font-variation-settings:"wght" 820,"wdth" 122;font-size:42px;text-transform:uppercase;line-height:.9;}
.head .num{font-family:'JBMono';font-size:11px;color:var(--accent);letter-spacing:.2em;}
.subhead{font-size:13px;line-height:1.55;color:var(--mut);max-width:5.2in;margin:18px 0 26px;}
.cover .frame{justify-content:space-between;} .cover .topline{display:flex;justify-content:space-between;align-items:flex-start;}
.cover .id{font-family:'JBMono';font-size:9.5px;letter-spacing:.16em;color:var(--mut);text-align:right;line-height:1.8;} .cover .id b{color:var(--ink);}
.cover h1{font-size:140px;position:relative;z-index:2;}
.cover h1 .sub{display:block;font-size:42px;font-variation-settings:"wght" 660,"wdth" 116;color:var(--accent);letter-spacing:.01em;margin-top:8px;}
.cover .lead{max-width:5.6in;font-size:14.5px;line-height:1.6;margin-top:24px;font-weight:340;position:relative;z-index:2;}
.cover .athlete{display:flex;align-items:flex-end;gap:18px;margin-top:30px;position:relative;z-index:2;}
.cover .athlete .name{font-family:'ArchivoX';font-variation-settings:"wght" 780,"wdth" 116;font-size:34px;text-transform:uppercase;}
.cover .athlete .meta{font-family:'JBMono';font-size:10.5px;letter-spacing:.05em;color:var(--mut);padding-bottom:6px;}
.cover .footer{display:flex;justify-content:space-between;align-items:flex-end;border-top:2px solid var(--line-strong);padding-top:18px;position:relative;z-index:2;}
.cover .goalchip .k{font-family:'JBMono';font-size:9px;letter-spacing:.26em;color:var(--accent);text-transform:uppercase;}
.cover .goalchip .v{font-family:'ArchivoX';font-variation-settings:"wght" 740,"wdth" 110;font-size:26px;text-transform:uppercase;margin-top:5px;}
.cover .block{font-family:'JBMono';font-size:10px;letter-spacing:.08em;color:var(--mut);text-align:right;line-height:1.85;} .cover .block b{color:var(--ink);font-weight:600;}
.board{display:grid;grid-template-columns:repeat(3,1fr);border:1.5px solid var(--line-strong);}
.board .cell{padding:18px;border-right:1px solid var(--line);border-bottom:1px solid var(--line);}
.board .cell:nth-child(3n){border-right:none;} .board .cell:nth-child(n+4){border-bottom:none;}
.board .cell .k{font-family:'JBMono';font-size:9px;letter-spacing:.16em;color:var(--accent);text-transform:uppercase;}
.board .cell .v{font-family:'JBMono';font-weight:700;font-size:30px;margin-top:10px;letter-spacing:-.01em;}
.board .cell .v small{font-size:14px;} .board .cell .u{font-family:'JBMono';font-size:9px;color:var(--mut);margin-top:5px;letter-spacing:.06em;}
.twocol{display:grid;grid-template-columns:1.05fr .95fr;gap:34px;margin-top:30px;}
.goalbox{border-left:3px solid var(--accent);padding:2px 0 2px 20px;}
.goalbox .k{font-family:'JBMono';font-size:9px;letter-spacing:.22em;color:var(--accent);text-transform:uppercase;}
.goalbox p{font-size:19px;line-height:1.36;margin-top:12px;font-weight:400;} .goalbox p .sp{font-variation-settings:"wght" 700;color:var(--accent-deep);}
.focus .k{font-family:'JBMono';font-size:9px;letter-spacing:.22em;color:var(--accent);text-transform:uppercase;margin-bottom:14px;}
.fitem{margin-bottom:15px;} .fitem .row{display:flex;justify-content:space-between;font-family:'JBMono';font-size:11px;margin-bottom:6px;} .fitem .row .sev{color:var(--mut);}
.bar{height:6px;background:var(--soft);overflow:hidden;} .bar i{display:block;height:100%;background:var(--accent);}
.phases{display:flex;flex-direction:column;gap:10px;}
.phase{border:1.5px solid var(--line-strong);padding:18px 22px;display:grid;grid-template-columns:58px 1fr auto;align-items:center;gap:22px;}
.phase .d{font-family:'JBMono';font-size:11px;color:var(--accent);white-space:pre-line;} .phase .nm{font-family:'ArchivoX';font-variation-settings:"wght" 780,"wdth" 116;text-transform:uppercase;font-size:23px;}
.phase .desc{font-size:11.5px;color:var(--mut);margin-top:5px;line-height:1.4;max-width:3.7in;}
.phase .load{text-align:right;} .phase .load .n{font-family:'JBMono';font-weight:700;font-size:22px;color:var(--accent-deep);} .phase .load .l{font-family:'JBMono';font-size:8.5px;color:var(--mut);letter-spacing:.12em;margin-top:3px;}
.grid12{width:100%;border-collapse:collapse;}
.grid12 th{font-family:'JBMono';font-size:9px;letter-spacing:.14em;color:var(--accent);text-transform:uppercase;text-align:left;padding:0 10px 11px 0;border-bottom:2px solid var(--line-strong);}
.grid12 td{font-size:11.5px;padding:9.5px 10px 9.5px 0;border-bottom:1px solid var(--line);vertical-align:top;}
.grid12 td.wk{font-family:'JBMono';font-weight:700;font-size:12px;} .grid12 td.ph{font-family:'JBMono';font-size:9.5px;color:var(--accent-deep);} .grid12 td.lo{font-family:'JBMono';font-size:10px;color:var(--mut);text-align:right;}
.phasebadge{display:inline-block;width:8px;height:8px;background:var(--accent);margin-right:7px;vertical-align:middle;}
.week{border:1.5px solid var(--line-strong);}
.day{display:grid;grid-template-columns:46px 1.15fr 2fr;align-items:center;gap:18px;padding:12.5px 20px;border-bottom:1px solid var(--line);} .day:last-child{border-bottom:none;}
.day .dn{font-family:'JBMono';font-size:10px;letter-spacing:.1em;color:var(--accent);}
.day .ti{font-family:'ArchivoX';font-variation-settings:"wght" 700,"wdth" 108;text-transform:uppercase;font-size:14px;}
.day .ti .tag{font-family:'JBMono';font-size:8px;letter-spacing:.08em;color:var(--mut);display:block;margin-top:4px;text-transform:none;}
.day .set{font-family:'JBMono';font-size:10.5px;line-height:1.55;} .day .set .sp{color:var(--accent-deep);font-weight:600;}
.day.rest{background:var(--soft);} .day.rest .ti{color:var(--mut);}
.weektot{display:flex;justify-content:space-between;align-items:center;margin-top:14px;font-family:'JBMono';font-size:10px;color:var(--mut);} .weektot b{font-size:18px;color:var(--ink);font-weight:700;}
.drills{display:grid;grid-template-columns:1fr 1fr;gap:12px;}
.drill{border:1.5px solid var(--line-strong);padding:17px 18px 15px;position:relative;}
.drill .play{position:absolute;top:15px;right:15px;width:30px;height:30px;border-radius:50%;background:var(--accent);display:flex;align-items:center;justify-content:center;color:#fff;}
.drill .play svg{width:11px;height:11px;margin-left:2px;}
.drill .tag{font-family:'JBMono';font-size:8px;letter-spacing:.14em;color:var(--accent);text-transform:uppercase;}
.drill .nm{font-family:'ArchivoX';font-variation-settings:"wght" 740,"wdth" 110;text-transform:uppercase;font-size:18px;margin-top:8px;line-height:1;}
.drill .cue{font-size:11px;line-height:1.45;color:var(--mut);margin-top:9px;max-width:2.7in;} .drill .rx{font-family:'JBMono';font-size:9.5px;margin-top:10px;}
.watchnote{font-family:'JBMono';font-size:9px;letter-spacing:.1em;color:var(--mut);margin-top:14px;display:flex;align-items:center;gap:8px;} .watchnote .dot{width:7px;height:7px;background:var(--accent);}
.testbox{border:1.5px solid var(--line-strong);padding:22px 24px;}
.testbox .k{font-family:'JBMono';font-size:9px;letter-spacing:.2em;color:var(--accent);text-transform:uppercase;}
.testbox .set{font-family:'JBMono';font-size:12.5px;line-height:1.7;margin-top:12px;} .testbox .set .sp{color:var(--accent-deep);font-weight:600;}
.targets{width:100%;border-collapse:collapse;margin-top:24px;}
.targets th{font-family:'JBMono';font-size:9px;letter-spacing:.14em;color:var(--accent);text-transform:uppercase;text-align:left;padding:0 0 11px;border-bottom:2px solid var(--line-strong);}
.targets td{font-family:'JBMono';font-size:13px;padding:12px 0;border-bottom:1px solid var(--line);}
.targets td.metric{font-family:'Archivo';font-size:13px;font-weight:500;} .targets td.now{color:var(--mut);} .targets td.goal{color:var(--accent-deep);font-weight:700;}
.closing{margin-top:auto;} .closing .big{font-family:'ArchivoX';font-variation-settings:"wght" 820,"wdth" 124;text-transform:uppercase;font-size:42px;line-height:.92;} .closing .big em{font-style:normal;color:var(--accent);}
.brandfoot{display:flex;justify-content:space-between;align-items:center;border-top:2px solid var(--line-strong);padding-top:16px;margin-top:22px;font-family:'JBMono';font-size:9px;letter-spacing:.14em;color:var(--mut);}
`;

// Alias the spec's font-family tokens to Google-hosted variable families.
const CSS = RAW.replace(/'ArchivoX'/g, "'Archivo Expanded'").replace(/'JBMono'/g, "'JetBrains Mono'");

if (typeof module !== 'undefined' && module.exports) module.exports = { CSS };
if (typeof window !== 'undefined') window.PlanPdfCss = { CSS };
