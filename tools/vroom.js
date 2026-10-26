#!/usr/bin/env node
// Стенд этапа 1: программа просмотра (build/vec/viewer.bin) в vector06js без окна рисует каждую комнату.
// -> build/vec/rooms/L<у>_<комната>.bin: NT 768 | cmap 16 | pal 16 | индекс Вектора 0..7 по пикселям 256x192
//   node tools/vroom.js [уровни, по умолчанию 1,2,3]
'use strict';
const fs = require('fs');
const E = require('./vec_emu');
const sym = {};
for (const l of fs.readFileSync('build/vec/viewer.sym', 'latin1').split('\n')) {
  const m = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (m) sym[m[1]] = parseInt(m[2], 16);
}
const ROW = [-8, -4, 2, 10, 20, 32, 46, 62, 80];
const levels = (process.argv[2] || '1,2,3').split(',').map(Number);
fs.mkdirSync('build/vec/rooms', { recursive: true });
const m = E.mk('build/vec/viewer.bin');
for (let f = 0; f < 30; f++) m.frame();
let maxf = 0;
for (const lv of levels) for (let r = 0; r < 9; r++) for (let c = 8 - r; c <= 10 + r; c++) {
  const i = ROW[r] + c;
  m.wr(sym.req_lv, lv); m.wr(sym.req_row, r); m.wr(sym.done, 0); m.wr(sym.req_room, i);
  let f = 0;
  while (!m.rd(sym.done)) { m.frame(); if (++f > 600) throw new Error(`комната ${i}: нет done`); }
  maxf = Math.max(maxf, f);
  for (let k = 0; k < 4; k++) m.frame();
  const out = Buffer.alloc(768 + 32 + 256 * 192);
  for (let a = 0; a < 768; a++) out[a] = m.rd(sym.NT + a);
  for (let a = 0; a < 16; a++) { out[768 + a] = m.rd(sym.cmap + a); out[784 + a] = m.rd(sym.pal + a); }
  const ep = m.palette();
  for (let a = 0; a < 16; a++) if (ep[a] !== undefined && false) {}
  for (let y = 0; y < 192; y++) for (let x = 0; x < 256; x++) {
    const lo = 0xDF - y, col = x >> 3, bit = 7 - (x & 7);
    const b2 = (m.rd(0x8000 + col * 256 + lo) >> bit) & 1, b1 = (m.rd(0xA000 + col * 256 + lo) >> bit) & 1,
          b0 = (m.rd(0xC000 + col * 256 + lo) >> bit) & 1;
    out[800 + y * 256 + x] = b2 << 2 | b1 << 1 | b0;
  }
  fs.writeFileSync(`build/vec/rooms/L${lv}_${i}.bin`, out);
}
console.log('комнат', levels.length * 99, 'макс. кадров на комнату', maxf);
