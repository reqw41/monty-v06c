#!/usr/bin/env node
// Диагностика игры на Векторе: на каком кадре впервые исполнены заданные метки, сколько прерываний,
// флаги вывода. node tools/vtrace.js <кадров> "<план клавиш как в vshot>" метка1,метка2,...
'use strict';
const fs = require('fs');
const E = require('./vec_emu');
const sym = {};
for (const l of fs.readFileSync('build/vec/monty.sym', 'latin1').split('\n')) {
  const m = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (m) sym[m[1]] = parseInt(m[2], 16);
}
const KEYS = { left: [0, 0x10], up: [0, 0x20], right: [0, 0x40], down: [0, 0x80], space: [7, 0x80], 1: [2, 0x02], 2: [2, 0x04], 3: [2, 0x08] };
const [NS, PLAN, LABS] = process.argv.slice(2);
const plan = {};
for (const it of (PLAN || '').split(/\s+/).filter(Boolean)) {
  const mm = it.match(/^(\d+):(\w+)([+-])$/); (plan[+mm[1]] = plan[+mm[1]] || []).push([mm[2], mm[3] === '+']);
}
const want = new Map((LABS || '').split(',').filter(Boolean).map((n) => [sym[n], n]));
const seen = {};
const m = E.mk('build/vec/monty.bin');
let f = 0;
m.onInstr = (pc) => { const n = want.get(pc); if (n !== undefined && !(n in seen)) seen[n] = f; };
for (; f < +NS; f++) {
  for (const [k, d] of plan[f] || []) { const e = KEYS[k]; if (d) m.keyboard.matrix[e[0]] |= e[1]; else m.keyboard.matrix[e[0]] &= ~e[1]; }
  m.frame();
  if (f % 500 === 499) console.log('кадр', f + 1, 'прерываний', m.rd(sym.frames) | m.rd(sym.frames + 1) << 8, 'R1', m.rd(sym.vregs + 1).toString(16), 'vdirty', m.rd(sym.vdirty).toString(16), 'nt_age', m.rd(sym.nt_age));
}
console.log('первые исполнения:', JSON.stringify(seen));
