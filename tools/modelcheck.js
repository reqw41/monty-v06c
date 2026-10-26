#!/usr/bin/env node
// Сверка JS-модели: две модели MSX (coop) с одинаковым вводом — без подмен и с подменами процедур из
// src/model/hooks.js; сравнение по итерациям главного цикла (A5D1): ОЗУ 7000-733F (без буфера OS7 7210-723F),
// таблица имён, цвета, атрибуты спрайтов (VRAM 1B00-1B7F). Первое расхождение — печать.
//   node tools/modelcheck.js [итераций] [уровень] ["план тик:клавиша+/-"] [список подмен через запятую]
'use strict';
const MSX1 = require('./msx1');
const HOOKS = require('../src/model/hooks');
const N = +(process.argv[2] || 600), LV = +(process.argv[3] || 1), PLAN = process.argv[4] || '', ONLY = process.argv[5];
const plan = { 120: [['space', true]], 128: [['space', false]] };
for (const it of PLAN.split(/\s+/).filter(Boolean)) { const mm = it.match(/^(\d+):(\w+)([+-])$/); (plan[+mm[1]] = plan[+mm[1]] || []).push([mm[2], mm[3] === '+']); }
const K = { space: 0x40, left: 0x44, up: 0x45, down: 0x46, right: 0x47 };
const CHEAT = process.env.CHEAT === '1';
function run(hooks) {
  const m = new MSX1().loadSnap('entry'); m.coop = new Set([0xA5CA, 0x8C19]);
  if (hooks) m.hooks = hooks;
  const out = []; let st = false, t = -1, f = 0; const ev = { 30: [LV, 1], 48: [LV, 0] };
  while (out.length < N && f < 40000) {
    if (ev[f]) m.key(ev[f][0], ev[f][1]);
    const end = m.frames + 1;
    while (m.frames < end && out.length < N) {
      const pc = m.pc;
      if (pc === 0xa59d) st = true;
      if (st && pc === 0xa5d1) {
        t++; if (CHEAT) m.mem[0x7049] = 6;
        for (const [k, d] of plan[t] || []) m.key(K[k], d);
        out.push(Buffer.concat([Buffer.from(m.mem.subarray(0x7000, 0x7340)), Buffer.from(m.vram.subarray(0x1800, 0x1b80)), Buffer.from(m.vram.subarray(0x2000, 0x2020))]));
      }
      m.step();
    }
    f++;
  }
  return out;
}
const hits = {};
const hooks = new Map(Object.entries(HOOKS).filter(([k]) => !ONLY || ONLY.split(',').includes(k)).map(([k, fn]) => [parseInt(k, 16), (m) => { hits[k] = (hits[k] || 0) + 1; return fn(m); }]));
const A = run(null), B = run(hooks);
console.log('итераций', A.length, B.length, '| вызовов подмен:', Object.entries(hits).map(([k, v]) => k + ':' + v).join(' '));
const name = (i) => i < 0x340 ? (0x7000 + i).toString(16) : i < 0x340 + 0x300 ? 'NT' + (i - 0x340).toString(16) : i < 0x340 + 0x380 ? 'SAT' + (i - 0x640).toString(16) : 'COL' + (i - 0x6c0).toString(16);
for (let k = 0; k < Math.min(A.length, B.length); k++) {
  const d = []; for (let i = 0; i < A[k].length; i++) { if (i >= 0x210 && i < 0x240) continue; if (A[k][i] !== B[k][i]) d.push(i); }
  if (d.length) { console.log(`итерация ${k}: ${d.length} байт:`, d.slice(0, 14).map((i) => `${name(i)}=${A[k][i].toString(16)}/${B[k][i].toString(16)}`).join(' ')); process.exit(1); }
}
console.log('совпадение по всем итерациям');
