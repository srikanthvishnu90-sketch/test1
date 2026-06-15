/* =========================================================
   Sporve plan-PDF — theme registry (27 sports).
   Each sport: accent, accentDeep (text-on-white legibility),
   coverWord, label, motif (stroke-only SVG for viewBox 0 0 500 470).
   Adapted from the KINETIK spec to Sporve's vanilla-JS stack.
   ========================================================= */
const M = {
  basketball: `<g stroke-width="2.4"><line x1="205" y1="44" x2="295" y2="44"/><circle cx="250" cy="60" r="9"/><rect x="190" y="20" width="120" height="182"/><circle cx="250" cy="202" r="58"/><path d="M44,20 L44,150"/><path d="M456,20 L456,150"/><path d="M44,150 A232,232 0 0 0 456,150"/></g>`,
  swimming: `<g stroke-width="2.4"><line x1="20" y1="70" x2="480" y2="70"/><line x1="20" y1="150" x2="480" y2="150"/><line x1="20" y1="230" x2="480" y2="230"/><line x1="20" y1="310" x2="480" y2="310"/><line x1="20" y1="390" x2="480" y2="390"/><path d="M20,440 q28,-24 56,0 t56,0 t56,0 t56,0 t56,0 t56,0 t56,0 t56,0" fill="none"/></g>`,
  golf: `<g stroke-width="2.4"><ellipse cx="250" cy="255" rx="185" ry="120"/><ellipse cx="250" cy="255" rx="122" ry="78"/><ellipse cx="250" cy="255" rx="62" ry="40"/><circle cx="250" cy="255" r="7"/><line x1="250" y1="255" x2="250" y2="120"/><path d="M250,120 L304,135 L250,150 Z" fill="currentColor"/></g>`,
  soccer: `<g stroke-width="2.4"><rect x="120" y="20" width="260" height="150"/><rect x="190" y="20" width="120" height="60"/><circle cx="250" cy="22" r="6" fill="currentColor"/><path d="M180,170 A70,70 0 0 0 320,170"/><path d="M60,300 A190,190 0 0 1 440,300"/><circle cx="250" cy="300" r="60"/></g>`,
  baseball_softball: `<g stroke-width="2.4"><path d="M250,90 L410,250 L250,410 L90,250 Z"/><rect x="240" y="80" width="20" height="20"/><rect x="400" y="240" width="20" height="20"/><rect x="240" y="400" width="20" height="20"/><rect x="80" y="240" width="20" height="20"/><circle cx="250" cy="250" r="26"/></g>`,
  football: `<g stroke-width="2.4"><line x1="40" y1="120" x2="460" y2="120"/><line x1="40" y1="200" x2="460" y2="200"/><line x1="40" y1="280" x2="460" y2="280"/><line x1="220" y1="110" x2="220" y2="130"/><line x1="280" y1="110" x2="280" y2="130"/><line x1="220" y1="190" x2="220" y2="210"/><line x1="280" y1="190" x2="280" y2="210"/><path d="M210,400 L210,350 M290,400 L290,350 M180,350 L320,350 M250,350 L250,322"/></g>`,
  volleyball: `<g stroke-width="2.4"><rect x="80" y="80" width="340" height="320"/><line x1="80" y1="240" x2="420" y2="240"/><line x1="80" y1="180" x2="420" y2="180"/><line x1="80" y1="300" x2="420" y2="300"/></g>`,
  lacrosse: `<g stroke-width="2.4"><rect x="80" y="40" width="340" height="390"/><circle cx="250" cy="360" r="55"/><line x1="195" y1="360" x2="305" y2="360"/><line x1="80" y1="235" x2="420" y2="235"/></g>`,
  ice_hockey: `<g stroke-width="2.4"><circle cx="160" cy="160" r="48"/><circle cx="340" cy="160" r="48"/><circle cx="160" cy="160" r="5" fill="currentColor"/><circle cx="340" cy="160" r="5" fill="currentColor"/><line x1="40" y1="300" x2="460" y2="300"/><path d="M200,430 A50,50 0 0 1 300,430"/></g>`,
  rugby: `<g stroke-width="2.4"><rect x="60" y="40" width="380" height="390"/><line x1="60" y1="110" x2="440" y2="110"/><line x1="60" y1="180" x2="440" y2="180" stroke-dasharray="10 8"/><path d="M230,40 L230,12 M270,40 L270,12 M200,26 L300,26"/></g>`,
  distance_running: `<g stroke-width="2.4"><rect x="60" y="120" width="380" height="230" rx="115"/><rect x="90" y="150" width="320" height="170" rx="85"/><rect x="120" y="180" width="260" height="110" rx="55"/></g>`,
  track_sprints: `<g stroke-width="2.4"><line x1="40" y1="120" x2="460" y2="120"/><line x1="40" y1="190" x2="460" y2="190"/><line x1="40" y1="260" x2="460" y2="260"/><line x1="40" y1="330" x2="460" y2="330"/><line x1="100" y1="110" x2="100" y2="340" stroke-width="6"/><line x1="120" y1="120" x2="120" y2="150"/><line x1="120" y1="190" x2="120" y2="220"/></g>`,
  cycling: `<g stroke-width="2.4"><circle cx="250" cy="250" r="110"/><circle cx="250" cy="250" r="126" stroke-dasharray="5 13"/><circle cx="250" cy="250" r="20"/><line x1="250" y1="250" x2="330" y2="330"/><circle cx="338" cy="338" r="9"/></g>`,
  rowing: `<g stroke-width="2.4"><line x1="40" y1="120" x2="460" y2="120"/><line x1="40" y1="200" x2="460" y2="200"/><line x1="40" y1="280" x2="460" y2="280"/><circle cx="120" cy="120" r="5" fill="currentColor"/><circle cx="260" cy="120" r="5" fill="currentColor"/><circle cx="400" cy="120" r="5" fill="currentColor"/><path d="M120,370 q130,-40 260,0 q-130,40 -260,0 Z"/><line x1="250" y1="350" x2="250" y2="390"/></g>`,
  tennis: `<g stroke-width="2.4"><rect x="90" y="40" width="320" height="390"/><line x1="160" y1="135" x2="340" y2="135"/><line x1="160" y1="335" x2="340" y2="335"/><line x1="250" y1="135" x2="250" y2="335"/><line x1="90" y1="235" x2="410" y2="235" stroke-dasharray="4 6"/></g>`,
  pickleball: `<g stroke-width="2.4"><rect x="110" y="50" width="280" height="370"/><line x1="110" y1="200" x2="390" y2="200"/><line x1="110" y1="270" x2="390" y2="270"/><line x1="250" y1="50" x2="250" y2="200"/><line x1="250" y1="270" x2="250" y2="420"/><line x1="110" y1="235" x2="390" y2="235" stroke-dasharray="4 6"/></g>`,
  badminton: `<g stroke-width="2.4"><rect x="110" y="40" width="280" height="390"/><line x1="110" y1="235" x2="390" y2="235" stroke-dasharray="4 6"/><line x1="180" y1="40" x2="180" y2="430"/><line x1="320" y1="40" x2="320" y2="430"/><line x1="110" y1="150" x2="390" y2="150"/><line x1="110" y1="320" x2="390" y2="320"/><path d="M250,235 q40,-90 90,-110"/></g>`,
  table_tennis: `<g stroke-width="2.4"><rect x="120" y="90" width="260" height="320"/><line x1="250" y1="90" x2="250" y2="410"/><line x1="110" y1="250" x2="390" y2="250" stroke-dasharray="3 6"/></g>`,
  strength_training: `<g stroke-width="2.4"><line x1="70" y1="250" x2="430" y2="250"/><rect x="150" y="200" width="22" height="100"/><rect x="125" y="215" width="20" height="70"/><rect x="328" y="200" width="22" height="100"/><rect x="355" y="215" width="20" height="70"/><line x1="60" y1="360" x2="440" y2="360"/></g>`,
  powerlifting: `<g stroke-width="2.4"><line x1="60" y1="250" x2="440" y2="250"/><rect x="150" y="180" width="26" height="140"/><rect x="120" y="195" width="26" height="110"/><rect x="324" y="180" width="26" height="140"/><rect x="354" y="195" width="26" height="110"/><line x1="230" y1="244" x2="270" y2="244"/><line x1="230" y1="256" x2="270" y2="256"/></g>`,
  functional_fitness: `<g stroke-width="2.4"><path d="M150,202 a30,30 0 1 1 60,0"/><circle cx="180" cy="252" r="42"/><rect x="280" y="210" width="100" height="100"/><line x1="60" y1="372" x2="440" y2="372"/><rect x="100" y="347" width="14" height="30"/></g>`,
  boxing: `<g stroke-width="2.4"><line x1="90" y1="30" x2="90" y2="400"/><line x1="90" y1="130" x2="410" y2="130"/><line x1="90" y1="200" x2="410" y2="200"/><line x1="90" y1="270" x2="410" y2="270"/><line x1="320" y1="30" x2="320" y2="300"/><path d="M320,300 m-26,0 a26,40 0 1 0 52,0 a26,40 0 1 0 -52,0"/></g>`,
  wrestling: `<g stroke-width="2.4"><circle cx="250" cy="240" r="180"/><circle cx="250" cy="240" r="120"/><circle cx="250" cy="240" r="40"/><line x1="210" y1="240" x2="290" y2="240"/></g>`,
  martial_arts: `<g stroke-width="2.4"><rect x="80" y="80" width="340" height="280"/><line x1="80" y1="173" x2="420" y2="173"/><line x1="80" y1="266" x2="420" y2="266"/><line x1="193" y1="80" x2="193" y2="360"/><line x1="307" y1="80" x2="307" y2="360"/><path d="M150,400 h200 l-30,30 M150,400 l30,30"/></g>`,
  gymnastics: `<g stroke-width="2.4"><line x1="180" y1="40" x2="180" y2="180"/><line x1="320" y1="40" x2="320" y2="180"/><circle cx="180" cy="210" r="30"/><circle cx="320" cy="210" r="30"/><rect x="90" y="340" width="320" height="18"/><line x1="140" y1="358" x2="120" y2="420"/><line x1="360" y1="358" x2="380" y2="420"/></g>`,
  rock_climbing: `<g stroke-width="2.4"><line x1="120" y1="20" x2="120" y2="450"/><circle cx="180" cy="100" r="8" fill="currentColor"/><circle cx="260" cy="170" r="8" fill="currentColor"/><circle cx="210" cy="250" r="8" fill="currentColor"/><circle cx="300" cy="320" r="8" fill="currentColor"/><circle cx="240" cy="390" r="8" fill="currentColor"/><path d="M180,100 L260,170 L210,250 L300,320 L240,390" stroke-dasharray="6 8"/></g>`,
  general_athletic: `<g stroke-width="2.4"><line x1="60" y1="400" x2="440" y2="400"/><path d="M120,400 A130,130 0 0 1 380,400"/><path d="M160,400 A90,90 0 0 1 340,400"/><path d="M200,400 A50,50 0 0 1 300,400"/></g>`,
};

