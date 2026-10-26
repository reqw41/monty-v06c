// Модель: функции BIOS OS7 для VDP (подмены по таблице переходов 1F61-1FFF). Регистры на выходе — как у OS7.
'use strict';
const { rd, wr, rd16 } = require('./core');

// адрес элемента таблицы (1BAA): база (73F2 + 2t) + элемент << сдвиг; 73FE := число байт; IX, IY — как в OS7
function tabAddr(m, r, t) {
  let item = r.de, cnt = r.iy;
  wr(m, 0x73fe, cnt & 0xff); wr(m, 0x73ff, cnt >> 8);
  if (!(t === 4 && !(rd(m, 0x73c3) & 2))) {
    r.iy = 0x1bff + t;
    const sh = rd(m, r.iy);
    item = (item << sh) & 0xffff; cnt = (cnt << sh) & 0xffff;
    wr(m, 0x73fe, cnt & 0xff); wr(m, 0x73ff, cnt >> 8);
  }
  r.ix = 0x73f2 + 2 * t;
  return { addr: (rd16(m, r.ix) + item) & 0xffff, cnt };
}

const V = module.exports = {
  // 1FBE PUT_VRAM: A = таблица, DE = элемент, HL = источник, IY = число
  '1FBE'(m, r) {
    const t = r.a;
    if (t === 0 && rd(m, 0x73c7) === 1) {     // атрибуты спрайтов — в копию ОЗУ (8002) = 7300
      const dst = (rd16(m, 0x8002) + ((r.e << 2) & 0xff)) & 0xffff, n = (r.iy << 2) & 0xffff;
      for (let i = 0; i < n; i++) wr(m, dst + i, rd(m, r.hl + i));
      r.a = n & 0xff; r.hl = (r.hl + n) & 0xffff; r.de = (dst + n) & 0xffff; r.bc = 0;
      return;
    }
    const { addr, cnt } = tabAddr(m, r, t);
    for (let i = 0; i < cnt; i++) m.vram[(addr + i) & 0x3fff] = rd(m, r.hl + i);
    m.vaddr = (addr + cnt) & 0x3fff;
    r.a = ((addr + 0x4000) >> 8) & 0xff; r.hl = (r.hl + cnt) & 0xffff; r.d = 0xff; r.e = cnt & 0xff; r.b = 0; r.c = 0x98;
  },
  // 1FBB GET_VRAM
  '1FBB'(m, r) {
    const { addr, cnt } = tabAddr(m, r, r.a);
    for (let i = 0; i < cnt; i++) wr(m, r.hl + i, m.vram[(addr + i) & 0x3fff]);
    m.vaddr = (addr + cnt) & 0x3fff;
    r.a = (addr >> 8) & 0xff; r.hl = (r.hl + cnt) & 0xffff; r.d = 0xff; r.e = cnt & 0xff; r.b = 0; r.c = 0x98;
  },
  // 1F82 FILL_VRAM: HL = адрес, DE = число, A = байт; выход: DE = 0, C = байт, A = статус (сброс флага кадра)
  '1F82'(m, r) {
    const v = r.a;
    for (let i = 0; i < r.de; i++) m.vram[(r.hl + i) & 0x3fff] = v;
    m.vaddr = (r.hl + r.de) & 0x3fff;
    r.c = v; r.de = 0; r.a = m.vstat; m.vstat &= 0x1f;
  },
  // 1FD9 WRITE_REGISTER: B = регистр, C = значение
  '1FD9'(m, r) {
    m.vreg[r.b & 7] = r.c;
    r.a = r.b;
    if (r.b === 0) { wr(m, 0x73c3, r.c); r.a = 0; } else if (r.b === 1) { wr(m, 0x73c4, r.c); r.a = r.c; }
  },
  // 1FDC READ_REGISTER
  '1FDC'(m, r) { r.a = m.vstat; m.vstat &= 0x1f; },
  // 1FC4 WR_SPR_NM_TBL: A спрайтов из 7300 в порядке (8004) = 72E0 в таблицу 0 VDP
  '1FC4'(m, r) {
    const n = r.a, ord = rd16(m, 0x8004), base = rd16(m, 0x73f2), sat = rd16(m, 0x8002);
    let hl = 0;
    for (let i = 0; i < n; i++) { const k = rd(m, ord + i); hl = (sat + 4 * k) & 0xffff; for (let j = 0; j < 4; j++) m.vram[(base + 4 * i + j) & 0x3fff] = rd(m, hl + j); hl += 4; }
    m.vaddr = (base + 4 * n) & 0x3fff;
    r.a = 0; r.b = 0; r.c = 0x98; r.de = base; r.hl = hl & 0xffff; r.ix = (ord + n) & 0xffff; r.iy = 0x73f2;
  },
  // 1FC1 INIT_SPR_ORDER: (8004)[i] := i, i < A
  '1FC1'(m, r) {
    const n = r.a, p = rd16(m, 0x8004);
    for (let i = 0; i < n; i++) wr(m, p + i, i);
    r.b = n; r.a = n; r.hl = (p + n) & 0xffff;
  },
};
