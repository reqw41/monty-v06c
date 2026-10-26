// Модель: предметы и столкновения — процесс 91E5 (факел/меч/враги), инвентарь 908F/909C, флаги взятия
// 92A2/92BE, кадр героя 92DC, мелкие счётчики (91B0, 91BD, 92D1), очистка 840B, перезапуск комнаты 919A.
'use strict';
const { rd, wr, rd16, wr16, z } = require('./core');
const U = require('./vram');
const S = require('./sound');
const RM = require('./room');
const DR = require('./drawroom');

const hl16 = (v) => v & 0xffff;
// ADD A,b; DAA (Z80): [результат, перенос]
function bcd(a, b) {
  const s = a + b, h = (a & 0xf) + (b & 0xf) > 0xf; let c = s > 0xff, x = s & 0xff, d = 0;
  if (h || (x & 0xf) > 9) d = 6;
  if (c || x > 0x99) { d |= 0x60; c = true; }
  return [(x + d) & 0xff, c];
}
// CPIR: поиск A с HL, BC байт -> r.hl, r.bc, r.zf как у Z80
function cpir(m, r) { let f = false; do { f = rd(m, r.hl) === r.a; r.hl = hl16(r.hl + 1); r.bc = (r.bc - 1) & 0xffff; } while (r.bc && !f); r.zf = f ? 1 : 0; }
const K = module.exports = {
  cpir,
  // 840B: (HL) .. (HL + BC) := 0
  '840B'(m, r) { for (let i = 0; i <= r.bc; i++) wr(m, r.hl + i, 0); r.de = hl16(r.hl + r.bc + 1); r.hl = hl16(r.hl + r.bc); r.bc = 0; },
  // 9067/906D/9073: очки за событие 70BD := 50 / 100 / 3000 (BCD)
  '9067'(m, r) { wr16(m, 0x70bd, 0x0050); },
  '906D'(m, r) { wr16(m, 0x70bd, 0x0100); },
  '9073'(m, r) { wr16(m, 0x70bd, 0x3000); },
  // 908F: предмет A в инвентаре 71B2 (6 мест)? Z и CF — есть; HL, BC — как после CPIR
  '908F'(m, r) {
    let hl = 0x71b2, bc = 6, f = 0;
    do { f = rd(m, hl) === r.a; hl++; bc--; } while (bc && !f);
    r.hl = hl; r.bc = bc; r.zf = f ? 1 : 0; r.cf = r.zf;
  },
  // 909C: убрать найденный предмет (сдвиг хвоста), перерисовать инвентарь
  '909C'(m, r) {
    if (!r.bc) throw new Error('909C: LDIR с BC = 0');
    for (let i = 0; i < r.bc; i++) wr(m, r.hl - 1 + i, rd(m, r.hl + i));
    r.de = hl16(r.hl - 1 + r.bc); r.hl = hl16(r.hl + r.bc); r.bc = 0; DR.A548(m, r);
  },
  // 90A5: 71B0 -= смещение по C mod 4 (бит 0 — клетка влево, бит 1 — строка вверх), затем 90C8
  '90A5'(m, r) {
    r.e = (r.c + 4) % 4 & 0xff; let a = 0; r.b = 0;
    if (r.e & 1) a += 1; if (r.e & 2) a += 0x20;
    r.c = a; r.hl = hl16(rd16(m, 0x71b0) - a); wr16(m, 0x71b0, r.hl); r.cf = 0;
    return K['90C8'](m, r);
  },
  // 90C8: клетка (71B0) в списке объектов комнаты 72C0..72F1 (поиск с конца) -> 92A2 (снять флаг взятия);
  // иначе 90E3 — проверка прыжка/огня
  '90C8'(m, r) {
    let de = 0x72f2, hl = 0x71b0, b = 0x18, L = '90D0';
    for (;;) {
      if (L === '90D0') de--;
      de--;
      if (rd(m, de) === rd(m, hl)) {
        hl++; de++;
        if (rd(m, de) === rd(m, hl)) { r.hl = de; r.de = de; r.b = b; return K['92A2'](m, r); }
        L = '90D1'; continue;
      }
      b = (b - 1) & 0xff; if (!b) break; L = '90D0';
    }
    r.de = de; r.hl = hl; r.b = 0;
    return K['90E3'](m, r);
  },
  // 90E3: CF — прыжок запрещён/огонь отработан: на верёвке/цепи (тайл 08 под ногами) вне состояния 4 после
  // вступления; иначе огонь+? (73EE биты 7-6): удержание C0 после отпускания (7075 = 80h) — сброс, CF
  '90E3'(m, r) {
    if ((rd(m, 0x7057) === 8 || rd(m, 0x7059) === 8) && rd(m, 0x7079) !== 4 && (rd(m, 0x705f) & 4)) { r.zf = 0; r.cf = 1; return; }
    r.a = rd(m, 0x73ee) & 0xc0;
    if (r.a === 0xc0 && rd(m, 0x7075) === 0x80) { r.a = 0; wr(m, 0x7075, 0); r.zf = 1; r.cf = 1; return; }
    wr(m, 0x7075, r.a); r.zf = r.a === 0 ? 1 : 0; r.cf = 0;
  },
  // 911E/9122: тайл A (911E — под ногами 705B) проходим? CF — нет опоры
  '911E'(m, r) { r.hl = 0x705b; r.a = rd(m, 0x705b); return K['9122'](m, r); },
  '9122'(m, r) {
    for (let i = 0; i < 10; i++) if (rd(m, 0x93ff + i) === r.a) { r.cf = 0; r.zf = 1; return; }
    if (r.a === 0xe8) { r.zf = 1; r.cf = 0; if (rd(m, 0x7000) & 0x40) { r.a = rd(m, 0x7000); r.zf = 0; r.cf = 1; } else r.a = rd(m, 0x7000); return; }
    K['913B'](m, r); if (r.zf) { r.a = 0xd2; r.cf = 0; return; }
    r.cf = 1;
  },
  '913B'(m, r) { r.zf = 0; for (let i = 0; i < 5; i++) if (rd(m, 0xa00e + i) === r.a) { r.zf = 1; break; } },
  // 919A: перерисовка комнаты (сброс спрайтов врагов 7308..7328)
  '919A'(m, r) { wr(m, 0x7000, rd(m, 0x7000) | 1); wr(m, 0x707a, 0); r.hl = 0x7308; r.bc = 0x20; K['840B'](m, r); DR.A067(m, r); },
  '91B0'(m, r) { let a = (rd(m, 0x7096) - 1) & 0xff; if (a & 0x80) a = 3; wr(m, 0x7096, a); r.a = a; },
  '91BD'(m, r) {
    r.hl = 0x70ad; const v = (rd(m, 0x70ad) - 1) & 0xff; wr(m, 0x70ad, v); if (v) { r.zf = 0; return; }
    wr(m, 0x70ad, 2); let a = (rd(m, 0x70aa) - 1) & 0xff; if (a & 0x80) a = 7; wr(m, 0x70aa, a); r.a = a;
  },
  // 91D1: CF := |A - (HL)| < B (модуль по знаку байта)
  '91D1'(m, r) { let a = (r.a - rd(m, r.hl)) & 0xff; if (a & 0x80) a = (-a) & 0xff; r.a = a; r.cf = a < r.b; r.zf = a === r.b; },
  // 91D9: цвет группы 14h (тайлы A0-A7: факел/меч?) := A
  '91D9'(m, r) { r.hl = 0x2014; r.de = 1; U.AE25(m, r); },
  // 92A2: снять/поставить флаг взятия объекта по его месту HL в списке 72C0 (на уровнях 4+ при 7000 бит 3 — нет)
  '92A2'(m, r) {
    if (rd(m, 0x71a6) >= 4 && (rd(m, 0x7000) & 8)) { r.zf = 0; return; }
    r.hl = hl16(r.hl - 1); let a = (r.l - 0xc0) & 0xff; a = ((a << 24) >> 25) & 0xff; r.a = a;
    K['92BE'](m, r); r.c = 0; r.e = 0;
  },
  '92BE'(m, r) {
    wr(m, 0x71a2, r.a - 1); RM.A4B5(m, r); wr(m, 0x71a1, (r.a << 1) & 0xff); RM.A514(m, r);
    r.a = rd(m, r.hl) ^ r.d; wr(m, r.hl, r.a);
  },
  '92D1'(m, r) { r.hl = 0x7098; const v = rd(m, 0x7098) ^ 0x80; wr(m, 0x7098, v); r.a = v; r.zf = v === 0 ? 1 : 0; if (!v) K['91B0'](m, r); },
  // 91E5 (процесс): таймер факела 704A (мигание цвета группы), амулет 8C; столкновение героя с врагом:
  // меч (91) — враг гибнет, очки 2000/3000; иначе гибель героя (8DA2), на уровнях 1-4 враг тоже снимается
  '91E5'(m, r) {
    let a = (rd(m, 0x70ac) - 1) & 0xff; if (!a) a = 1; wr(m, 0x70ac, a);
    if (rd(m, 0x7079) >= 8) return;
    const t = rd(m, 0x704a);
    if (t) {
      wr(m, 0x704a, t - 1);
      if (t === 1) { r.a = 0xc0; K['91D9'](m, r); wr(m, 0x704a, 0); a = 'c'; }
      else { r.a = 0xe0; K['91D9'](m, r); a = 'n'; }
    } else a = 'c';
    if (a === 'c') { r.a = 0x8c; K['908F'](m, r); if (r.zf) K['909C'](m, r); }
    K['92D1'](m, r);
    if (rd(m, 0x704a)) return;
    wr(m, 0x7084, rd(m, 0x7300)); wr(m, 0x7085, rd(m, 0x7301));
    let hl = 0x72c1;
    for (;;) {
      hl++; r.c = rd(m, hl); hl++; r.a = rd(m, hl);
      if (r.a === 0xfe) { r.hl = hl; r.zf = 1; return; }
      if (r.a !== 0xff) continue;
      const sp = 0x7304 + r.c; r.b = 0;
      r.hl = sp; r.a = rd(m, 0x7084); r.b = 0x0d; K['91D1'](m, r); if (!r.cf) continue;
      r.hl = sp + 1; r.a = rd(m, 0x7085); r.b = 8; K['91D1'](m, r); if (!r.cf) continue;
      const cp = sp + 3; if (!rd(m, cp)) continue;
      r.a = 0x91; K['908F'](m, r);
      if (!r.zf) {
        r.hl = hl; if (rd(m, 0x71a6) < 5) K["92A2"](m, r);
        r.c = 0; r.e = 0; require('./hero')['8DA2'](m, r); return;
      }
      K['909C'](m, r); r.a = 3; S.AC1A(m, r);
      const col = rd(m, cp); wr(m, cp, 0);
      r.hl = col === 0x0f ? 0x2000 : 0x3000;
      K.A587(m, r);
      r.hl = hl; K['92A2'](m, r); return;
    }
  },
  // AF70 ADD_SCORE: счёт 7017-7019 (BCD, старший первым) += HL; при переносе в 7017 — жизнь (кроме
  // уровней 5+ при нечётной сотне тысяч), вывод жизней, звук 0. Регистры (кроме C) сохраняются
  AF70(m, r) {
    const sv = { a: r.a, hl: r.hl, zf: r.zf, cf: r.cf };
    let [x, c] = bcd(r.l, rd(m, 0x7019)); wr(m, 0x7019, x);
    const mid = (v) => {
      [x, c] = bcd(v, rd(m, 0x7018)); wr(m, 0x7018, x); if (!c) return;
      if (!(x & 1) || rd(m, 0x71a6) < 5) wr(m, 0x7049, rd(m, 0x7049) + 1);
      [x] = bcd(1, rd(m, 0x7017)); wr(m, 0x7017, x);
      DR.AABB(m, r); r.a = 0; S.AC1A(m, r);
    };
    if (c) mid(1);
    mid(sv.hl >> 8);
    Object.assign(r, sv); r.hl = sv.hl;
  },
  A587(m, r) { K.AF70(m, r); DR.AEFE(m, r); },
  // A56C: предмет C в инвентарь (CF — полон); 44h (драгоценность) — не хранится, 1000 очков; иначе очки 70BD
  A56C(m, r) {
    let hl = 0x71b1; do hl++; while (rd(m, hl) !== 0xff);
    if ((hl & 0xff) === 0xb7) { r.hl = hl; r.a = 0xb7; r.zf = 1; r.cf = 1; return; }
    r.a = r.c;
    if (r.c === 0x44) wr16(m, 0x70bd, 0x1000); else wr(m, hl, r.c);
    r.hl = hl; DR.A548(m, r); r.hl = rd16(m, 0x70bd); K.A587(m, r); r.hl = hl; r.cf = 0;
  },
  // 901B: взять предмет A (место — остаток BC поиска): в инвентарь, звук 2, стереть 2x2 (набор 0B)
  '901B'(m, r) {
    const bc = r.bc; r.c = r.a; K.A56C(m, r);
    if (r.cf) { r.bc = bc; return; }
    r.a = 2; S.AC1A(m, r); U.A8B7(m, r); r.bc = bc; K['90A5'](m, r);
    r.a = 0x0b; r.de = rd16(m, 0x71b0); DR.A378(m, r); wr(m, 0x70b1, rd(m, 0x70b1) | 0x10); U.A8C3(m, r); r.bc = bc;
  },
  // 8F5F (процесс): двери (ключ нужного цвета — открыть, 300 очков), огонь/лазеры — гибель (кроме факела?),
  // предметы под героем (тайлы 9430 — ключи/меч/амулет..., 9418 — факел, драгоценности, меч, амулет)
  '8F5F'(m, r) {
    if (rd(m, 0x7079) === 9) { r.zf = 1; return; }
    wr(m, 0x7011, rd(m, 0x7011) ^ 0x80);
    K.h9156(m, r);
    r.a = rd(m, 0x7057);
    if (!(rd(m, 0x7078) & 0x80)) { wr(m, 0x71b0, rd(m, 0x71b0) + 2); r.a = rd(m, 0x7059); }
    const door = { 0x9c: [0x70, 0x5d], 0xb7: [0x69, 0x58], 0xc7: [0x77, 0x62] }[r.a];
    if (door) {
      r.d = door[0]; r.a = door[1]; wr(m, 0x7084, r.d); K['908F'](m, r);
      if (r.zf) {
        K['909C'](m, r); wr16(m, 0x71b0, rd16(m, 0x71b0) - 0x60); K['90C8'](m, r);
        r.a = rd(m, 0x7084); DR.A3F1(m, r); const a = r.a; r.a = 8; S.AC1A(m, r); r.a = a;
        r.hl = 0x0300; K.A587(m, r); return;
      }
    }
    K.h9156(m, r); wr(m, 0x71b0, rd(m, 0x71b0) + 1);
    r.a = rd(m, 0x7058); r.bc = 8; r.hl = 0x9428; cpir(m, r);
    if (r.zf) {
      if (rd(m, 0x704a)) { r.a = rd(m, 0x704a); r.zf = 0; return; }
      wr(m, 0x7000, rd(m, 0x7000) | 8); K['90A5'](m, r); wr(m, 0x7000, rd(m, 0x7000) & ~8);
      r.hl = 0x7000; r.c = 0; r.e = 0; require('./hero')['8DA2'](m, r); return;
    }
    r.bc = 0x0c; r.hl = 0x9430; cpir(m, r);
    if (r.zf) {
      K['9067'](m, r); r.hl = hl16(r.hl - 1); const t = rd(m, r.hl) & 0xf8;
      r.a = t === 0x78 ? 0x58 : t === 0x68 ? 0x5d : 0x62;
      return K['901B'](m, r);
    }
    r.bc = 0x10; r.hl = 0x9418; cpir(m, r);
    if (!r.zf) return;
    r.a = r.c;
    if (r.c < 4) { K['906D'](m, r); wr(m, 0x704a, 0xa0); r.a = 0x8c; }
    else if (r.c < 8) { r.a = 0x44; K['9067'](m, r); }
    else if (r.c < 0x0c) { K['9073'](m, r); r.a = 0x53; }
    else { r.a = 0x91; K['9067'](m, r); }
    K['901B'](m, r);
  },
  h9156(m, r) { require('./vram')['9156'](m, r); },
  // 9369: CF := герой смотрит вправо (7078 бит 7 = 0); A и прочие флаги сохраняются
  '9369'(m, r) { r.cf = !(rd(m, 0x7078) & 0x80); },
  // 9305: кадр героя A из таблицы HL: 7302 := (HL + 2A), 7306 := (HL + 2A + 1)
  '9305'(m, r) { r.a = (r.a << 1) & 0xff; RM.A540(m, r); wr(m, 0x7302, r.a); r.de = 0x7306; r.hl = hl16(r.hl + 1); r.a = rd(m, r.hl); wr(m, 0x7306, r.a); },
  // 92DC: кадр спрайта героя (7302 — имя, 7306 — второй слой) по состоянию 7079
  '92DC'(m, r) {
    const st = rd(m, 0x7079); let hl, a;
    const fin = () => { r.a = a; r.hl = hl; K['9305'](m, r); };
    const walk = (x) => { a = x; if (a) { r.a = 9; S.AC1A(m, r); } hl = 0x9380; r.a = a; K['9369'](m, r); if (r.cf) hl = 0x9378; fin(); };
    if (st === 1) return walk(rd(m, 0x70aa) >> 1);
    if (st === 2) { hl = 0x9388; K['9369'](m, r); if (!r.cf) hl = 0x938a; a = 0; return fin(); }
    if (st === 3) { if (rd(m, 0x705f) & 0x40) { wr(m, 0x705f, rd(m, 0x705f) & ~0x40); return; } hl = 0x938e; a = rd(m, 0x70aa) >> 1; return fin(); }
    if (st === 4) { hl = 0x9396; a = rd(m, 0x70aa) >> 1; return fin(); }
    if (st === 5) { hl = 0x938c; a = 0; return fin(); }
    if (st === 9) { hl = 0x939e; a = rd(m, 0x7096); return fin(); }
    if (st === 8 || st === 0x0a) return;
    walk(0);
  },
};
