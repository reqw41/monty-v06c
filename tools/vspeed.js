#!/usr/bin/env node
// Скорость игры на Векторе: итераций главного цикла (A5D1) в секунду при 50 Гц за 2000 кадров игры
// (старт уровня 1, ходьба вправо-влево), и доля прерываний (сколько кадров обработчик пропустил).
'use strict';
const fs = require('fs');
const E = require('./vec_emu');
const sym = {};
for (const l of fs.readFileSync('build/vec/monty.sym', 'latin1').split('\n')) {
  const m = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (m) sym[m[1]] = parseInt(m[2], 16);
}
const m = E.mk('build/vec/monty.bin'); let st = false, t = 0, t0 = 0, i0 = 0;
m.onInstr = (pc) => { if (pc === sym.L_A59D) st = true; if (st && pc === sym.L_A5D1) t++; };
const K = (r, b, d) => { if (d) m.keyboard.matrix[r] |= b; else m.keyboard.matrix[r] &= ~b; };
for (let f = 0; f < 3000; f++) {
  if (f === 300) K(2, 2, 1); if (f === 320) K(2, 2, 0); if (f === 700) K(7, 0x80, 1); if (f === 710) K(7, 0x80, 0);
  if (f >= 1000 && f % 200 === 0) { K(0, 0x40, 1); K(0, 0x10, 0); } if (f >= 1000 && f % 200 === 100) { K(0, 0x40, 0); K(0, 0x10, 1); }
  if (f === 1000) { t0 = t; i0 = m.rd(sym.frames) | m.rd(sym.frames + 1) << 8; }
  m.frame();
}
const isr = (m.rd(sym.frames) | m.rd(sym.frames + 1) << 8) - i0;
console.log(`итераций/с: ${((t - t0) / 2000 * 50).toFixed(1)} (MSX: 60), прерываний обработано: ${isr} из 2000`);
