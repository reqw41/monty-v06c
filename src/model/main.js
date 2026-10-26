// Модель: главный цикл (A5CA/A5D1) — таблица процессов A8A1 (счётчик, процедура, перезагрузка): процедура
// вызывается, когда счётчик = 1; FE — процесс выключен. Кадр (обработчик A9B3) — в ожиданиях, как в coop:
// A5D8 — пока 705F бит 3 (A60B), A5CA — пока 7207 бит 7 = 0, 8C13 — пока 70B1 бит 3.
'use strict';
const { rd, wr, rd16 } = require('./core');
const F = require('./frame');

const PROC = { 0x91e5: './collide', 0x8f5f: './collide', 0x88d1: './hero', 0xa8d6: './frame' };
const M = module.exports = {
  frame(m, r) { F.A9B3(m, r); },
  '8C13'(m, r) { wr(m, 0x70b1, rd(m, 0x70b1) | 8); while (rd(m, 0x70b1) & 8) M.frame(m, r); },
  // итерация A5D1 -> A5CA (подмена с переходом: PC := A5D1)
  A5D1(m, r) {
    wr(m, 0x7207, 0);
    for (let p = 0xa8a1; ; p += 5) {
      while (rd(m, 0x705f) & 8) M.frame(m, r);
      const cnt = rd16(m, p); if ((cnt >> 8) === 0xff) break;
      const fn = rd16(m, p + 2);
      let a = rd(m, cnt);
      if (a !== 0xfe) {
        if (a === 1) { const h = require(PROC[fn])[fn.toString(16).toUpperCase()]; if (!h) throw new Error('процесс ' + fn.toString(16)); h(m, r); }
        a = (rd(m, cnt) - 1) & 0xff;
      }
      if (!a) a = rd(m, p + 4);
      wr(m, cnt, a);
    }
    while (!(rd(m, 0x7207) & 0x80)) M.frame(m, r);
  },
};
M.JUMPS = { A5D1: 0xa5d1 };
