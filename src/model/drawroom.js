// Модель: рисование комнаты DRAW_ROOM (A067) — поток описания, примитивы, объекты, зеркало, интерфейс.
// Дословно по коду картриджа: рабочие ячейки 7190-71B1, 72C0, 7086, 7304.., 707A, 71A2 — как у оригинала.
'use strict';
const { rd, wr, rd16, wr16 } = require('./core');
const V = require('./vdp');
const U = require('./vram');
const S = require('./sound');
const RM = require('./room');

const hl16 = (v) => v & 0xffff;

const D = module.exports = {
  // A4E3: 71B0/71B1 := клетка: p1 и старшие 2 бита кода
  A4E3(m, r) { const k = rd(m, 0x7196); wr(m, 0x71b1, (k >> 6) & 3); wr(m, 0x71b0, rd(m, 0x7197)); r.a = rd(m, 0x7197); r.hl = 0x71b0; },
  // A4F8: 719A := ROOM_TS[K & 3F]
  A4F8(m, r) { r.a = rd(m, 0x7196) & 0x3f; r.hl = 0x9444 + r.a; r.b = 0; r.c = r.a; r.a = rd(m, r.hl); wr(m, 0x719a, r.a); },
  // A509: 71B0 += 20h
  A509(m, r) { r.bc = 0x20; r.hl = hl16(rd16(m, 0x71b0) + 0x20); wr16(m, 0x71b0, r.hl); },
  // A2D5: K & 1 — 71B0 += 1
  A2D5(m, r) { r.a = rd(m, 0x7196) & 1; if (!r.a) return; r.hl = hl16(rd16(m, 0x71b0) + 1); wr16(m, 0x71b0, r.hl); },
  // A257: 719D, 719E := D, E; E строк по D клеток тайла 719B; A := (71A0)
  A257(m, r) {
    wr(m, 0x719d, r.d); wr(m, 0x719e, r.e);
    let rows = rd(m, 0x719e);
    do {
      r.b = rd(m, 0x719d); r.c = 1; r.de = rd16(m, 0x71b0); r.hl = 0x719b;
      U.AEA7(m, r); D.A509(m, r);
      r.a = rd(m, 0x71a0); rows = (rows - 1) & 0xff;
    } while (rows);
    r.b = 0;
  },
  // A21A: прямоугольник тайла T(1)
  A21A(m, r) {
    D.A4E3(m, r); wr(m, 0x719b, rd(m, 0x9fd2 + rd(m, 0x719a)));
    if (rd(m, 0x7196) & 1) { r.d = rd(m, 0x7198); r.e = rd(m, 0x7199); wr(m, 0x71a0, 4); } else { const p = rd(m, 0x7198); r.d = p >> 4; r.e = p & 0x0f; wr(m, 0x71a0, 3); }
    D.A257(m, r);
  },
  // A27C: треугольник
  A27C(m, r) {
    D.A4E3(m, r); wr(m, 0x719b, rd(m, 0x9fd4 + rd(m, 0x719a)));
    r.d = r.e = rd(m, 0x7198); if (rd(m, 0x7196) & 0x10) r.e = (r.e << 1) & 0xff;
    D.A257(m, r);
    D.A4E3(m, r); wr(m, 0x719b, rd(m, 0x9fd2 + rd(m, 0x719a)));
    D.A2D5(m, r);
    for (;;) {
      const n = (rd(m, 0x7198) - 1) & 0xff; wr(m, 0x7198, n);
      if (!n) { r.a = 3; return; }
      r.d = n; r.e = ((rd(m, 0x7196) & 0x10) >> 4) + 1;
      D.A257(m, r); D.A2D5(m, r);
    }
  },
  // A2F0: столбец ширины T(0), (7198) строк
  A2F0(m, r) {
    D.A4E3(m, r); r.hl = 0x9fd1 + rd(m, 0x719a); r.c = rd(m, r.hl); r.hl = hl16(r.hl + 1); r.b = rd(m, 0x7198);
    r.de = rd16(m, 0x71b0); U.AA96(m, r); r.a = 3;
  },
  // A30E: столбец + верхняя строка следующими T(0) тайлами
  A30E(m, r) { D.A2F0(m, r); r.hl = hl16(r.hl + r.c); r.b = 1; U.AA96(m, r); r.a = 3; },
  // A318: полоса с концами
  A318(m, r) {
    D.A4E3(m, r); r.hl = 0x9fd2 + rd(m, 0x719a); r.de = rd16(m, 0x71b0); r.c = 1; r.b = rd(m, 0x7198);
    U.AEA7(m, r); r.hl = hl16(r.hl + 1); r.b = (r.b - 1) & 0xff; U.AEA7(m, r); r.hl = hl16(r.hl + 1); r.b = 1; U.AEA7(m, r); r.a = 3;
  },
  // A340: узор / подряд идущие тайлы
  A340(m, r) {
    D.A4E3(m, r); r.hl = 0x9fd1 + rd(m, 0x719a); r.a = rd(m, r.hl);
    if (r.a === 0xff) { r.c = rd(m, 0x7198); r.b = 1; } else { r.c = r.a; r.b = rd(m, 0x7198); }
    r.hl = hl16(r.hl + 1); r.de = rd16(m, 0x71b0); U.AEA7(m, r); r.a = 3;
  },
  // A2E3: код 0B — столбец в 4 строки
  A2E3(m, r) { wr(m, 0x7198, 4); D.A2F0(m, r); r.a = 2; },
  // A394: HL := 72C0 + 2 * (71A2), A := (HL)
  A394(m, r) { r.a = (rd(m, 0x71a2) << 1) & 0xff; r.hl = 0x72c0; RM.A540(m, r); },
  // A3A0: позиция объекта (71B0) — в список 72C0
  A3A0(m, r) { D.A394(m, r); r.de = rd16(m, 0x71b0); wr(m, r.hl, r.e); r.hl = hl16(r.hl + 1); wr(m, r.hl, r.d); },
  // A378: предмет 2x2 из набора A в клетку DE
  A378(m, r) {
    r.hl = 0x9fd2; RM.A540(m, r); r.bc = 0x0102; U.AEA7(m, r);
    r.hl = hl16(r.hl + 2); r.de = hl16(r.de + 0x20); U.AEA7(m, r);
  },
  // A36A: предмет
  A36A(m, r) {
    RM.A514(m, r); if (r.cf) { r.a = 2; return; }
    D.A4E3(m, r); D.A3A0(m, r); r.a = rd(m, 0x719a); D.A378(m, r); r.a = 2;
  },
  // A3D5: 2 тайла из набора A в клетку (71B0)
  A3D5(m, r) { r.hl = 0x9fd2 + r.a; r.b = 0; r.c = r.a; r.bc = 0x0102; r.de = rd16(m, 0x71b0); U.AEA7(m, r); },
  // A3AB: дверь
  A3AB(m, r) {
    RM.A514(m, r);
    if (r.cf) {                                  // открыта: 2x4 из набора + 2
      D.A4E3(m, r); r.a = (rd(m, 0x719a) + 2) & 0xff;
      D.A3D5(m, r); r.hl = hl16(r.hl + 2); r.de = hl16(r.de + 0x20); r.b = 3; U.AA96(m, r); r.a = 2; return;
    }
    D.A4E3(m, r); D.A3A0(m, r);
    r.hl = 0x9fd2 + rd(m, 0x719a); r.bc = 0x0301; r.de = rd16(m, 0x71b0); U.AA96(m, r);
    r.hl = hl16(r.hl + 1); r.de = hl16(r.de + 0x60); r.bc = 0x0101; U.AEA7(m, r); r.a = 2;
  },
  // A405: враг — атрибуты спрайта 7304 + 4n, список 7086, позиция в 72C0
  A405(m, r) {
    RM.A514(m, r); if (r.cf) { r.a = 2; return; }
    const n = (rd(m, 0x707a) + 1) & 0xff; wr(m, 0x707a, n);
    r.c = (n << 2) & 0xff; r.b = 0;
    D.A394(m, r); wr(m, r.hl, r.c); r.hl = hl16(r.hl + 1); wr(m, r.hl, 0xff);
    let p = 0x7304 + r.c;
    wr(m, p, rd(m, 0xa496 + (rd(m, 0x7197) & 0x0f))); p++;
    wr(m, p, rd(m, 0xa4a5 + ((rd(m, 0x7197) >> 4) & 0x0f))); p++;
    const ts = rd(m, 0x719a); let e;
    if (ts === 0x86) { wr(m, p - 2, rd(m, p - 2) - 2); e = 0x48; } else e = ts === 0x88 ? 0x10 : 8;
    let q = 0x7086; while (rd(m, q) !== 0xff) q += 2;
    wr(m, q, n + 1 + e); wr(m, q + 1, rd(m, 0x7196) & 0x40 ? 0x80 : 0);
    r.hl = 0x9fd1 + ts; r.d = rd(m, r.hl); r.hl = hl16(r.hl + 1); r.a = rd(m, r.hl);
    wr(m, p, r.a); wr(m, p + 1, r.d); r.hl = hl16(p + 1); r.a = 2;
  },
  // AB29 MIRROR_ROOM: строки 5..22 — пары тайлов (AB0C) и разворот (строка 23 читается, но не пишется)
  AB29(m, r) {
    const sv = { hl: r.hl, de: r.de, bc: r.bc, a: r.a, zf: r.zf, cf: r.cf, iy: r.iy };
    U.A8B7(m, r);
    wr(m, 0x7002, 0x13);
    let row = 0xa0;
    for (;;) {
      r.a = 2; r.de = row; r.hl = 0x7200; r.iy = 0x20; V['1FBB'](m, r);
      for (let i = 0; i < 32; i++) {
        const t = rd(m, 0x7200 + i);
        if (t === 8 || t === 0) continue;
        for (let p = 0xab0c; rd(m, p) !== 0xff; p += 2) if (t === rd(m, p)) { wr(m, 0x7200 + i, rd(m, p + 1)); break; }
      }
      const c = (rd(m, 0x7002) - 1) & 0xff; wr(m, 0x7002, c);
      if (!c) break;
      for (let i = 0; i < 32; i++) wr(m, 0x729f - i, rd(m, 0x7200 + i));
      r.de = row; r.bc = 0x0120; r.hl = 0x7280; U.AEA7(m, r);
      row += 0x20;
    }
    r.iy = 0x20;
    Object.assign(r, { hl: sv.hl, de: sv.de, bc: sv.bc, a: sv.a, zf: sv.zf, cf: sv.cf });
    r.hl = sv.hl; r.de = sv.de; r.bc = sv.bc;
    U.A8C3(m, r);
  },
  // AAA8: строка B тайлов AA94 с клетки DE и строка AA95 на 4 строки ниже
  AAA8(m, r) { r.hl = 0xaa94; U.AEA7(m, r); r.de = hl16(r.de + 0x80); r.hl = 0xaa95; U.AEA7(m, r); },
  // AA5D: рамка интерфейса
  AA5D(m, r) {
    r.de = 1; r.bc = 0x0a01; D.AAA8(m, r);
    r.bc = 0x0801; r.de = 0x17; D.AAA8(m, r);
    r.hl = 0xaa88; r.bc = 0x030c; r.de = 0x20; U.AA96(m, r);
    r.de = 0x36; r.hl = 0xaa89; r.bc = 0x030a; U.AA96(m, r);
  },
  // A1DF CLEAR_ROOM
  A1DF(m, r) {
    r.b = 3; r.hl = 0x18a0; r.de = 0x0260; r.a = 0; V['1F82'](m, r);
    r.a = rd(m, 0x705f);
    if (r.a & 4) { r.a = rd(m, 0x71a8); if (r.a !== 0x0a) { r.zf = 0; return; } }
    r.hl = 0x1800; r.de = 0xa0; r.a = 8; V['1F82'](m, r); D.AA5D(m, r);
  },
  // AF66: тайл A в VRAM HL (FILL 1 байт), HL += 1 (DE сохраняется)
  AF66(m, r) { const de = r.de; r.de = 1; U.AE25(m, r); r.hl = hl16(r.hl + 1); r.de = de; },
  // AF54: цифра младшей тетрады A (ведущие нули — пусто, флаг 70B1 бит 0) -> AF66
  AF54(m, r) {
    const hl = r.hl; let a = r.a & 0x0f;
    if (a !== 0 || (rd(m, 0x70b1) & 1)) { a = (a + r.c) & 0xff; wr(m, 0x70b1, rd(m, 0x70b1) | 1); }
    r.a = a; r.hl = hl; D.AF66(m, r);
  },
  // AF32: 3 байта BCD 7017.. в 6 цифр с HL (основа C)
  AF32(m, r) {
    r.b = 3; r.de = 0x7017;
    for (let i = 0; i < 3; i++) {
      const v = rd(m, r.de); const bc = r.bc;
      r.a = ((v << 24) >> 28) & 0xff; D.AF54(m, r); r.bc = bc;
      r.a = rd(m, r.de); D.AF54(m, r); r.de = hl16(r.de + 1); r.bc = bc;
    }
    r.b = 0; r.hl = 0x70b1; wr(m, 0x70b1, rd(m, 0x70b1) & ~1);
  },
  // AEFE: счёт (две строки цифр) и номер уровня
  AEFE(m, r) {
    const sv = { hl: r.hl, bc: r.bc, de: r.de, a: r.a, zf: r.zf, cf: r.cf };
    U.A8B7(m, r);
    r.hl = 0x1838; r.c = 0x18; D.AF32(m, r);
    r.hl = 0x1858; r.c = 0x28; D.AF32(m, r);
    r.hl = 0x1834; const lv = rd(m, 0x71a6); r.a = (lv + 0x18) & 0xff; D.AF66(m, r);
    r.hl = 0x1854; r.a = (lv + 0x28) & 0xff; D.AF66(m, r);
    U.A8C3(m, r);
    Object.assign(r, sv); r.hl = sv.hl; r.bc = sv.bc; r.de = sv.de;
  },
  // AABB: жизни — 7049 - 1 шляп (6F) с 1861 и 1877
  AABB(m, r) {
    if (rd(m, 0x705f) & 0x20) return;
    U.A8B7(m, r);
    r.hl = 0x1861; r.de = 8; r.a = 0; U.AE25(m, r);
    r.hl = 0x1877; r.de = 8; r.a = 0; U.AE25(m, r);
    const lives = rd(m, 0x7049); let a = lives, fin = lives;
    if (a !== 1) {
      a = (a - 1) & 0xff; r.hl = 0x1861; r.e = a; r.d = 0;
      if (a >= 0x0b) {
        r.de = 0x0a; r.a = 0x6f; U.AE25(m, r);
        fin = (lives - 1) & 0xff; a = (fin - 0x0a) & 0xff; r.hl = 0x1877; r.e = 8;
        if (a < 9) r.e = a;
      }
      r.d = 0; r.a = 0x6f; U.AE25(m, r);
    }
    r.a = fin; U.A8C3(m, r);
  },
  // A548 DRAW_INVENTORY: счёт, очистка поля 3x10 с 21h, предметы из 71B2.., жизни
  A548(m, r) {
    D.AEFE(m, r);
    r.de = 0x21; r.hl = 0x85d7; r.bc = 0x030a; U.AA96(m, r); r.a = 3;
    r.hl = 0x71b2;
    for (;;) {
      r.a = rd(m, r.hl); if (r.a === 0xff) return D.AABB(m, r);
      const hl = r.hl, de = r.de; D.A378(m, r); r.de = hl16(de + 2); r.hl = hl16(hl + 1);
    }
  },
  // A067 DRAW_ROOM
  A067(m, r) {
    U.AE77(m, r); S['1FD6'](m, r);
    for (let i = 0; i < 15; i++) wr(m, 0x7086 + i, 0xff);
    for (let i = 0; i < 31; i++) wr(m, 0x72c0 + i, 0);
    wr(m, 0x72df, 0xfe); wr(m, 0x72de, 0xfe);
    D.A1DF(m, r);
    RM.A4B5(m, r); wr(m, 0x7015, r.a); RM.A4CE(m, r);
    wr(m, 0x71a2, 0); wr(m, 0x71a1, (rd(m, 0x71a5) << 1) & 0xff);
    const stack = [];
    const adv = (n) => wr16(m, 0x7190, hl16(rd16(m, 0x7190) + n));
    for (;;) {
      const p = rd16(m, 0x7190);                     // A0A4: младшие байты, затем старшие (как у оригинала)
      if (rd(m, 0x7190) < rd(m, 0x7192) || rd(m, 0x7191) !== rd(m, 0x7193)) {
        const k = rd(m, p); wr(m, 0x7196, k);
        if ((k & 0x3e) === 0x3e) {                   // A191: подописание
          stack.push([rd(m, 0x7190), rd(m, 0x7191), rd(m, 0x7192), rd(m, 0x7193), rd(m, 0x7195)]);
          const sub = rd(m, p + rd(m, 0x7195) + 1);
          wr(m, 0x7195, k & 1); wr(m, 0x7194, rd(m, 0x7194) + 1);
          r.a = sub; RM.A4CE(m, r);
          continue;
        }
        for (let i = 0; i < 3; i++) wr(m, 0x7197 + i, rd(m, p + 1 + i));
        D.A4F8(m, r);
        const kk = k & 0x3f; let b = 2;
        if (kk === 0x10 || kk === 0x11) {            // A1BE: конец потока на младших уровнях
          if (kk === 0x11) b = 6;
          b = (((k & 0xc0) >> 6) + b) & 0xff;
          if (rd(m, 0x71a6) < b) { endStream(); if (done) break; continue; }
          adv(1); continue;
        }
        if (kk === 0x0b) { D.A2E3(m, r); adv(2); continue; }
        if (kk < 0x20) {
          const h = (k >> 2) & 7;
          const fn = [D.A21A, D.A27C, D.A2F0, D.A318, D.A21A, D.A27C, D.A30E, D.A340][h];
          fn(m, r); adv(r.a); continue;
        }
        if (!rd(m, 0x7194)) { if (kk < 0x29) D.A36A(m, r); else if (kk < 0x30) D.A3AB(m, r); else D.A405(m, r); }
        adv(2); continue;
      }
      endStream(); if (done) break;
    }
    var done;
    function endStream() {                          // A0B6: конец потока
      done = false;
      const depth = rd(m, 0x7194);
      if (!depth) { done = true; return; }
      wr(m, 0x7194, depth - 1);
      if (rd(m, 0x7195)) D.AB29(m, r);
      const [a0, a1, a2, a3, mir] = stack.pop();
      wr(m, 0x7195, mir); wr(m, 0x7190, a0); wr(m, 0x7191, a1); wr(m, 0x7192, a2); wr(m, 0x7193, a3);
      adv(2);
    }
    // A0E7: конец описания — интерфейс (кроме вступления не в столбце 10), спрайты врагов за последним — скрыть
    const f = rd(m, 0x705f);
    if (!(f & 4) || rd(m, 0x71a8) === 0x0a) D.A548(m, r);
    const c = (rd(m, 0x707a) << 2) & 0xff;
    r.hl = 0x1b08 + c; r.de = (0x80 - c) & 0xff; r.a = 0; V['1F82'](m, r);
    U.AE83(m, r);
  },
};
