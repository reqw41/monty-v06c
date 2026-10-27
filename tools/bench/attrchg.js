const fs = require('fs'); process.chdir('/Users/boris/projects/monty-v06c');
const E = require('/Users/boris/projects/monty-v06c/tools/vec_emu'); const B = 'build/native'; const R19 = process.argv[2] === 'r19';
const sym = {}; for (const l of fs.readFileSync(B + '/monty.sym', 'latin1').split('\n')) { const q = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const m = E.mk(B + '/monty.bin'); const K = (r, b, d) => { if (d) m.keyboard.matrix[r] |= b; else m.keyboard.matrix[r] &= ~b; };
let steps = 0, fc = 0, prev = null, n = 0; const C = {};
const keys = (s) => { if (R19) return; K(7, 0x80, (s >= 20 && s < 30) || (s > 200 && s % 37 < 4)); const ph = s < 100 ? -1 : Math.floor((s - 100) / 70) % 3; K(0, 0x40, ph === 0); K(0, 0x10, ph === 1); };
m.onInstr = (pc) => {
  if (R19 && pc === sym.L_8DA2 && steps > 60) { const c = m.cpu; c.pc = m.rd(c.sp) | (m.rd(c.sp + 1) << 8); c.sp += 2; return; }
  if (pc === sym.L_A5D1) { steps++; keys(steps); m.wr(0x7049, 6);
    if (R19) { m.wr(0x707C, m.rd(0x7300)); if (steps === 50) { m.wr(0x705F, m.rd(0x705F) & ~4); m.wr(0x71A7, 1); m.wr(0x71A8, 9); m.wr(0x7079, 9); } }
    const cur = []; for (let k = 0; k < 6; k++) { const a = 0x7300 + 4 * k; cur.push([m.rd(a), m.rd(a + 1), m.rd(a + 2) & 0xFC, m.rd(a + 3) & 15]); }
    if (steps > 200 && prev) { n++; cur.forEach((c, k) => { const p = prev[k]; if (c[0] >= 0xC0 || c[3] === 0) return; const r = (C[k] = C[k] || { vis: 0, pos: 0, name: 0, any: 0, onlyname: 0, nm: new Set() }); r.vis++; r.nm.add(c[2]);
      const mp = c[0] !== p[0] || c[1] !== p[1], mn = c[2] !== p[2]; if (mp) r.pos++; if (mn) r.name++; if (mp || mn) r.any++; if (mn && !mp) r.onlyname++; }); }
    prev = cur; } };
while (steps < 2200) { if (fc === 10) K(2, 2, 1); if (fc === 100) K(2, 2, 0); fc++; m.frame(); }
console.log(R19 ? 'комната 1,9 (Джо стоит)' : 'обычная игра (ходьба)', 'шагов', n);
for (const k in C) { const r = C[k]; console.log(`спрайт ${k}: виден ${r.vis} шагов; место менялось ${(100 * r.pos / r.vis).toFixed(0)}%, кадр ${(100 * r.name / r.vis).toFixed(0)}%, хоть что-то ${(100 * r.any / r.vis).toFixed(0)}% (раз в ${(r.vis / Math.max(1, r.any)).toFixed(1)} шага), кадров всего ${r.nm.size}`); }
