const fs = require('fs'); process.chdir(require('path').resolve(__dirname, '../..'));
const E = require('../vec_emu'); const B = process.env.B || 'build/native';
const sym = {}; for (const l of fs.readFileSync(B + '/monty.sym', 'latin1').split('\n')) { const q = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const m = E.mk(B + '/monty.bin'); let steps = 0, fc = 0; const W = (process.env.W || 'force_live_t,disp_prep,crit,spr_plan,spr_prep,crit_plan,draw_list,ex_build,fl_under,dc_draw,kb_scan,pal_load_isr').split(','); const A = {}, N = {}; const stk = [];
let cyc = 0, lastc = 0; const tot = () => cyc;
m.onInstr = (pc) => { cyc += m.cpu.vcycles || 0; const v = cyc;
  while (stk.length && m.cpu.sp > stk[stk.length - 1].sp) { const e = stk.pop(); if (steps > 200) { A[e.n] = (A[e.n] || 0) + (v - e.c); N[e.n] = (N[e.n] || 0) + 1; } }
  for (const w of W) if (pc === sym[w]) stk.push({ n: w, sp: m.cpu.sp, c: v });
  if (pc === sym.L_8DA2 && steps > 60) { const c = m.cpu; c.pc = m.rd(c.sp) | (m.rd(c.sp + 1) << 8); c.sp += 2; return; }
  if (pc === sym.L_A5D1) { steps++; m.wr(0x7049, 6); m.wr(0x707C, m.rd(0x7300));
    if (steps === 50) { m.wr(0x705F, m.rd(0x705F) & ~4); m.wr(0x71A7, 1); m.wr(0x71A8, 9); m.wr(0x7079, 9); } } };
let f0; while (steps < 500) { if (steps === 201 && f0 === undefined) f0 = m.frames; if (fc === 10) m.keyboard.matrix[2] |= 2; if (fc === 100) m.keyboard.matrix[2] &= ~2; fc++; m.frame(); }
console.log('кадров/шаг', ((m.frames - f0) / 299).toFixed(2)); for (const w of W) if (A[w]) console.log(w, 'вызовов', N[w], 'тактов на вызов', Math.round(A[w] / N[w]), 'на шаг', Math.round(A[w] / 299));
