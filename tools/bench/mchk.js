const fs = require('fs'); process.chdir('/Users/boris/projects/monty-v06c');
const E = require('/Users/boris/projects/monty-v06c/tools/vec_emu');
const sym = {}; for (const l of fs.readFileSync('build/native/monty.sym', 'latin1').split('\n')) { const q = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const m = E.mk('build/native/monty.bin'); const K = (r, b, d) => { if (d) m.keyboard.matrix[r] |= b; else m.keyboard.matrix[r] &= ~b; };
const ROOMS = []; for (let r = 0; r < 9; r++) for (let c = 8 - r; c <= 10 + r; c++) ROOMS.push([r, c]);
let pend = null, ok = 0, bad = 0, steps = 0, fc = 0; const ex = [];
const keys = (s) => { K(7, 0x80, s > 200 && s % 37 < 4); const ph = s < 100 ? -1 : Math.floor((s - 100) / 70) % 3; K(0, 0x40, ph === 0); K(0, 0x10, ph === 1); };
m.onInstr = (pc) => {
  if (pend && m.cpu.sp > pend.sp) { const p = pend; pend = null; const SM = 0xD0; const base = (sym.SPR_SLOTS >> 8) + p.k;
    for (let y = 0; y < p.rows; y++) { const b0 = m.rd(0x7400 + 8 * p.name + p.off + y), b1 = m.rd(0x7400 + 8 * p.name + p.off + y + 16);
      const w = ((b0 << 16) | (b1 << 8)) >>> p.s; const want = [(w >> 16) & 255, (w >> 8) & 255, w & 255];
      for (let j = 0; j < 3; j++) { if (p.s === 0 && j === 2) continue; const got = m.rd(base * 256 + SM + 16 * j + y); if (got === want[j]) ok++; else { bad++; if (ex.length < 5) ex.push(`k${p.k} имя ${p.name} s${p.s} стр ${y} ст ${j}: ${got.toString(16)} != ${want[j].toString(16)}`); } } } }
  if (pc === sym.spr_masks && !pend) pend = { sp: m.cpu.sp, k: m.rd(sym.sp_k), name: m.rd(sym.sp_name), s: m.rd(sym.sp_x) & 7, off: m.rd(sym.sm_off), rows: m.rd(sym.st_rows) };
  if (pc === sym.L_A5D1) { steps++; keys(steps); m.wr(0x7049, 6); if (steps >= 300 && steps % 150 === 0) { const [r, c] = ROOMS[(steps / 150 * 7) % ROOMS.length]; m.wr(0x71A7, r); m.wr(0x71A8, c); m.wr(0x7079, 9); } } };
while (steps < 3000) { if (fc === 10) K(2, 2, 1); if (fc === 100) K(2, 2, 0); fc++; m.frame(); }
console.log('байт масок верно', ok, 'неверно', bad); console.log(ex.join('\n'));
