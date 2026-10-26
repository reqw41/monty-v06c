// Модель: процедуры игры поверх VRAM — вложенность (A8B7/A8C3), PUT/FILL с ней (AE2E, AE25), прерывание VDP
// (AE77/AE83), блок клеток (AEA7, AA96), координаты -> клетка (AFC8, AFE3), тайлы под объектом (916C, 9159).
'use strict';
const { rd, wr, rd16, wr16 } = require('./core');
const V = require('./vdp');

const M = module.exports = {
  // A8B7: 705F |= 2, 70AF += 1 (регистры сохраняются)
  A8B7(m, r) { wr(m, 0x705f, rd(m, 0x705f) | 2); wr(m, 0x70af, rd(m, 0x70af) + 1); },
  // A8C3: 70AF -= 1; при 0 — 705F &= ~2 (AF, HL сохраняются)
  A8C3(m, r) { const v = (rd(m, 0x70af) - 1) & 0xff; wr(m, 0x70af, v); if (!v) wr(m, 0x705f, rd(m, 0x705f) & ~2); },
  // AE2E: PUT_VRAM внутри вложенности
  AE2E(m, r) { M.A8B7(m, r); V['1FBE'](m, r); M.A8C3(m, r); },
  AE34(m, r) { M.A8C3(m, r); },
  // AE25: FILL_VRAM внутри вложенности
  AE25(m, r) { M.A8B7(m, r); V['1F82'](m, r); M.A8C3(m, r); },
  // AE77: прерывание VDP выкл. (70B3 += 1, R1 := 82)
  AE77(m, r) { M.A8B7(m, r); wr(m, 0x70b3, rd(m, 0x70b3) + 1); r.hl = 0x70b3; r.bc = 0x0182; V['1FD9'](m, r); },
  // AE83: 70B3 -= 1; при 0 — прерывание VDP вкл. (R1 := E2)
  AE83(m, r) {
    M.A8C3(m, r); r.hl = 0x70b3; const v = (rd(m, 0x70b3) - 1) & 0xff; wr(m, 0x70b3, v); r.a = v;
    if (v) { r.zf = 0; return; }
    r.bc = 0x01e2; V['1FD9'](m, r);
  },
  // AEA7 PUT_BLOCK: HL = источник, DE = клетка, B строк по C тайлов; 7000: бит 4 — чтение (GET), бит 2 —
  // шаг строки 32 (иначе C), бит 3 — источник +1 и клетка -2 на строку (при записи)
  AEA7(m, r) {
    const sv = { ix: r.ix, bc: r.bc, hl: r.hl, de: r.de };
    M.A8B7(m, r);
    r.iy = r.c;
    let rows = r.b;
    do {
      const pbc = (rows << 8) & 0xff00, phl = r.hl, pde = r.de, piy = r.iy;
      r.a = 2;
      if (rd(m, 0x7000) & 0x10) V['1FBB'](m, r); else M.AE2E(m, r);
      let bc = piy; r.de = pde;
      const f = rd(m, 0x7000); r.a = f;
      if (f & 4) bc = 0x20;
      r.de = (r.de + bc) & 0xffff;
      r.iy = piy;
      if (!(f & 0x10)) { r.hl = phl; if (f & 8) { r.hl = (r.hl + 1) & 0xffff; r.de = (r.de - 2) & 0xffff; } }
      r.bc = pbc; rows = (rows - 1) & 0xff; r.b = rows;
    } while (rows);
    r.de = sv.de; r.hl = sv.hl; r.bc = sv.bc; r.ix = sv.ix;
    M.A8C3(m, r);
  },
  // AA96: AEA7 с шагом строки 32 (7000 бит 2)
  AA96(m, r) { wr(m, 0x7000, rd(m, 0x7000) | 4); M.AEA7(m, r); wr(m, 0x7000, rd(m, 0x7000) & ~4); },
  // AFC8: A := ceil(A / 8) & 1F (H бит 1 — были младшие биты)
  AFC8(m, r) {
    const low = r.a & 7; r.a = (r.a >> 3) & 0x1f; r.h = low ? r.h | 2 : r.h & ~2;
    if (low) r.a = (r.a + 1) & 0xff;
  },
  // AFE3: A = Y, B = X (в точках) -> HL = 32 * (ceil(Y / 8) - 1) + ceil(X / 8); BC = (0, столбец), DE = 20h
  AFE3(m, r) {
    M.AFC8(m, r); r.c = r.a; r.a = r.b; M.AFC8(m, r); r.a &= 0x1f; r.b = 0;
    let row = r.a, hl = 0;
    for (;;) { row = (row - 1) & 0xff; if (!row) break; hl = (hl + 0x20) & 0xffff; }
    r.hl = (hl + r.bc) & 0xffff; r.de = 0x20; r.a = 0;
  },
  // 916C: тайлы 3x2 вокруг (7084 + B, 7085 - 1 + C) -> (HL); 71B0 := клетка - 33
  '916C'(m, r) {
    const dst = r.hl;
    r.b = (rd(m, 0x7084) + r.b) & 0xff;
    r.a = (rd(m, 0x7085) + 0xff + r.c) & 0xff;
    M.AFE3(m, r);
    r.hl = (r.hl + 0xffdf) & 0xffff; r.de = r.hl; wr16(m, 0x71b0, r.de);
    wr(m, 0x7000, rd(m, 0x7000) | 0x14);
    r.hl = dst; r.bc = 0x0203; M.AEA7(m, r);
    r.hl = 0x7000; wr(m, 0x7000, rd(m, 0x7000) & ~0x14);
  },
  // 9159: 7084, 7085 := (HL), (HL+1); тайлы под ним в 7057
  '9159'(m, r) {
    wr(m, 0x7084, rd(m, r.hl)); r.hl = (r.hl + 1) & 0xffff; r.a = rd(m, r.hl); wr(m, 0x7085, r.a);
    r.bc = 0x1202; r.hl = 0x7057; M['916C'](m, r);
  },
  '9156'(m, r) { r.hl = 0x7304; M['9159'](m, r); },
};
