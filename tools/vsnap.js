#!/usr/bin/env node
// Снимок VRAM и ОЗУ модели MSX на первой итерации главного цикла (A5D1) уровня 1 -> build/native/vram.bin
// (16 КБ VRAM), на входе в начало уровня A59D — ram0/vram0/vreg0.bin; build/native/ram.bin (7000-73FF), build/native/vreg.bin (8 регистров VDP). Для tools/mknative.py.
'use strict';
const fs = require('fs');
const MSX1 = require('./msx1');
const m = new MSX1().loadSnap('entry'); m.coop = new Set([0xA5CA, 0x8C19, 0xA5D8]);
const ev = { 30: [1, 1], 48: [1, 0] }; let st = false, f = 0, done = false;
while (!done && f < 3000) {
  if (ev[f]) m.key(ev[f][0], ev[f][1]);
  const end = m.frames + 1;
  while (m.frames < end && !done) { const pc = m.pc; if (pc === 0xa59d && !st) { st = true; fs.mkdirSync('build/native', { recursive: true }); fs.writeFileSync('build/native/ram0.bin', Buffer.from(m.mem.subarray(0x7000, 0x7400))); fs.writeFileSync('build/native/vram0.bin', Buffer.from(m.vram)); fs.writeFileSync('build/native/vreg0.bin', Buffer.from(m.vreg)); } if (st && pc === 0xa5d1) done = true; else m.step(); }
  f++;
}
fs.mkdirSync('build/native', { recursive: true });
fs.writeFileSync('build/native/vram.bin', Buffer.from(m.vram));
fs.writeFileSync('build/native/ram.bin', Buffer.from(m.mem.subarray(0x7000, 0x7400)));
fs.writeFileSync('build/native/vreg.bin', Buffer.from(m.vreg));
console.log('снимок на A5D1, кадр', f, 'R4', m.vreg[4], 'R1', m.vreg[1].toString(16));
