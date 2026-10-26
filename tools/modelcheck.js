#!/usr/bin/env node
// Сверка JS-модели: две модели MSX (coop) с одинаковым вводом — без подмен и с подменами процедур из
// src/model/hooks.js; сравнение по итерациям главного цикла (A5D1): ОЗУ 7000-733F (без буфера OS7 7210-723F),
// таблица имён, цвета, атрибуты спрайтов (VRAM 1B00-1B7F). Первое расхождение — печать.
//   node tools/modelcheck.js [итераций] [уровень] ["план тик:клавиша+/- тик:tpРЯД.СТОЛБЕЦ"] [список подмен через запятую]
'use strict';
const MSX1 = require('./msx1');
const HOOKS = require('../src/model/hooks');
const N = +(process.argv[2] || 600), LV = +(process.argv[3] || 1), PLAN = process.argv[4] || '', ONLY = process.argv[5];
const plan = { 120: [['space', true]], 128: [['space', false]] };
for (const it of PLAN.split(/\s+/).filter(Boolean)) {
  const ob = it.match(/^(\d+):obj(\d+)([+-]\d+)?$/); if (ob) { (plan[+ob[1]] = plan[+ob[1]] || []).push(['obj', +ob[2], +(ob[3] || 0)]); continue; }
  const tp = it.match(/^(\d+):tp(\d+)\.(\d+)$/); if (tp) { (plan[+tp[1]] = plan[+tp[1]] || []).push(['tp', +tp[2], +tp[3]]); continue; }
  const mm = it.match(/^(\d+):(\w+)([+-])$/); (plan[+mm[1]] = plan[+mm[1]] || []).push([mm[2], mm[3] === '+']); }
if (process.env.RND) {                                     // случайный ввод: каждые 6-30 итераций — смена клавиш
  let x = +process.env.RND || 1; const rnd = (n) => { x = (x * 1103515245 + 12345) & 0x7fffffff; return x % n; };
  const keys = ['left', 'right', 'up', 'down', 'space'];
  for (let t = 200; t < N; t += 6 + rnd(25)) for (const k of keys) (plan[t] = plan[t] || []).push([k, rnd(3) === 0]);
}
for (const it of (process.env.SET || '').split(/\s+/).filter(Boolean)) {   // SET="тик:адрес=знач,адрес=знач"
  const [t, kv] = it.split(':'); (plan[+t] = plan[+t] || []).push(['set', kv.split(',').map((x) => x.split('=').map((y) => parseInt(y, 16)))]);
}
const K = { space: 0x40, left: 0x44, up: 0x45, down: 0x46, right: 0x47 };
const CHEAT = process.env.CHEAT === '1';
function run(hooks) {
  const m = new MSX1().loadSnap('entry'); m.coop = new Set([0xA5CA, 0x8C19]); if (!hooks && process.env.COV) m.cov = COVS;
  const out = []; let st = false, t = -1, f = 0; const ev = { 30: [LV, 1], 48: [LV, 0] };
  while (out.length < N && f < 40000) {
    if (ev[f]) m.key(ev[f][0], ev[f][1]);
    const end = m.frames + 1;
    while (m.frames < end && out.length < N) {
      const pc = m.pc;
      if (pc === 0xa59d && !st) { st = true; if (hooks) m.hooks = hooks; }   // подмены — с начала игры (меню Muffie зависит от времени)
      if (st && pc === 0xa5d1) {
        t++; if (CHEAT) m.mem[0x7049] = 6;
        for (const [k, d, c] of plan[t] || []) if (k === 'obj') {          // герой на объект d списка 72C0 (тайл 7058 = клетка объекта, столбец + c)
          const lo = m.mem[0x72c0 + 2 * d], hi = m.mem[0x72c1 + 2 * d]; if (hi === 0xff || hi === 0xfe || (lo | hi) === 0) continue;
          const off = (hi << 8 | lo) & 0x3ff, y = 8 * (off >> 5) - 2, x = 8 * ((off & 31) + c) - 1;
          m.mem[0x7300] = m.mem[0x7304] = y & 0xff; m.mem[0x7301] = m.mem[0x7305] = x & 0xff;
        } else if (k === 'set') { for (const [a, v] of d) m.mem[a] = v; } else if (k === 'tp') { m.mem[0x71a7] = d; m.mem[0x71a8] = c; m.mem[0x7079] = 9; } else m.key(K[k], d);
        out.push(Buffer.concat([Buffer.from(m.mem.subarray(0x7000, 0x7340)), Buffer.from(m.vram.subarray(0x1800, 0x1b80)), Buffer.from(m.vram.subarray(0x2000, 0x2020)), Buffer.from(m.psg.subarray(0, 11)), Buffer.from(m.mem.subarray(0x20f7, 0x20fb))]));
      }
      m.step();
    }
    f++;
  }
  return out;
}
const COVS = new Set();
const hits = {};
const hooks = new Map(Object.entries(HOOKS).filter(([k]) => !ONLY || ONLY.split(',').includes(k)).map(([k, fn]) => [parseInt(k, 16), (m) => { hits[k] = (hits[k] || 0) + 1; return fn(m); }]));
const A = run(null), B = run(hooks);
console.log('итераций', A.length, B.length, '| вызовов подмен:', Object.entries(hits).map(([k, v]) => k + ':' + v).join(' '));
const name = (i) => i < 0x340 ? (0x7000 + i).toString(16) : i < 0x340 + 0x300 ? 'NT' + (i - 0x340).toString(16) : i < 0x340 + 0x380 ? 'SAT' + (i - 0x640).toString(16) : i < 0x6e0 ? 'COL' + (i - 0x6c0).toString(16) : i < 0x6eb ? 'PSG' + (i - 0x6e0) : 'SNV' + (0x20f7 + i - 0x6eb).toString(16);
for (let k = 0; k < Math.min(A.length, B.length); k++) {
  const d = []; for (let i = 0; i < A[k].length; i++) { if (i >= 0x210 && i < 0x240) continue; if (A[k][i] !== B[k][i]) d.push(i); }
  if (d.length) { console.log(`итерация ${k}: ${d.length} байт:`, d.slice(0, 14).map((i) => `${name(i)}=${A[k][i].toString(16)}/${B[k][i].toString(16)}`).join(' ')); process.exit(1); }
}
console.log('совпадение по всем итерациям');
if (process.env.COV) {                                     // COV=A6B3-A894: не исполненные в эталоне инструкции диапазона
  const [lo, hi] = process.env.COV.split('-').map((x) => parseInt(x, 16));
  const ins = require('fs').readFileSync(__dirname + '/../build/monty.skool', 'utf8').split('\n').map((l) => l.match(/^[ *c]\$([0-9A-F]{4}) /)).filter(Boolean).map((x) => parseInt(x[1], 16)).filter((a) => a >= lo && a < hi);
  const miss = ins.filter((a) => !COVS.has(a)); console.log(`покрытие ${ins.length - miss.length}/${ins.length}; нет:`, miss.map((a) => a.toString(16)).join(' '));
}
