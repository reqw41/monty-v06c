// Модель: звук — перевод байтов SN76489 в регистры AY (прослойка Muffie 211E), TURN_OFF_SOUND, вызовы
// проигрывателя эффектов (21C5, 21CA, 21CF, 21D4). Переменные прослойки: 20F7 (защёлка), 20F8 (младшие
// 4 бита периода), 20F9 (80h — шум от канала 2), 20FA (ослабление шума).
'use strict';
const { rd, wr, rd16, wr16 } = require('./core');

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

  // AC06: инвентарь 71B2-71B8 := FF (регистры сохраняются)
  AC06(m, r) { for (let i = 0; i < 7; i++) wr(m, 0x71b2 + i, 0xff); },
  // AC1A START_SFX: эффект A (меньший номер важнее; 1 и 9 не перезапускаются); регистры и флаги сохраняются
  AC1A(m, r) {
    const b = r.a, f = rd(m, 0x702c);
    if (f & 0x80) { const cur = rd(m, 0x702d); if (cur < b || (cur === b && (b === 9 || b === 1))) return; }
    wr(m, 0x702d, b); wr(m, 0x702c, (f | 0xa0) & ~0x40);
    const p = rd16(m, 0xad0b + ((b << 1) & 0xff));
    wr(m, 0x7030, rd(m, p)); wr(m, 0x7032, rd(m, p) - 1);
    wr(m, 0x7035, rd(m, p + 1)); wr(m, 0x7031, rd(m, p + 1) & 3);
    wr16(m, 0x702e, p + 2); wr(m, 0x7033, 0);
  },
  // AC77: эффект окончен — тишина
  AC77(m, r) { r.hl = 0x702c; wr(m, 0x702c, rd(m, 0x702c) & ~0xc0); S['1FD6'](m, r); },
  // AC6D SFX_TICK: раз в (7030) кадров — шаг эффекта: первый шаг — период/ослабление каналов 1 и 0 и шум,
  // затем (7031) нот: байт = период (биты 7-2) | ослабление (биты 1-0); 0 — конец эффекта
  AC6D(m, r) {
    r.hl = 0x702c; const f = rd(m, 0x702c);
    if (!(f & 0x80)) { r.zf = 1; return; }
    if (f & 0x40) return S.AC77(m, r);
    const n = (rd(m, 0x7032) + 1) & 0xff; wr(m, 0x7032, n); r.a = n; r.hl = 0x7030;
    if (n !== rd(m, 0x7030)) { r.zf = 0; return; }
    wr(m, 0x7032, 0); r.hl = 0x702c;
    if (f & 0x20) {
      wr(m, 0x702c, rd(m, 0x702c) & ~0x20);
      r.hl = rd16(m, 0x702e); r.a = (rd(m, r.hl) & 0x0f) | 0xd0; S['21C5'](m, r);
      r.a = ((r.a & 0xf0) >> 4) | 0xf0; S['21CA'](m, r);
      r.a = (rd(m, r.hl) & 0x0f) | 0x90; S['21C5'](m, r);
      r.a = ((r.a & 0xf0) >> 4) | 0xb0; S['21CA'](m, r);
      wr16(m, 0x702e, r.hl); r.a = 0xe3; r.hl = 0x7035; S['21CF'](m, r);
    }
    for (;;) {
      r.a = rd(m, 0x7033); r.hl = 0x7031;
      if (r.a === rd(m, 0x7031)) { wr(m, 0x7033, 0); r.a = 0; r.zf = 1; return; }
      const k = (r.a + 1) & 0xff; wr(m, 0x7033, k);
      r.hl = rd16(m, 0x702e); const v = rd(m, r.hl);
      if (!v) return S.AC77(m, r);
      wr(m, 0x7034, (v & 0xfc) >> 2); r.b = (v & 3) << 2;
      const x = k ^ 7; r.a = ((x >> 3) | (x << 5)) & 0xff | r.b;
      r.hl = (r.hl + 1) & 0xffff; wr16(m, 0x702e, r.hl); S['21D4'](m, r);
    }
  },
};
