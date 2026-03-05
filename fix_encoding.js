const fs = require('fs');

// Mojibake reversal: UTF-8 bytes of each special char were decoded as Windows-1252,
// then stored as UTF-8. Map confirmed via hex inspection of the file.
//
// Pattern: each garbled char = the W1252 interpretation of the original UTF-8 bytes.
// Confirmed: ₹ U+20B9 (E2 82 B9) → â[U+00E2] ‚[U+201A] ¹[U+00B9]
// Derived via W1252 byte table for the rest.
const replacements = [
  // ₹ (rupee) — confirmed by hex inspection
  ['\u00E2\u201A\u00B9', '\u20B9'],
  // — em dash  (E2 80 94 → â € ")
  ['\u00E2\u20AC\u201D', '\u2014'],
  // – en dash  (E2 80 93 → â € ")
  ['\u00E2\u20AC\u201C', '\u2013'],
  // … ellipsis (E2 80 A6 → â € ¦)
  ['\u00E2\u20AC\u00A6', '\u2026'],
  // − minus    (E2 88 92 → â ˆ ')
  ['\u00E2\u02C6\u2019', '\u2212'],
  // × multiply (C3 97 → Ã —)
  ['\u00C3\u2014', '\u00D7'],
  // • bullet   (E2 80 A2 → â € ¢)
  ['\u00E2\u20AC\u00A2', '\u2022'],
  // · middle dot (C2 B7 → Â ·) — drop the spurious Â
  ['\u00C2\u00B7', '\u00B7'],
  // ✓ check    (E2 9C 93 → â œ ")
  ['\u00E2\u0153\u201C', '\u2713'],
  // ⚠ warning  (E2 9A A0 → â š \u00A0)
  ['\u00E2\u0161\u00A0', '\u26A0'],
  // non-breaking space artefact (C2 A0 → Â \u00A0)
  ['\u00C2\u00A0', '\u00A0'],
];

const target = __dirname + '/web/app/orders/new/page.tsx';
let c = fs.readFileSync(target, 'utf8');
let total = 0;
for (const [bad, good] of replacements) {
  let n = 0;
  while (c.includes(bad)) { c = c.split(bad).join(good); n++; }
  if (n) console.log('  replaced', JSON.stringify(bad), '->', JSON.stringify(good), '('+n+'x)');
  total += n;
}
fs.writeFileSync(target, c, 'utf8');
console.log('Done. Total replacements:', total, '| Lines:', c.split('\n').length);
