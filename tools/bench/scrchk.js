// Весь экран против эталона: фон по VNT (огонь 38, D0-D5 — любой кадр банка) + нарисованные спрайты (spr_rec +0, атрибуты +1..+4):
// враги (цвет не 6/11) — OR в 8000; Джо — по индексу cmap[цвет]: бит 2 -> 8000, 1 -> A000, 0 -> C000 (AND/OR), меньший номер сверху.
// node scrchk.js dir шагов [tp|r19]
const fs = require('fs'); process.chdir('/Users/boris/projects/monty-v06c');
const E = require('/Users/boris/projects/monty-v06c/tools/vec_emu');
const dir = process.argv[2] || 'build/native', N = +(process.argv[3] || 2000), MODE = process.argv[4] || '';
const sym = {}; for (const l of fs.readFileSync(dir + '/monty.sym', 'latin1').split('\n')) { const q = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const m = E.mk(dir + '/monty.bin'); const K = (r, b, d) => { if (d) m.keyboard.matrix[r] |= b; else m.keyboard.matrix[r] &= ~b; };
const ROOMS = []; for (let r = 0; r < 9; r++) for (let c = 8 - r; c <= 10 + r; c++) ROOMS.push([r, c]);
const SPRMAX = 6, REC = sym.spr_rec;
let steps = 0, fc = 0, checks = 0, bad = 0, skip = 0; const ex = [];
const keys = (s) => { K(7, 0x80, (s >= 20 && s < 30) || (s > 200 && s % 37 < 4)); const ph = s < 100 ? -1 : Math.floor((s - 100) / 70) % 4; K(0, 0x40, ph === 0); K(0, 0x10, ph === 2); K(0, 0x20, ph === 1 && s % 50 < 20); K(0, 0x80, ph === 3 && s % 50 < 20); };
const isFire = (t) => t === 0x38 || (t >= 0xD0 && t <= 0xD5);
function cellBytes(t, f) { const ds = m.rd(sym.dslot + t); let src = 0xE000 + 8 * t; if (f && ds !== 0xFF) src = sym.dstore + 24 * ds + 8 * (f - 1);
  const md = m.rd(sym.cmodes + m.rd(sym.VCOL + (t >> 3))); const o = [];
  for (let p = 0; p < 3; p++) { const mode = (md >> (4 - 2 * p)) & 3; for (let y = 0; y < 8; y++) { const pat = m.rd(src + y); o.push([0, pat, pat ^ 0xFF, 0xFF][mode]); } } return o; }
function check() {
  if (m.rd(sym.dl_n) || m.rd(sym.dl_ovf) || m.rd(sym.vdirty) || m.rd(sym.crit_pend) || m.rd(sym.lv_dirty)) { skip++; return; }
  if (!(m.rd(sym.vregs + 1) & 0x40)) { skip++; return; }
  // фон: 3 плоскости x 256 x 256 (строки экрана 0..191 сверху: адрес 0xFF - y... как у клетки: 0xDF - 8r - y)
  const scr = [new Uint8Array(8192), new Uint8Array(8192), new Uint8Array(8192)], fire = new Uint8Array(768); const th = m.rd(sym.tile_hi);
  const ad = (c, y) => c * 256 + 0xDF - y;   // y = 0..191 сверху
  for (let r = 0; r < 24; r++) for (let c = 0; c < 32; c++) { const t = m.rd(sym.VNT + r * 32 + c); if (isFire(t) && m.rd(sym.dslot + t) !== 0xFF) fire[r * 32 + c] = 1;
    const b = cellBytes(t, th); for (let p = 0; p < 3; p++) for (let y = 0; y < 8; y++) scr[p][ad(c, 8 * r + y)] = b[p * 8 + y]; }
  // огонь: принимаем экран как есть, если он равен какому-то кадру
  for (let r = 0; r < 24; r++) for (let c = 0; c < 32; c++) if (fire[r * 32 + c]) { const t = m.rd(sym.VNT + r * 32 + c);
    for (let f = 0; f < 4; f++) { const b = cellBytes(t, f); let ok = true; for (let p = 0; p < 3 && ok; p++) for (let y = 0; y < 8; y++) if (m.rd(0x8000 + 0x2000 * p + ad(c, 8 * r + y)) !== b[p * 8 + y]) { ok = false; break; }
      if (ok) { for (let p = 0; p < 3; p++) for (let y = 0; y < 8; y++) scr[p][ad(c, 8 * r + y)] = b[p * 8 + y]; fire[r * 32 + c] = 0; break; } } }
  const under = new Uint8Array(768);
  for (let k = SPRMAX - 1; k >= 0; k--) { const a = REC + 16 * k; if (!m.rd(a)) continue;
    const Y = m.rd(a + 1), X = m.rd(a + 2), nm = m.rd(a + 3) & 0xFC, col = m.rd(a + 4) & 15; const ci = m.rd(sym.cmap + col);
    const hero = col === 6 || col === 11; const top = Y + 1;
    for (let yy = 0; yy < 16; yy++) { const y = top + yy; if (y >= 192) break;
      for (let half = 0; half < 2; half++) { const pb = m.rd(sym.VSPR + nm * 8 + half * 16 + yy);
        for (let bx = 0; bx < 8; bx++) { if (!(pb & (0x80 >> bx))) continue; const x = X + half * 8 + bx; if (x > 255) continue;
          const c = x >> 3, bit = 0x80 >> (x & 7), A = ad(c, y); under[(y >> 3) * 32 + c] = 1;
          if (!hero) scr[0][A] |= bit; else for (let p = 0; p < 3; p++) { if (!(ci & 4) && p === 0) continue; if ((ci >> (2 - p)) & 1) scr[p][A] |= bit; else scr[p][A] &= ~bit; } } } } }
  checks++; let nb = 0; for (let i = 0; i < 768; i++) if (fire[i]) under[i] = 0;
  for (let p = 0; p < 3; p++) for (let c = 0; c < 32; c++) for (let y = 0; y < 192; y++) { const cell = (y >> 3) * 32 + c; if (fire[cell] && !under[cell]) continue;
    const A = ad(c, y), got = m.rd(0x8000 + 0x2000 * p + A); if (got !== scr[p][A]) { nb++; if (ex.length < 8) ex.push(`шаг ${steps} пл ${p} кл ${y >> 3},${c} стр ${y & 7}: ${got.toString(16)} != ${scr[p][A].toString(16)}${fire[cell] ? ' (огонь под спрайтом)' : ''}${under[cell] ? ' (под спрайтом)' : ''}`); } }
  if (nb) bad++;
}
m.onInstr = (pc) => {
  if (MODE === 'r19' && pc === sym.L_8DA2 && steps > 60) { const c = m.cpu; c.pc = m.rd(c.sp) | (m.rd(c.sp + 1) << 8); c.sp += 2; return; }
  if (pc === sym.L_A5D1) { steps++; keys(steps); m.wr(0x7049, 6); check();
    if (MODE === 'r19') { m.wr(0x707C, m.rd(0x7300)); if (steps === 50) { m.wr(0x705F, m.rd(0x705F) & ~4); m.wr(0x71A7, 1); m.wr(0x71A8, 9); m.wr(0x7079, 9); } }
    if (MODE === 'tp' && steps >= 300 && steps % 60 === 0) { const [r, c] = ROOMS[(steps / 60 - 5) % ROOMS.length]; m.wr(0x71A7, r); m.wr(0x71A8, c); m.wr(0x7079, 9); } } };
while (steps < N) { if (fc === 10) K(2, 2, 1); if (fc === 100) K(2, 2, 0); fc++; m.frame(); }
console.log(dir, MODE, 'проверок', checks, 'пропущено', skip, 'неверных экранов', bad); console.log(ex.join('\n'));
