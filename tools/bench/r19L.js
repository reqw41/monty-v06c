const fs = require('fs'); process.chdir('/Users/boris/projects/monty-v06c');
const E = require('/Users/boris/projects/monty-v06c/tools/vec_emu'); const B = process.env.B || 'build/native';
const sym = {}; for (const l of fs.readFileSync(B + '/monty.sym', 'latin1').split('\n')) { const q = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const labs = Object.entries(sym).filter(([k, v]) => v >= 0x38 && v < 0x7000 && !k.startsWith('C_')).sort((a, b) => a[1] - b[1]);
const near = new Array(0x7000); { let j = 0; for (let a = 0; a < 0x7000; a++) { while (j + 1 < labs.length && labs[j + 1][1] <= a) j++; near[a] = labs[j] ? labs[j][0] : '?'; } }
const m = E.mk(B + '/monty.bin'); let steps = 0, fc = 0, last = 0, ctx = 'L', dsp = 0, isp = 0; const T = { L: {}, D: {}, I: {} }, S = { L: 0, D: 0, I: 0 };
m.onInstr = (pc) => { const v = m.cpu.vcycles || 0;
  if (steps > 200 && last < 0x7000) { T[ctx][near[last]] = (T[ctx][near[last]] || 0) + v; S[ctx] += v; }
  if (ctx === 'I' && m.cpu.sp > isp) ctx = dsp ? 'D' : 'L';
  if (ctx === 'D' && pc === sym.fw2) { ctx = 'L'; dsp = 0; }
  if (pc === sym.disp_prep && ctx === 'L') { ctx = 'D'; dsp = 1; }
  if (pc === sym.isr && ctx !== 'I') { ctx = 'I'; isp = m.cpu.sp; }
  last = pc;
  if (pc === sym.L_8DA2 && steps > 60) { const c = m.cpu; c.pc = m.rd(c.sp) | (m.rd(c.sp + 1) << 8); c.sp += 2; return; }
  if (pc === sym.L_A5D1) { steps++; m.wr(0x7049, 6); m.wr(0x707C, m.rd(0x7300)); if (steps === 50) { m.wr(0x705F, m.rd(0x705F) & ~4); m.wr(0x71A7, 1); m.wr(0x71A8, 9); m.wr(0x7079, 9); } } };
while (steps < 600) { if (fc === 10) m.keyboard.matrix[2] |= 2; if (fc === 100) m.keyboard.matrix[2] &= ~2; fc++; m.frame(); }
const n = 399; for (const c of ['L', 'D', 'I']) { console.log(c, Math.round(S[c] / n), Object.entries(T[c]).sort((a, b) => b[1] - a[1]).slice(0, 22).map(([k, v]) => k + ' ' + Math.round(v / n)).join('  ')); }
