// Модель: цвета и экраны — загрузчик таблиц AE00 (данные за CALL), цвета 8308, цвета ряда и темнота 8EB0,
// сокровищница A60B (случайные верёвки и драгоценности).
'use strict';
const { rd, wr, rd16, wr16 } = require('./core');
const V = require('./vdp');
const U = require('./vram');
const DR = require('./drawroom');
const K = require('./collide');

const hl16 = (v) => v & 0xffff;
const W = module.exports = {
  // таблица за CALL AE00 по адресу p: (слово источник, байт номер, байт число)..., источник со старшим 0 — конец;
  // PUT_VRAM в таблицу A; возвращает адрес за концом
  tab(m, r, p) {
    const t = r.a;
    for (;;) {
      const src = rd16(m, p);
      if (!(src >> 8)) { r.a = t; r.c = src & 0xff; r.hl = hl16(p + 2); return r.hl; }
      r.de = rd(m, p + 2); r.bc = rd(m, p + 3); r.iy = r.bc; r.hl = src; r.a = t; U.AE2E(m, r); p += 4;
    }
  },
  // AE00 как подмена: адрес возврата — на данные; RET — за конец таблицы
  AE00(m, r) { wr16(m, r.sp, W.tab(m, r, rd16(m, r.sp))); },
  // 8308: цвета групп 00-1B из 841E
  '8308'(m, r) { r.a = 4; W.tab(m, r, 0x830d); },
  // 8EB0: цвета групп 1-7 по ряду (93C0 + 7 * min(ряд, 8)); темнота — ряд >= 9 - уровень без факела (53),
  // кроме сокровищницы: группы 0-2, 10-13, 15-18 — чёрные (ABCD)
  '8EB0'(m, r) {
    W['8308'](m, r);
    let a = rd(m, 0x71a7); if (a >= 8) a = 8;
    r.hl = 0x93c0; r.a = 7 * a; require('./room').A540(m, r); r.de = 1; r.iy = 7; r.a = 4; U.AE2E(m, r);
    r.b = (9 - rd(m, 0x71a6)) & 0xff; r.a = rd(m, 0x71a7);
    if (r.a < r.b) { r.cf = 1; return; }
    r.a = 0x53; K['908F'](m, r); if (r.cf) return;
    if (rd(m, 0x705f) & 0x20) return;
    r.a = 4; W.tab(m, r, 0x8ef5);
  },
  // A60B: сокровищница — экран выкл., поле пусто; 25 верёвок разной длины (по ПЗУ с адреса из счётчика
  // 7047), драгоценности (уровень/2 + 8) по диагонали, стены по краям (кроме столбца 10), счёт; экран вкл.
  A60B(m, r) {
    wr(m, 0x705f, rd(m, 0x705f) & ~8);
    r.bc = 0x0182; V['1FD9'](m, r); r.bc = 0x0705; V['1FD9'](m, r);
    r.a = 0; r.de = 0x0300; r.hl = 0x1800; V['1F82'](m, r);
    if (rd(m, 0x70ac) !== 1) {
      let hl = rd16(m, 0x7047); hl = (((hl >> 8) & 0xae) | 0x80) << 8 | (hl & 0xff);
      for (let n = 0; n < 0x19; n++) {
        const b = (rd(m, hl) & 7) | 2; const e = rd(m, hl + 2); hl = hl16(hl + 3);
        r.b = b; r.c = 1; r.de = 0x0100 | e; r.hl = 0xa9ad; U.AA96(m, r);
      }
      r.b = ((rd(m, 0x71a6) << 24 >> 25) + 8) & 0xff; r.de = 0x0100 | (rd(m, 0x7047) & 0x1f);
      for (let n = r.b; n; n--) {
        wr16(m, 0x71b0, r.de); const de = r.de; r.a = 0x44; DR.A378(m, r); r.de = hl16(de + 0x27);
      }
    }
    r.a = rd(m, 0x71a8);
    if (r.a !== 0x0a) {
      r.de = 0; r.hl = 0xa9ae; if (r.a === 0x0b) { r.hl = 0xa9b0; r.de = 0x1d; }
      r.bc = 0x1803; U.AA96(m, r);
    }
    DR.AEFE(m, r); r.bc = 0x01e2; V['1FD9'](m, r);
  },
};
