const fs = require('fs'); process.chdir('/Users/boris/projects/monty-v06c');
const E = require('/Users/boris/projects/monty-v06c/tools/vec_emu');
const dir = process.argv[2] || 'build/native';
const sym = {}; for (const l of fs.readFileSync(dir + '/monty.sym', 'latin1').split('\n')) { const q = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const m = E.mk(dir + '/monty.bin'); const K = (r, b, d) => { if (d) m.keyboard.matrix[r] |= b; else m.keyboard.matrix[r] &= ~b; };
const ROOMS = []; for (let r = 0; r < 9; r++) for (let c = 8 - r; c <= 10 + r; c++) ROOMS.push([r, c]);
let ok = 0, bad = 0, steps = 0, fc = 0, spr = 0; const ex = [];
const keys = (s) => { K(7, 0x80, s > 200 && s % 37 < 4); const ph = s < 100 ? -1 : Math.floor((s - 100) / 70) % 3; K(0, 0x40, ph === 0); K(0, 0x10, ph === 1); };
m.onInstr = (pc) => {
  if (pc === sym.L_A5D1) { steps++;
    if (steps % 5 === 0 && !m.rd(sym.crit_pend)) for (let k = 0; k < 6; k++) { const a = sym.spr_rec + 16 * k; if (!m.rd(a) || m.rd(a + 14) !== 2) continue; spr++;
      const Y = m.rd(a + 1) + 1, X = m.rd(a + 2), nm = m.rd(a + 3) & 0xFC;
      for (let r = 0; r < 16 && Y + r < 192; r++) { const b0 = m.rd(0x7400 + 8 * nm + r), b1 = m.rd(0x7400 + 8 * nm + r + 16); const wv = ((b0 << 16) | (b1 << 8)) >>> (X & 7);
        for (let j = 0; j < 3; j++) { const col = (X >> 3) + j; if (col > 31) continue; const want = (wv >> (16 - 8 * j)) & 255; const got = m.rd(0x8000 + col * 256 + 0xDF - (Y + r));
          if ((got & want) === want) ok++; else { bad++; if (ex.length < 5) ex.push(`шаг ${steps} k${k} имя ${nm.toString(16)} X ${X} стр ${r} ст ${j}: ${got.toString(16)} & ${want.toString(16)}`); } } } }
    keys(steps); m.wr(0x7049, 6); if (steps >= 300 && steps % 150 === 0) { const [r, c] = ROOMS[(steps / 150 * 7) % ROOMS.length]; m.wr(0x71A7, r); m.wr(0x71A8, c); m.wr(0x7079, 9); } } };
while (steps < 4000) { if (fc === 10) K(2, 2, 1); if (fc === 100) K(2, 2, 0); fc++; m.frame(); }
console.log(dir, 'врагов проверено', spr, 'байт верно', ok, 'неверно', bad); console.log(ex.join('\n'));