const SPORT_THEMES = {
  basketball:        { accent: '#E8601C', accentDeep: '#C24E12', coverWord: 'HOOPS',    label: 'BASKETBALL PERFORMANCE',  motif: M.basketball },
  soccer:            { accent: '#16A34A', accentDeep: '#11782F', coverWord: 'FOOTBALL', label: 'SOCCER PERFORMANCE',      motif: M.soccer },
  baseball_softball: { accent: '#C0392B', accentDeep: '#952C20', coverWord: 'DIAMOND',  label: 'BASEBALL PERFORMANCE',    motif: M.baseball_softball },
  football:          { accent: '#7A4A22', accentDeep: '#5C3717', coverWord: 'GRIDIRON', label: 'FOOTBALL PERFORMANCE',    motif: M.football },
  golf:              { accent: '#15803D', accentDeep: '#0E5E2C', coverWord: 'FAIRWAY',  label: 'GOLF PERFORMANCE',        motif: M.golf },
  volleyball:        { accent: '#D69E2E', accentDeep: '#A87A1E', coverWord: 'VOLLEY',   label: 'VOLLEYBALL PERFORMANCE',  motif: M.volleyball },
  lacrosse:          { accent: '#0F766E', accentDeep: '#0B564F', coverWord: 'LACROSSE', label: 'LACROSSE PERFORMANCE',    motif: M.lacrosse },
  ice_hockey:        { accent: '#1E3A8A', accentDeep: '#14275C', coverWord: 'HOCKEY',   label: 'ICE HOCKEY PERFORMANCE',  motif: M.ice_hockey },
  rugby:             { accent: '#4D7C0F', accentDeep: '#38590B', coverWord: 'RUGBY',    label: 'RUGBY PERFORMANCE',       motif: M.rugby },
  distance_running:  { accent: '#E11D48', accentDeep: '#B01539', coverWord: 'DISTANCE', label: 'RUNNING PERFORMANCE',     motif: M.distance_running },
  track_sprints:     { accent: '#DB2777', accentDeep: '#A81A5B', coverWord: 'SPRINT',   label: 'TRACK PERFORMANCE',       motif: M.track_sprints },
  cycling:           { accent: '#CA8A04', accentDeep: '#9A6903', coverWord: 'CYCLE',    label: 'CYCLING PERFORMANCE',     motif: M.cycling },
  swimming:          { accent: '#10A0C4', accentDeep: '#0B7793', coverWord: 'SWIM',     label: 'SWIM PERFORMANCE',        motif: M.swimming },
  rowing:            { accent: '#2563EB', accentDeep: '#1A4BC0', coverWord: 'CREW',     label: 'ROWING PERFORMANCE',      motif: M.rowing },
  tennis:            { accent: '#65A30D', accentDeep: '#4A7A09', coverWord: 'TENNIS',   label: 'TENNIS PERFORMANCE',      motif: M.tennis },
  pickleball:        { accent: '#F59E0B', accentDeep: '#C47C08', coverWord: 'PICKLE',   label: 'PICKLEBALL PERFORMANCE',  motif: M.pickleball },
  badminton:         { accent: '#0EA5E9', accentDeep: '#0A7DB0', coverWord: 'SHUTTLE',  label: 'BADMINTON PERFORMANCE',   motif: M.badminton },
  table_tennis:      { accent: '#DC2626', accentDeep: '#B01D1D', coverWord: 'PADDLE',   label: 'TABLE TENNIS PERFORMANCE', motif: M.table_tennis },
  strength_training: { accent: '#3F3F46', accentDeep: '#27272A', coverWord: 'STRENGTH', label: 'STRENGTH PERFORMANCE',    motif: M.strength_training },
  powerlifting:      { accent: '#18181B', accentDeep: '#0A0A0C', coverWord: 'IRON',     label: 'POWERLIFTING',            motif: M.powerlifting },
  functional_fitness: { accent: '#0D9488', accentDeep: '#0A6E66', coverWord: 'ENGINE',  label: 'FUNCTIONAL FITNESS',      motif: M.functional_fitness },
  boxing:            { accent: '#B91C1C', accentDeep: '#8E1414', coverWord: 'BOXING',   label: 'BOXING PERFORMANCE',      motif: M.boxing },
  wrestling:         { accent: '#B45309', accentDeep: '#8A3F07', coverWord: 'WRESTLE',  label: 'WRESTLING PERFORMANCE',   motif: M.wrestling },
  martial_arts:      { accent: '#1F2937', accentDeep: '#111827', coverWord: 'MARTIAL',  label: 'MARTIAL ARTS',            motif: M.martial_arts },
  gymnastics:        { accent: '#7C3AED', accentDeep: '#5B27B0', coverWord: 'GYMNAST',  label: 'GYMNASTICS PERFORMANCE',  motif: M.gymnastics },
  rock_climbing:     { accent: '#57534E', accentDeep: '#3F3C38', coverWord: 'ASCENT',   label: 'CLIMBING PERFORMANCE',    motif: M.rock_climbing },
  general_athletic:  { accent: '#0D0D0E', accentDeep: '#000000', coverWord: 'ATHLETE',  label: 'ATHLETIC PERFORMANCE',    motif: M.general_athletic },
};

// Map Sporve's internal sport keys → theme keys (for the real-data wiring later).
const SPORT_KEY_TO_THEME = {
  basketball: 'basketball', soccer: 'soccer', football: 'football', baseball: 'baseball_softball',
  golf: 'golf', volleyball: 'volleyball', tennis: 'tennis', lacrosse: 'lacrosse',
  swimming: 'swimming', track: 'track_sprints',
};

const API = { SPORT_THEMES, SPORT_KEY_TO_THEME };
if (typeof module !== 'undefined' && module.exports) module.exports = API;
if (typeof window !== 'undefined') window.PlanPdfThemes = API;
