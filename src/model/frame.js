// Модель: обработчик кадра A9B3 (NMI), смена банков шаблонов A92F/A97A, мигание лазеров A8D6.
'use strict';
const { rd, wr, rd16, wr16, z } = require('./core');
const V = require('./vdp');
const U = require('./vram');
const S = require('./sound');
const RM = require('./room');

const F = module.exports = {
  // A894: Z — A есть среди 8 байт 943C (HL, BC сохраняются)
  A894(m, r) { r.zf = 0; for (let i = 0; i < 8; i++) if (rd(m, 0x943c + i) === r.a) { r.zf = 1; break; } },
  // A9A0: шаблон (HL + A) — 1 байт в таблицу 3 (шаблоны), номер DE
  A9A0(m, r) { RM.A540(m, r); r.iy = 1; r.a = 3; U.AE2E(m, r); },
  // A97A: R4 := A/8 (банк C), в банк — кадр анимации тайлов E0/E8 (7096)
  A97A(m, r) {
    wr(m, 0x73f9, r.a); r.b = 4; V['1FD9'](m, r);
    const f = rd(m, 0x7096);
    r.a = (f << 1) & 0xff; r.hl = 0x85bc; r.de = 0xe0; F.A9A0(m, r);
    r.hl = 0x85ca; r.de = 0xe8; r.a = (f & 1) << 3; F.A9A0(m, r);
  },
  // A92F: кадр анимации во все 4 банка (0, 1, 2, 5), затем прежний банк
  A92F(m, r) {
    U.A8B7(m, r); wr(m, 0x7085, rd(m, 0x73f9));
    for (const [c, a] of [[0, 0], [1, 8], [2, 0x10], [5, 0x28]]) { r.c = c; r.a = a; F.A97A(m, r); }
    r.a = rd(m, 0x7085);
    if (r.a === 0) r.c = 0; if (r.a === 8) r.c = 1; if (r.a === 0x10) r.c = 2; if (r.a === 0x28) r.c = 5;
    wr(m, 0x73f9, r.a); r.b = 4; V['1FD9'](m, r); U.A8C3(m, r);
  },
  // A905: цвет группы E (1 байт из HL)
  A905(m, r) { r.iy = 1; r.a = 4; U.AE2E(m, r); },
  // A8D6 LASERS: таймер 70A8 (60h..1); 60h — включить обе группы (1D, 1C), 48h/30h — выключить
  A8D6(m, r) {
    let a = (rd(m, 0x70a8) - 1) & 0xff; if (!a) a = 0x60; wr(m, 0x70a8, a);
    if (a === 0x60) { wr(m, 0x7000, rd(m, 0x7000) | 0x40); r.hl = 0xabcd; r.de = 0x1d; F.A905(m, r); }
    else if (a === 0x48) { wr(m, 0x7000, rd(m, 0x7000) & ~0x40); r.hl = 0xa92e; r.de = 0x1d; F.A905(m, r); }
    a = rd(m, 0x70a8);
    if (a === 0x60) { wr(m, 0x7000, rd(m, 0x7000) | 0x20); r.hl = 0xabcd; r.de = 0x1c; F.A905(m, r); return; }
    r.a = a;
    if (a !== 0x30) { r.zf = 0; return; }
    wr(m, 0x7000, rd(m, 0x7000) & ~0x20); r.hl = 0xa92e; r.de = 0x1c; F.A905(m, r);
  },
  // A9B3 NMI: раз в кадр (не вложенно, 70B1 бит 7): 919A, A60B, 8EB0 по флагам; при выводе (705F бит 1)
  // только опрос VDP; иначе счётчики, смена кадра анимации раз в 2 кадра по циклу банков, спрайты, звук
  A9B3(m, r) {
    const sv = Object.assign({}, r);
    if (rd(m, 0x70b1) & 0x80) return;
    wr(m, 0x70b1, rd(m, 0x70b1) | 0x80);
    if (rd(m, 0x70b1) & 8) { wr(m, 0x70b1, rd(m, 0x70b1) & ~8); z(m, r, 0x919a); }
    const f = rd(m, 0x705f);
    if (!(f & 2)) {
      if (f & 8) z(m, r, 0xa60b);
      if (rd(m, 0x70b1) & 0x10) { wr(m, 0x70b1, rd(m, 0x70b1) & ~0x10); z(m, r, 0x8eb0); }
      wr(m, 0x7097, rd(m, 0x7097) + 1); wr16(m, 0x7047, rd16(m, 0x7047) + 1);
      const a = (rd(m, 0x7011) + 1) & 0xff;
      if (!(a & 0x80)) {
        wr(m, 0x7011, a);
        const t = { 1: [0, 0], 2: [1, 8], 3: [2, 0x10], 4: [5, 0x28] }[a];
        if (t) {
          if (a === 4) wr(m, 0x7011, 0);
          r.bc = 0x0400 | t[0]; r.a = t[1]; wr(m, 0x73f9, r.a); F.A92F(m, r);
          wr(m, 0x7011, rd(m, 0x7011) ^ 0x80);
        }
      }
      wr(m, 0x7207, rd(m, 0x7207) - 1); r.a = 8; V['1FC4'](m, r); S.AC6D(m, r);
    }
    V['1FDC'](m, r); wr(m, 0x70b1, rd(m, 0x70b1) & ~0x80);
    Object.assign(r, sv);
  },
};
