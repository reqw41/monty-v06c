// Модель: звук — перевод байтов SN76489 в регистры AY (прослойка Muffie 211E), TURN_OFF_SOUND, вызовы
// проигрывателя эффектов (21C5, 21CA, 21CF, 21D4). Переменные прослойки: 20F7 (защёлка), 20F8 (младшие
// 4 бита периода), 20F9 (80h — шум от канала 2), 20FA (ослабление шума).
'use strict';
const { rd, wr } = require('./core');

function psg(m, reg, v) { m.psgSel = reg & 15; m.psg[m.psgSel] = v & 0xff; if (m.onPsg) m.onPsg(m.psgSel, v & 0xff, m.frames); }

// sn: A = байт SN76489 (все регистры сохраняются)
function sn(m, a) {
  const b = a;
  if (a & 0x80) {
    wr(m, 0x20f7, a);
    if (a & 0x10) {
      const ch = (b & 0x60) >> 5, att = (~b) & 0x0f;
      if (ch === 3) wr(m, 0x20fa, att); else psg(m, 8 + ch, att);
    } else if ((b & 0x60) !== 0x60) wr(m, 0x20f8, b & 0x0f);
    else wr(m, 0x20f9, (b & 3) === 3 ? 0x80 : 0);
    return;
  }
  const lo = ((((a & 0x3f) << 4) & 0xf0) + rd(m, 0x20f8)) & 0xff;
  let d = (rd(m, 0x20f7) & 0x60) >> 4;
  psg(m, d, lo); d++;
  psg(m, d, ((b & 0x3f) >> 4) & 7);
  d--;
  if (((rd(m, 0x20f9) + d) & 0xff) === 0x84 && rd(m, 0x20fa)) psg(m, 0x0a, rd(m, 0x20fa));
}

const S = module.exports = {
  sn,
  '211E'(m, r) { sn(m, r.a); },
  // 1FD6 TURN_OFF_SOUND -> 023B: 9F, BF, DF, FF (все каналы и шум — без звука); A := FF
  '1FD6'(m, r) { for (const v of [0x9f, 0xbf, 0xdf, 0xff]) sn(m, v); r.a = 0xff; },
  '21C5'(m, r) { sn(m, r.a); r.a = rd(m, r.hl); },
  '21CA'(m, r) { sn(m, r.a); r.hl = (r.hl + 1) & 0xffff; },
  '21CF'(m, r) { r.a |= rd(m, r.hl); sn(m, r.a); },
  '21D4'(m, r) { sn(m, r.a); r.a = rd(m, 0x7034); sn(m, r.a); },
};
