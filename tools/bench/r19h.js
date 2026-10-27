const fs = require('fs'); process.chdir(require('path').resolve(__dirname, '../..'));
const E = require('../vec_emu'); const B = process.env.B || 'build/native';
const sym = {}; for (const l of fs.readFileSync(B + '/monty.sym', 'latin1').split('\n')) { const q = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const m = E.mk(B + '/monty.bin'); let steps = 0, fc = 0, idle = 0, tot = 0, last = 0, f0 = 0, isr = 0, inI = 0, isp = 0;
m.onInstr = (pc) => { const v = m.cpu.vcycles || 0; if (steps > 200) { tot += v; if (last >= sym.fw2 && last < sym.fw2 + 6) idle += v; if (inI) isr += v; }
  if (inI && m.cpu.sp > isp) inI = 0; if (pc === sym.isr && !inI) { inI = 1; isp = m.cpu.sp; } last = pc;
  if (pc === sym.L_8DA2 && steps > 60) { const c = m.cpu; c.pc = m.rd(c.sp) | (m.rd(c.sp + 1) << 8); c.sp += 2; return; }
  if (pc === sym.L_A5D1) { steps++; if (steps === 201) f0 = m.frames; m.wr(0x7049, 6); m.wr(0x707C, m.rd(0x7300));
    if (steps === 50) { m.wr(0x705F, m.rd(0x705F) & ~4); m.wr(0x71A7, 1); m.wr(0x71A8, 9); m.wr(0x7079, 9); } } };
while (steps < 600) { if (fc === 10) m.keyboard.matrix[2] |= 2; if (fc === 100) m.keyboard.matrix[2] &= ~2; fc++; m.frame(); }
const n = 399; console.log('кадров/шаг', ((m.frames - f0) / n).toFixed(3), 'тактов/шаг', Math.round(tot / n), 'простой', Math.round(idle / n), 'прерывание', Math.round(isr / n));
