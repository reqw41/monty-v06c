#!/usr/bin/env node
// Сверка JS-игры без процессора (src/opt) с моделью MSX в coop: эталон — MSX без подмен; JS-игра стартует
// со снимка эталона на первой итерации A5D1 и дальше идёт сама (main.A5D1 на итерацию). Сравнение по
// итерациям: ОЗУ 7000-733F (без 7210-723F), таблица имён, атрибуты спрайтов, цвета, PSG.
//   node tools/optcheck.js [итераций] [уровень] ["план"]   (план и переменные — как у modelcheck.js)
'use strict';
const MSX1 = require('./msx1');
const Machine = require('../src/opt/machine');
const MAIN = process.env.OPT || '../src/model/main';
const N = +(process.argv[2] || 600), LV = +(process.argv[3] || 1), PLAN = process.argv[4] || '';
const plan = { 120: [['space', true]], 128: [['space', false]] };
for (const it of PLAN.split(/\s+/).filter(Boolean)) {
  const st = it.match(/^(\d+):s([0-9A-F=,]+)$/i); if (st) { (plan[+st[1]] = plan[+st[1]] || []).push(['set', st[2].split(',').map((x) => x.split('=').map((y) => parseInt(y, 16)))]); continue; }
  const tp = it.match(/^(\d+):tp(\d+)\.(\d+)$/); if (tp) { (plan[+tp[1]] = plan[+tp[1]] || []).push(['set', [[0x71a7, +tp[2]], [0x71a8, +tp[3]], [0x7079, 9]]]); continue; }
  const mm = it.match(/^(\d+):(\w+)([+-])$/); (plan[+mm[1]] = plan[+mm[1]] || []).push([mm[2], mm[3] === '+']);
}
if (process.env.RND) {
  let x = +process.env.RND || 1; const rnd = (n) => { x = (x * 1103515245 + 12345) & 0x7fffffff; return x % n; };
  for (let t = 200; t < N; t += 6 + rnd(25)) for (const k of ['left', 'right', 'up', 'down', 'space']) (plan[t] = plan[t] || []).push([k, rnd(3) === 0]);
}
const CHEAT = process.env.CHEAT === '1';
const K = { space: 0x40, left: 0x44, up: 0x45, down: 0x46, right: 0x47 };
const snap = (m) => Buffer.concat([Buffer.from(m.mem.subarray(0x7000, 0x7340)), Buffer.from(m.vram.subarray(0x1800, 0x1b80)), Buffer.from(m.vram.subarray(0x2000, 0x2020)), Buffer.from(m.psg.subarray(0, 11))]);
// эталон
const ref = []; let start = null;
{
  const m = new MSX1().loadSnap('entry'); m.coop = new Set([0xA5CA, 0x8C19, 0xA5D8]);
  let st = false, t = -1, f = 0; const ev = { 30: [LV, 1], 48: [LV, 0] };
  while (ref.length < N && f < 60000) {
    if (ev[f]) m.key(ev[f][0], ev[f][1]);
    const end = m.frames + 1;
    while (m.frames < end && ref.length < N) {
      const pc = m.pc;
      if (pc === 0xa59d) st = true;
      if (st && pc === 0xa5d1) {
        t++; if (CHEAT) m.mem[0x7049] = 6;
        if (t === 0) start = new Machine(m);
        for (const [k, d] of plan[t] || []) if (k === 'set') { for (const [a, v] of d) m.mem[a] = v; } else m.key(K[k], d);
        ref.push(snap(m));
      }
      m.step();
    }
    f++;
  }
}
// JS-игра
const main = require(MAIN); const out = []; const m = start; const t0 = Date.now();
for (let t = 0; t < ref.length; t++) {
  if (CHEAT) m.mem[0x7049] = 6;
  for (const [k, d] of plan[t] || []) if (k === 'set') { for (const [a, v] of d) m.mem[a] = v; } else m.key(k, d);
  out.push(snap(m));
  try { main.A5D1(m, m.r); } catch (e) { if (e.message !== 'конец игры') throw e; console.log('конец игры на итерации', t); break; }
}
console.log('итераций', ref.length, `(JS-игра ${Date.now() - t0} мс)`);
const name = (i) => i < 0x340 ? (0x7000 + i).toString(16) : i < 0x640 ? 'NT' + (i - 0x340).toString(16) : i < 0x6c0 ? 'SAT' + (i - 0x640).toString(16) : i < 0x6e0 ? 'COL' + (i - 0x6c0).toString(16) : 'PSG' + (i - 0x6e0);
for (let k = 0; k < out.length; k++) {
  const d = []; for (let i = 0; i < ref[k].length; i++) { if (i >= 0x210 && i < 0x240) continue; if (ref[k][i] !== out[k][i]) d.push(i); }
  if (d.length) { console.log(`итерация ${k}: ${d.length} байт:`, d.slice(0, 14).map((i) => `${name(i)}=${ref[k][i].toString(16)}/${out[k][i].toString(16)}`).join(' ')); process.exit(1); }
}
console.log('совпадение по всем итерациям');
