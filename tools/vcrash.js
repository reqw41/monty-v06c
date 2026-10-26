#!/usr/bin/env node
// Поиск сбоя: первый PC вне кода (code_end..DFFF) или повторный вход в boot; печать хвоста трассы.
//   node tools/vcrash.js <кадров> "<план клавиш>"
'use strict';
const fs = require('fs');
const E = require('./vec_emu');
const sym = {};
for (const l of fs.readFileSync('build/vec/monty.sym', 'latin1').split('\n')) {
  const m = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (m) sym[m[1]] = parseInt(m[2], 16);
}
const inv = Object.entries(sym).filter(([k, v]) => v < 0x7000 && v >= 0x100).sort((a, b) => a[1] - b[1]);
const near = (pc) => { let b = null; for (const [k, v] of inv) { if (v <= pc) b = [k, v]; } return b ? b[0] + '+' + (pc - b[1]).toString(16) : pc.toString(16); };
const KEYS = { left: [0, 0x10], up: [0, 0x20], right: [0, 0x40], down: [0, 0x80], space: [7, 0x80], 1: [2, 0x02], 2: [2, 0x04], 3: [2, 0x08] };
const [NS, PLAN] = process.argv.slice(2);
const plan = {};
for (const it of (PLAN || '').split(/\s+/).filter(Boolean)) {
  const mm = it.match(/^(\d+):(\w+)([+-])$/); (plan[+mm[1]] = plan[+mm[1]] || []).push([mm[2], mm[3] === '+']);
}
const m = E.mk('build/vec/monty.bin');
const ring = []; let f = 0, hit = null;
m.onInstr = (pc) => {
  ring.push([pc, m.cpu.sp]); if (ring.length > 40) ring.shift();
  if (!hit && ((pc >= sym.code_end && pc < 0xE000) || (f > 5 && pc === sym.boot))) hit = { f, trail: ring.slice() };
};
for (; f < +NS && !hit; f++) {
  for (const [k, d] of plan[f] || []) { const e = KEYS[k]; if (d) m.keyboard.matrix[e[0]] |= e[1]; else m.keyboard.matrix[e[0]] &= ~e[1]; }
  m.frame();
}
if (!hit) { console.log('сбоя нет'); process.exit(0); }
console.log('кадр', hit.f); console.log(hit.trail.map(([p, s]) => near(p) + '(' + s.toString(16) + ')').join('\n'));
