const fs = require('fs'); process.chdir(require('path').resolve(__dirname, '../..'));
const E = require('../vec_emu'); const B = process.env.B || 'build/native'; const P = process.env.P || 'force_live_t';
const sym = {}; for (const l of fs.readFileSync(B + '/monty.sym', 'latin1').split('\n')) { const q = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const labs = Object.entries(sym).filter(([k, v]) => v >= 0x38 && v < 0x7000 && !k.startsWith('C_')).sort((a, b) => a[1] - b[1]);
const near = new Array(0x7000); { let j = 0; for (let a = 0; a < 0x7000; a++) { while (j + 1 < labs.length && labs[j + 1][1] <= a) j++; near[a] = labs[j] ? labs[j][0] : '?'; } }
const m = E.mk(B + '/monty.bin'); let steps = 0, fc = 0, inP = 0, psp = 0, last = 0, n = 0; const T = {};
m.onInstr = (pc) => { const v = m.cpu.vcycles || 0;
  if (inP && last < 0x7000) T[near[last]] = (T[near[last]] || 0) + v;
  if (inP && m.cpu.sp > psp) inP = 0;
  if (pc === sym[P] && steps > 200 && !inP) { inP = 1; psp = m.cpu.sp; n++; }
  last = pc;
  if (pc === sym.L_8DA2 && steps > 60) { const c = m.cpu; c.pc = m.rd(c.sp) | (m.rd(c.sp + 1) << 8); c.sp += 2; return; }
  if (pc === sym.L_A5D1) { steps++; m.wr(0x7049, 6); m.wr(0x707C, m.rd(0x7300));
    if (steps === 50) { m.wr(0x705F, m.rd(0x705F) & ~4); m.wr(0x71A7, 1); m.wr(0x71A8, 9); m.wr(0x7079, 9); } } };
while (steps < 500) { if (fc === 10) m.keyboard.matrix[2] |= 2; if (fc === 100) m.keyboard.matrix[2] &= ~2; fc++; m.frame(); }
const tot = Object.values(T).reduce((a, b) => a + b, 0); console.log(P, 'вызовов', n, 'тактов на вызов', Math.round(tot / n));
console.log(Object.entries(T).sort((a, b) => b[1] - a[1]).slice(0, 25).map(([k, v]) => k + ' ' + Math.round(v / n)).join('  '));
