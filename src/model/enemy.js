// Модель: враги A7A1 (список 7086: байт флагов + счётчик, спрайт 7300 + 4 * (номер & 7)).
// Флаги: бит 7 — направление, 6 — прыгающий (череп), 5 — на конвейере/цепи, 4 — без проверки стен,
// 3 — катящийся (кадры через 4), младшие — номер. Оригинал держит указатели на стеке (EX (SP),HL) —
// здесь тот же порядок через локальный стек st.
'use strict';
const { rd, wr } = require('./core');
const U = require('./vram');
const RM = require('./room');
const F = require('./frame');

const E = module.exports = {
  // A69F: 7097 += 1; CF := (7097 & 11h) = 0 (HL сохраняется)
  A69F(m, r) { const v = (rd(m, 0x7097) + 1) & 0xff; wr(m, 0x7097, v); r.a = v & 0x11; r.cf = r.a === 0; r.zf = 0; },
  // ABED: T — слово на вершине стека вызывающего: младшая тетрада (T+1) := 8, если была >= 8, иначе 0
  ABED(m, r, T) { const v = rd(m, T + 1); r.c = (v & 0x0f) >= 8 ? 8 : 0; r.a = ((v & 0xf0) + r.c) & 0xff; wr(m, T + 1, r.a); },
  A7A1(m, r) {
    const st = []; const top = () => st[st.length - 1];
    const ex = () => { const t = st.pop(); st.push(r.hl); r.hl = t; };
    let hl = 0x7086, c = 0, b = 0;
    const flip = (p) => wr(m, p, rd(m, p) ^ 0x80);
    for (;;) {
      r.hl = hl; r.a = rd(m, hl);
      if (r.a === 0xff) { r.zf = 1; return; }
      st.push(hl);
      r.a = (r.a & 7) << 2; r.hl = 0x7300; RM.A540(m, r);
      const spr = r.hl; U['9159'](m, r);
      r.a = rd(m, spr); r.hl = hl;                     // EX (SP),HL: вершина — спрайт
      st[st.length - 1] = spr;
      if (r.a < 0x15 || r.a >= 0xb8) flip(hl);
      let a = rd(m, hl); let L;                         // L — метка продолжения
      st.push(hl);                                       // стек: [спрайт, список]
      if (a & 0x40) L = 'A6B3';
      else {
        st.pop(); st.pop(); st.push(spr);
        const cp = spr + 3; if (rd(m, cp)) wr(m, cp, rd(m, 0x704a) ? 0x0e : 0x0f);
        if (a & 8) {
          const n = (rd(m, hl + 1) + 1) & 0xff; wr(m, hl + 1, n);
          if ((n & 0x0f) === 4) {
            wr(m, hl + 1, rd(m, hl + 1) & 0x80);
            const cc = rd(m, hl) & 0x80 ? 4 : 0xfc;
            let t = (rd(m, spr + 2) + cc) & 0xff; if (t === 0x2c) t = 0x0c; if (t === 0x08) t = 0x28; wr(m, spr + 2, t);
          }
        }
        L = 'A81D';
      }
      // стековые ветви: на входе в A82F/A81D/A84A — стек [спрайт], HL = список
      for (;;) {
        if (L === 'A6B3') {
          const d = hl + 1; let v = rd(m, d); const bb = v & 0x80; let x = ((v & 0x7f) - 1) & 0xff; if (x & 0x80) x = 5;
          x = (x + bb) & 0xff; wr(m, d, x);
          if (!(x & 0x7f)) {
            const p = spr + 3; if (rd(m, p)) wr(m, p, rd(m, 0x704a) ? 0x0e : 0x0c);
            wr(m, spr + 2, rd(m, spr + 2) ^ 0x1c);
          }
          if (rd(m, 0x705a) === 0x10 && rd(m, 0x705b) === 0x11) {
            st.pop();                                    // HL = список, стек [спрайт]
            if (rd(m, hl) & 0x20) { L = 'A71A'; continue; }
            E.A69F(m, r);
            if (r.cf || rd(m, 0x70ab) !== 2) { st.push(hl); L = 'A762'; continue; }
            E.ABED(m, r, top());
            wr(m, spr, rd(m, spr) + 2); wr(m, hl, rd(m, hl) | 0xa0);
            st.pop(); L = 'A88F'; break;
          }
          L = 'A762'; continue;
        }
        if (L === 'A71A') {
          if (rd(m, hl) & 0x80) { L = 'A73A'; continue; }
          wr(m, hl, rd(m, hl) & ~0x20); E.A69F(m, r);
          let dx = 8; if (!r.cf) { flip(hl); dx = 0xfe; }
          L = 'A72D'; r.a = dx; continue;
        }
        if (L === 'A72D') {                              // X += A, Y -= 7
          wr(m, spr + 1, rd(m, spr + 1) + r.a); wr(m, spr, rd(m, spr) + 0xf9);
          st.pop(); L = 'A88F'; break;
        }
        if (L === 'A73A') {
          c = 0xff; const y = rd(m, 0x705b);
          if (y === 0xe8 || y === 0x08) {
            E.A69F(m, r);
            if (!r.cf) { wr(m, hl, rd(m, hl) | 0x80); b = 0xfe; } else { wr(m, hl, rd(m, hl) & ~0x80); b = 8; }
            c = 0; wr(m, hl, rd(m, hl) & ~0x20);
          } else b = 0;
          L = 'A87F'; continue;
        }
        if (L === 'A762') {                              // стек [спрайт, список]
          if (rd(m, 0x7057) === 0x88 && rd(m, 0x7058) === 0x89 && rd(m, 0x70ab) === 2) {
            st.pop();
            if (rd(m, hl) & 0x20) { L = 'A78E'; continue; }
            E.A69F(m, r);
            if (r.cf) { st.push(hl); L = 'A796'; continue; }
            E.ABED(m, r, top());
            wr(m, hl, (rd(m, hl) & ~0x80) | 0x20); r.a = 0; L = 'A72D'; continue;
          }
          L = 'A796'; continue;
        }
        if (L === 'A78E') {
          if (rd(m, hl) & 0x80) { L = 'A73A'; continue; }
          c = 1; b = 0; L = 'A87F'; continue;
        }
        if (L === 'A796') {
          st.pop(); c = 0; b = 0;
          if (rd(m, hl) & 0x20) { L = 'A78E'; continue; }
          L = 'A82F'; continue;
        }
        if (L === 'A81D') {
          if (rd(m, hl) & 0x10) { const x = rd(m, 0x7085); L = x < 8 || x >= 0xf5 ? 'A846' : 'A84A'; continue; }
          L = 'A82F'; continue;
        }
        if (L === 'A82F') {
          if (!rd(m, 0x705b)) { L = 'A846'; continue; }
          r.a = rd(m, rd(m, hl) & 0x80 ? 0x7057 : 0x7059); F.A894(m, r);
          L = r.zf ? 'A846' : 'A84A'; continue;
        }
        if (L === 'A846') { flip(hl); L = 'A84A'; continue; }
        if (L === 'A84A') {
          c = 0;
          if (!(rd(m, hl) & 8)) {
            let x = ((rd(m, hl + 1) & 0x7f) - 1) & 0xff; if (x & 0x80) x = 0x39;
            wr(m, hl + 1, x); c = rd(m, 0xabb3 + x);
          }
          const a7 = rd(m, hl) & 0x80; b = a7 ? 0xff : 1;
          if (rd(m, hl + 1) & 0x80) b = (b + b) & 0xff;
          L = 'A87F'; continue;
        }
        if (L === 'A87F') {                              // стек [список], HL = спрайт
          wr(m, spr, rd(m, spr) - c); const x = (rd(m, spr + 1) + b) & 0xff; wr(m, spr + 1, x);
          st.pop(); if (x < 8) flip(hl);
          L = 'A88F'; break;
        }
        throw new Error('A7A1: метка ' + L);
      }
      hl += 2;
    }
  },
};
