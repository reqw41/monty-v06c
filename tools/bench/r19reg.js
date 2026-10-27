// такты по участкам кода (вложенные вызовы — к участку вызывающего, пока SP глубже входа): REG="имя:от:до,..."
const fs = require('fs'); process.chdir('/Users/boris/projects/monty-v06c');
const E = require('/Users/boris/projects/monty-v06c/tools/vec_emu'); const B = process.env.B || 'build/native';
const sym = {}; for (const l of fs.readFileSync(B + '/monty.sym', 'latin1').split('\n')) { const q = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const R = process.env.REG.split(',').map((x) => { const [n, a, b] = x.split(':'); return { n, a: sym[a], b: sym[b], c: 0, sp: -1 }; });
const m = E.mk(B + '/monty.bin'); let steps = 0, fc = 0, cur = null;
m.onInstr = (pc) => { const v = m.cpu.vcycles || 0; if (cur) { if (m.cpu.sp > cur.sp || (m.cpu.sp === cur.sp && (pc < cur.a || pc >= cur.b))) cur = null; else if (steps > 200) cur.c += v; }
  if (!cur) for (const r of R) if (pc >= r.a && pc < r.b) { cur = r; r.sp = m.cpu.sp; break; }
  if (pc === sym.L_8DA2 && steps > 60) { const c = m.cpu; c.pc = m.rd(c.sp) | (m.rd(c.sp + 1) << 8); c.sp += 2; return; }
  if (pc === sym.L_A5D1) { steps++; m.wr(0x7049, 6); m.wr(0x707C, m.rd(0x7300)); if (steps === 50) { m.wr(0x705F, m.rd(0x705F) & ~4); m.wr(0x71A7, 1); m.wr(0x71A8, 9); m.wr(0x7079, 9); } } };
let nd = 0; const od = m.onInstr; m.onInstr = (pc) => { if (pc === sym.disp_prep && steps > 200) nd++; od(pc); };
while (steps < 500) { if (fc === 10) m.keyboard.matrix[2] |= 2; if (fc === 100) m.keyboard.matrix[2] &= ~2; fc++; m.frame(); }
for (const r of R) console.log(r.n, 'на вывод', Math.round(r.c / nd));
