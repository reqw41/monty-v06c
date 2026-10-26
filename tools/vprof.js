#!/usr/bin/env node
// Профиль по меткам: node tools/vprof.js <с кадра> <по кадр> "<план клавиш>" — доля команд по ближайшей метке
'use strict';
const fs = require('fs');
const E = require('./vec_emu');
const sym = {};
for (const l of fs.readFileSync('build/vec/monty.sym', 'latin1').split('\n')) {
  const m = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (m) sym[m[1]] = parseInt(m[2], 16);
}
const inv = Object.entries(sym).filter(([k, v]) => v < 0x7000 && !/^(L_|D_)/.test(k) || /^L_/.test(k)).sort((a, b) => a[1] - b[1]);
const near = new Array(0x7000).fill('?');
for (let i = 0, j = 0; i < 0x7000; i++) { while (j + 1 < inv.length && inv[j + 1][1] <= i) j++; if (inv[j] && inv[j][1] <= i) near[i] = inv[j][0]; }
const KEYS = { left: [0, 0x10], up: [0, 0x20], right: [0, 0x40], down: [0, 0x80], space: [7, 0x80], 1: [2, 0x02], 2: [2, 0x04], 3: [2, 0x08] };
const [A, B, PLAN] = process.argv.slice(2);
const plan = {};
for (const it of (PLAN || '').split(/\s+/).filter(Boolean)) {
  const mm = it.match(/^(\d+):(\w+)([+-])$/); (plan[+mm[1]] = plan[+mm[1]] || []).push([mm[2], mm[3] === '+']);
}
const m = E.mk('build/vec/monty.bin');
const h = new Map(); let n = 0;
for (let f = 0; f < +B; f++) {
  for (const [k, d] of plan[f] || []) { const e = KEYS[k]; if (d) m.keyboard.matrix[e[0]] |= e[1]; else m.keyboard.matrix[e[0]] &= ~e[1]; }
  if (f === +A) m.onInstr = (pc) => { const k = pc < 0x7000 ? near[pc] : 'вне'; h.set(k, (h.get(k) || 0) + 1); n++; };
  m.frame();
}
console.log([...h].sort((a, b) => b[1] - a[1]).slice(0, 25).map(([k, v]) => `${k} ${(100 * v / n).toFixed(1)}%`).join('\n'));
