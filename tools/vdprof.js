#!/usr/bin/env node
// Профиль внутри процедуры (по умолчанию display): доля команд по ближайшей метке платформы.
//   node tools/vdprof.js [процедура] [с кадра] [по кадр]
'use strict';
const fs = require('fs');
const E = require('./vec_emu');
const sym = {};
for (const l of fs.readFileSync('build/vec/monty.sym', 'latin1').split('\n')) {
  const m = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (m) sym[m[1]] = parseInt(m[2], 16);
}
const [P = 'display', A = '1000', B = '1500'] = process.argv.slice(2);
const inv = Object.entries(sym).filter(([k, v]) => v < 0x7000 && v >= 0x100 && !/^D_/.test(k)).sort((a, b) => a[1] - b[1]);
const near = new Array(0x7000).fill('?');
for (let i = 0, j = 0; i < 0x7000; i++) { while (j + 1 < inv.length && inv[j + 1][1] <= i) j++; if (inv[j] && inv[j][1] <= i) near[i] = inv[j][0]; }
const m = E.mk('build/vec/monty.bin'); const K = (r, b, d) => { if (d) m.keyboard.matrix[r] |= b; else m.keyboard.matrix[r] &= ~b; };
let on = false, depth = -1, n = 0, calls = 0; const h = new Map();
m.onInstr = (pc) => {
  if (!on) return;
  if (pc === sym[P] && depth < 0) { depth = m.cpu.sp; calls++; }
  if (depth >= 0) { if (m.cpu.sp > depth) { depth = -1; return; } if (pc < 0x100) return; n++; const k = near[pc]; h.set(k, (h.get(k) || 0) + 1); }
};
for (let f = 0; f < +B; f++) {
  if (f === 300) K(2, 2, 1); if (f === 320) K(2, 2, 0); if (f === 700) K(7, 0x80, 1); if (f === 710) K(7, 0x80, 0);
  if (f >= 1000 && f % 100 === 0) K(0, 0x40, f % 200 === 0); if (f === +A) on = true; m.frame();
}
console.log(`${P}: вызовов ${calls}, команд на вызов ${Math.round(n / calls)}`);
console.log([...h].sort((a, b) => b[1] - a[1]).slice(0, 22).map(([k, v]) => `${k} ${Math.round(v / calls)}`).join('\n'));
