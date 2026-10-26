// Модель: комнаты — номер, указатели описания, таблицы, флаги взятых объектов.
'use strict';
const { rd, wr } = require('./core');

module.exports = {
  // A4B5 ROOM_INDEX: A := ROW_BASE[71A7] + 71A8 (C := ROW_BASE[ряд], B := 0, HL := A4C5 + ряд)
  A4B5(m, r) {
    const row = rd(m, 0x71a7);
    r.hl = 0xa4c5 + row; r.b = 0; r.c = rd(m, r.hl);
    r.a = (rd(m, 0x71a8) + r.c) & 0xff;
  },
  // A540: A := (HL + A), HL += A (BC сохраняется)
  A540(m, r) {
    r.hl = (r.hl + r.a) & 0xffff; r.a = rd(m, r.hl);
  },
  // A4CE ROOM_PTRS: 71A5 := A; 7190..7193 := 4 байта из 9477 + 2A (HL, DE, BC — как после LDIR)
  A4CE(m, r) {
    wr(m, 0x71a5, r.a);
    const src = 0x9477 + ((r.a << 1) & 0xff);
    for (let i = 0; i < 4; i++) wr(m, 0x7190 + i, rd(m, src + i));
    r.a = (r.a << 1) & 0xff; r.c = 0; r.b = 0; r.hl = src + 4; r.de = 0x7194;
  },
  // A514 OBJ_TAKEN: бит n = 71A2 (счётчик объектов, +1) в байте 70C0 + 71A1 + n/8; CY = взят
  A514(m, r) {
    const n = rd(m, 0x71a2);
    let c = rd(m, 0x71a1) + (n >> 3), d = 1 << (n & 7);
    wr(m, 0x71a2, n + 1);
    r.c = c & 0xff; r.b = 0; r.d = d; r.hl = 0x70c0 + r.c;
    const taken = (d & rd(m, r.hl)) !== 0;
    r.a = d & rd(m, r.hl); r.cf = taken; r.zf = !taken;
  },
};
