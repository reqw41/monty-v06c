#!/usr/bin/env node
// Сверка игры на Векторе с моделью MSX по вызовам обработчика кадра A9B3 (тик k — k-й вызов после старта A59D).
// Ввод задаётся по тикам одинаково: огонь (выход из вступления) на тике FIRE, далее план "тик:клавиша+/-".
// На каждом тике сравнивается ОЗУ игры 7000-73FF (кроме стека 7380-73FF); печать первого расхождения.
//   node tools/lockstep.js [тиков] [FIRE] ["план"]
'use strict';
const fs = require('fs');
const MSX1 = require('./msx1');
const E = require('./vec_emu');
const sym = {};
for (const l of fs.readFileSync('build/vec/monty.sym', 'latin1').split('\n')) {
  const m = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (m) sym[m[1]] = parseInt(m[2], 16);
}
const N = +(process.argv[2] || 400), FIRE = +(process.argv[3] || 120), PLAN = process.argv[4] || '';
const SYNC = +(process.env.SYNC || 0xA9B3);   // точка тика: A9B3 (обработчик) или 8C13 (ожидание кадра в главном цикле)
const plan = {};
plan[FIRE] = [['space', true]]; plan[FIRE + 8] = [['space', false]];
for (const it of PLAN.split(/\s+/).filter(Boolean)) {
  const mm = it.match(/^(\d+):(\w+)([+-])$/); (plan[+mm[1]] = plan[+mm[1]] || []).push([mm[2], mm[3] === '+']);
}
const MSXK = { space: 0x40, left: 0x44, up: 0x45, down: 0x46, right: 0x47 };
const VECK = { space: [7, 0x80], left: [0, 0x10], up: [0, 0x20], right: [0, 0x40], down: [0, 0x80] };
const LO = 0x7000, HI = 0x7380;

// MSX: уровень 1 из меню прослойки, затем тики
const vsn = [], vsv = [];
function runMsx() {
  const m = new MSX1().loadSnap('entry');
  if (process.env.COOP !== '0') { m.coop = new Set([0xA5CA, 0x8C19]); }
  const snaps = []; let started = false, tick = -1;
  const ev = { 30: [1, 1], 48: [1, 0] };
  let f = 0;
  while (snaps.length < N && f < 20000) {
    if (ev[f]) m.key(ev[f][0], ev[f][1]);
    const end = m.frames + 1;
    while (m.frames < end) {
      const pc = m.pc;
      if (pc === 0xa59d) started = true;
      if (started && pc === SYNC) {
        tick++;
        for (const [k, d] of plan[tick] || []) m.key(MSXK[k], d);
        snaps.push(Buffer.from(m.mem.subarray(LO, HI))); vsn.push(Buffer.concat([Buffer.from(m.vram.subarray(0x1800, 0x1B00)), Buffer.from(m.vram.subarray(0x2000, 0x2020))]));
      }
      m.step();
    }
    f++;
  }
  return snaps;
}
function runVec() {
  const m = E.mk('build/vec/monty.bin');
  const snaps = []; let started = false, tick = -1;
  m.onInstr = (pc) => {
    if (pc === sym.L_A59D) started = true;
    if (started && pc === sym['L_' + SYNC.toString(16).toUpperCase()]) {
      tick++;
      for (const [k, d] of plan[tick] || []) { const e = VECK[k]; if (d) m.keyboard.matrix[e[0]] |= e[1]; else m.keyboard.matrix[e[0]] &= ~e[1]; }
      const b = Buffer.alloc(HI - LO); for (let a = LO; a < HI; a++) b[a - LO] = m.rd(a); snaps.push(b);
      const v = Buffer.alloc(800); for (let a = 0; a < 768; a++) v[a] = m.rd(sym.VNT + a); for (let a = 0; a < 32; a++) v[768 + a] = m.rd(sym.VCOL + a); vsv.push(v);
    }
  };
  let f = 0;
  while (snaps.length < N && f < 30000) {
    if (f === 300) m.keyboard.matrix[2] |= 0x02; if (f === 320) m.keyboard.matrix[2] &= ~0x02;
    m.frame(); f++;
  }
  return snaps;
}
// адрес картриджа -> адрес Вектора: метка L_/D_ (ближайшая не выше, данные лежат подряд)
const labs = Object.entries(sym).filter(([k]) => /^(L|D)_[0-9A-F]{4}$/.test(k)).map(([k, v]) => [parseInt(k.slice(2), 16), v]).sort((a, b) => a[0] - b[0]);
function vaddr(x) {
  if (x < 0x800C || x > 0xBFFF) return -1;
  let lo = 0, hi = labs.length - 1, r = -1;
  while (lo <= hi) { const mid = (lo + hi) >> 1; if (labs[mid][0] <= x) { r = mid; lo = mid + 1; } else hi = mid - 1; }
  return r < 0 ? -1 : labs[r][1] + (x - labs[r][0]);
}
const SKIP = [[0x7210, 0x7240], [0x7340, 0x7380]];   // буфер OS7 ((8006) = 7210, REFLECT) и глубина стека (SP = 73C0)
const skip = (a) => SKIP.some(([l, h]) => a >= l && a < h);
const A = runMsx(), B = runVec();
console.log('тиков: MSX', A.length, 'Вектор', B.length);
let first = -1, prevBad = false, runs = 0;
for (let k = 0; k < Math.min(A.length, B.length); k++) {
  const d = [];
  for (let i = 0; i < A[k].length; i++) {
    if (A[k][i] === B[k][i] || skip(LO + i)) continue;
    let ok = false;                            // слово-указатель картриджа (i — младший или старший байт)
    for (const j of [i, i - 1]) {
      if (j < 0 || j + 1 >= A[k].length) continue;
      const wa = A[k][j] | A[k][j + 1] << 8, wb = B[k][j] | B[k][j + 1] << 8;
      if (vaddr(wa) === wb) ok = true;
    }
    if (!ok) d.push(i);
  }
  const bad = d.length > 0;
  if (d.length) {
    if (first < 0) first = k;
    if (k === 0 || !prevBad) console.log(`тик ${k}: ${d.length} байт:`, d.slice(0, 16).map((i) => `${(LO + i).toString(16)}=${A[k][i].toString(16)}/${B[k][i].toString(16)}`).join(' '));
  }
  if (bad && !prevBad && ++runs > 12) break;
  prevBad = bad;
}
if (first < 0) console.log('совпадение по всем тикам');
let fv = -1;
for (let k = 0; k < Math.min(vsn.length, vsv.length); k++) {
  const d = []; for (let i = 0; i < 800; i++) if (vsn[k][i] !== vsv[k][i]) d.push(i);
  if (d.length) { if (fv < 0) fv = k; if (k - fv < 6 || k % 50 === 0) console.log(`VRAM тик ${k}: ${d.length} байт:`, d.slice(0, 12).map((i) => (i < 768 ? 'NT' + i.toString(16) : 'COL' + (i - 768).toString(16)) + `=${vsn[k][i].toString(16)}/${vsv[k][i].toString(16)}`).join(' ')); }
}
if (fv < 0) console.log('VRAM (имена, цвета) совпадает по всем тикам');
