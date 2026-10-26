#!/usr/bin/env node
// Разбор итераций главного цикла (A5D1 -> A5D1) на Векторе: команд всего, в выводе (display), в прерывании.
'use strict';
const fs = require('fs');
const E = require('./vec_emu');
const sym = {};
for (const l of fs.readFileSync('build/vec/monty.sym', 'latin1').split('\n')) {
  const m = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (m) sym[m[1]] = parseInt(m[2], 16);
}
const m = E.mk('build/vec/monty.bin'); const K = (r, b, d) => { if (d) m.keyboard.matrix[r] |= b; else m.keyboard.matrix[r] &= ~b; };
let on = false, n = 0, last = 0, dsp = 0, isrc = 0, depthD = -1, depthI = -1, wait = 0; const it = [];
m.onInstr = (pc) => {
  if (!on) return; n++;
  if (pc === sym.display && depthD < 0) depthD = m.cpu.sp;
  if (depthD >= 0) { dsp++; if (m.cpu.sp > depthD) depthD = -1; }
  if (pc === 0x38) depthI = m.cpu.sp; if (depthI >= 0) { isrc++; if (m.cpu.sp > depthI + 2) depthI = -1; }
  if (pc === sym.nmi_wait_a5ca || pc === sym.nmi_wait_8c19) wait++;
  if (pc === sym.L_A5D1) { it.push([n - last, dsp, isrc, wait]); last = n; dsp = 0; isrc = 0; wait = 0; }
};
for (let f = 0; f < 1500; f++) {
  if (f === 300) K(2, 2, 1); if (f === 320) K(2, 2, 0); if (f === 700) K(7, 0x80, 1); if (f === 710) K(7, 0x80, 0);
  if (f >= 1000 && f % 100 === 0) K(0, 0x40, f % 200 === 0); if (f === 1000) on = true; m.frame();
}
const a = it.slice(2); const avg = (k) => Math.round(a.reduce((s, x) => s + x[k], 0) / a.length);
console.log('итераций', a.length, 'команд на итерацию', avg(0), 'вывод', avg(1), 'прерывание', avg(2), 'проверок ожидания', avg(3));
console.log('по итерациям (всего/вывод/ожидание):', a.slice(0, 24).map((x) => x[0] + '/' + x[1] + '/' + x[3]).join(' '));
