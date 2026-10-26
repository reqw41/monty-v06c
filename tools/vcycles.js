#!/usr/bin/env node
// Команды (≈ такты / 9) по процедурам вывода за кадр: вход/выход (по паре адрес входа -> ret на ту же глубину стека).
//   node tools/vcycles.js <с кадра> <по кадр> proc1,proc2,... "<план клавиш>"
'use strict';
const fs = require('fs');
const E = require('./vec_emu');
const sym = {};
for (const l of fs.readFileSync('build/vec/monty.sym', 'latin1').split('\n')) {
  const m = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (m) sym[m[1]] = parseInt(m[2], 16);
}
const KEYS = { left: [0, 0x10], up: [0, 0x20], right: [0, 0x40], down: [0, 0x80], space: [7, 0x80], 1: [2, 0x02], 2: [2, 0x04], 3: [2, 0x08] };
const [A, B, PROCS, PLAN] = process.argv.slice(2);
const plan = {};
for (const it of (PLAN || '').split(/\s+/).filter(Boolean)) { const mm = it.match(/^(\d+):(\w+)([+-])$/); (plan[+mm[1]] = plan[+mm[1]] || []).push([mm[2], mm[3] === '+']); }
const procs = PROCS.split(',');
const ent = new Map(procs.map((p) => [sym[p], p]));
const tot = {}, cnt = {}; const open = [];
const m = E.mk('build/vec/monty.bin');
let on = false, icount = 0;
m.onInstr = (pc) => {
  if (!on) return;
  const t = ++icount;
  const p = ent.get(pc);
  if (p) open.push([p, m.cpu.sp, t]);
  while (open.length && m.cpu.sp > open[open.length - 1][1]) { const [q, , t0] = open.pop(); tot[q] = (tot[q] || 0) + (t - t0); cnt[q] = (cnt[q] || 0) + 1; }
};
for (let f = 0; f < +B; f++) {
  for (const [k, d] of plan[f] || []) { const e = KEYS[k]; if (d) m.keyboard.matrix[e[0]] |= e[1]; else m.keyboard.matrix[e[0]] &= ~e[1]; }
  if (f === +A) on = true;
  m.frame();
}
const fr = +B - +A;
for (const p of procs) console.log(p.padEnd(14), 'вызовов', String(cnt[p] || 0).padStart(5), 'команд на кадр', Math.round((tot[p] || 0) / fr), 'на вызов', cnt[p] ? Math.round(tot[p] / cnt[p]) : 0);
