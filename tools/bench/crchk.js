const fs = require('fs'); process.chdir('/Users/boris/projects/monty-v06c');
const E = require('/Users/boris/projects/monty-v06c/tools/vec_emu');
const sym = {}; for (const l of fs.readFileSync('build/native/monty.sym', 'latin1').split('\n')) { const q = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const m = E.mk('build/native/monty.bin'); const K = (r, b, d) => { if (d) m.keyboard.matrix[r] |= b; else m.keyboard.matrix[r] &= ~b; };
const ROOMS = []; for (let r = 0; r < 9; r++) for (let c = 8 - r; c <= 10 + r; c++) ROOMS.push([r, c]);
let ok = 0, bad = 0, steps = 0, fc = 0, multi = 0; const ex = [];
const keys = (s) => { K(7, 0x80, s > 200 && s % 37 < 4); const ph = s < 100 ? -1 : Math.floor((s - 100) / 70) % 3; K(0, 0x40, ph === 0); K(0, 0x10, ph === 1); };
m.onInstr = (pc) => {
  if (pc === sym.crit) {
    const got = []; for (let a = sym.cr_list; m.rd(a); a += 2) got.push(m.rd(a) + ':' + m.rd(a + 1));
    const R = (k, i) => m.rd(sym.spr_rec + 16 * k + i), U = (k) => [0, 1, 2, 3].map((i) => m.rd(sym.ubr + 4 * k + i));
    const mk = [...Array(6).keys()].filter((k) => R(k, 13)); const g = {}; for (const k of mk) g[k] = k;
    const hit = (a, b) => b[0] <= a[1] && b[1] >= a[0] && b[2] <= a[3] && b[3] >= a[2];
    let ch = true; while (ch) { ch = false; for (const i of mk) for (const j of mk) if (i < j && g[i] !== g[j] && hit(U(i), U(j))) { const gj = g[j]; for (const k of mk) if (g[k] === gj) g[k] = g[i]; ch = true; } }
    const exp = []; for (;;) { let y = 0xFF, gg = -1; for (const k of mk) if (g[k] >= 0 && U(k)[0] < y) { y = U(k)[0]; gg = g[k]; } if (gg < 0) break;
      const mem = mk.filter((k) => g[k] === gg); if (mem.length > 1) multi++;
      for (const k of mem) if (R(k, 0)) exp.push('1:' + k); for (const k of mem) if (R(k, 0)) exp.push('2:' + k); for (const k of [...mem].reverse()) exp.push('3:' + k); for (const k of mem) g[k] = -1; }
    if (got.join(' ') === exp.join(' ')) ok++; else { bad++; if (ex.length < 5) ex.push(`шаг ${steps}: ${got.join(' ')} | ждали ${exp.join(' ')}`); } }
  if (pc === sym.L_A5D1) { steps++; keys(steps); m.wr(0x7049, 6); if (steps >= 300 && steps % 150 === 0) { const [r, c] = ROOMS[(steps / 150 * 7) % ROOMS.length]; m.wr(0x71A7, r); m.wr(0x71A8, c); m.wr(0x7079, 9); } } };
while (steps < 4000) { if (fc === 10) K(2, 2, 1); if (fc === 100) K(2, 2, 0); fc++; m.frame(); }
console.log('списков crit верно', ok, 'неверно', bad, '(групп из нескольких:', multi + ')'); console.log(ex.join('\n'));
