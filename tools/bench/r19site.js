// такты вызовов процедур по местам вызова: P="cpir,nt_get"; комната 1,9 (R19=1) или обычная игра
const fs = require('fs'); process.chdir('/Users/boris/projects/monty-v06c');
const E = require('/Users/boris/projects/monty-v06c/tools/vec_emu'); const B = process.env.B || 'build/native';
const sym = {}; for (const l of fs.readFileSync(B + '/monty.sym', 'latin1').split('\n')) { const q = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const labs = Object.entries(sym).filter(([k, v]) => v >= 0x38 && v < 0x7000 && !k.startsWith('C_')).sort((a, b) => a[1] - b[1]);
const near = (a) => { let r = '?'; for (const [k, v] of labs) { if (v > a) break; r = k; } return r; };
const P = new Set(process.env.P.split(',').map((n) => sym[n])); const m = E.mk(B + '/monty.bin'); let steps = 0, fc = 0, cur = null; const A = {}, N = {};
let isp = -1; m.onInstr = (pc) => { const v = m.cpu.vcycles || 0; if (isp >= 0) { if (m.cpu.sp > isp) isp = -1; else return; } if (pc === 0x38 || pc === sym.isr) { isp = m.cpu.sp; return; } if (cur) { if (m.cpu.sp > cur.sp) cur = null; else if (steps > 200) A[cur.k] = (A[cur.k] || 0) + v; }
  if (!cur && P.has(pc)) { const ra = m.rd(m.cpu.sp) | (m.rd(m.cpu.sp + 1) << 8); cur = { sp: m.cpu.sp, k: labs.find(() => 1) && (Object.keys(sym).find((n) => sym[n] === pc) + ' <- ' + near(ra)) }; if (steps > 200) N[cur.k] = (N[cur.k] || 0) + 1; }
  if (process.env.R19 && pc === sym.L_8DA2 && steps > 60) { const c = m.cpu; c.pc = m.rd(c.sp) | (m.rd(c.sp + 1) << 8); c.sp += 2; return; }
  if (pc === sym.L_A5D1) { steps++; m.wr(0x7049, 6); if (process.env.R19) { m.wr(0x707C, m.rd(0x7300)); if (steps === 50) { m.wr(0x705F, m.rd(0x705F) & ~4); m.wr(0x71A7, 1); m.wr(0x71A8, 9); m.wr(0x7079, 9); } } } };
while (steps < 500) { if (fc === 10) m.keyboard.matrix[2] |= 2; if (fc === 100) m.keyboard.matrix[2] &= ~2; fc++; m.frame(); }
for (const [k, v] of Object.entries(A).sort((a, b) => b[1] - a[1]).slice(0, 25)) console.log(k, 'вызовов/шаг', (N[k] / 299).toFixed(2), 'тактов/шаг', Math.round(v / 299));
