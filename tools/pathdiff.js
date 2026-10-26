#!/usr/bin/env node
// Путь исполнения на итерации главного цикла (A5D1 -> A5D1) на MSX и Векторе: последовательность меченых адресов
// картриджа (метки L_xxxx), первое расхождение. node tools/pathdiff.js <итерация> [FIRE] ["план"]
'use strict';
const fs = require('fs');
const MSX1 = require('./msx1');
const E = require('./vec_emu');
const sym = {};
for (const l of fs.readFileSync('build/vec/monty.sym', 'latin1').split('\n')) {
  const m = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (m) sym[m[1]] = parseInt(m[2], 16);
}
const IT = +process.argv[2], FIRE = +(process.argv[3] || 120), PLAN = process.argv[4] || '';
const plan = {}; plan[FIRE] = [['space', true]]; plan[FIRE + 8] = [['space', false]];
for (const it of PLAN.split(/\s+/).filter(Boolean)) { const mm = it.match(/^(\d+):(\w+)([+-])$/); (plan[+mm[1]] = plan[+mm[1]] || []).push([mm[2], mm[3] === '+']); }
const MSXK = { space: 0x40, left: 0x44, up: 0x45, down: 0x46, right: 0x47 };
const VECK = { space: [7, 0x80], left: [0, 0x10], up: [0, 0x20], right: [0, 0x40], down: [0, 0x80] };
const v2c = new Map(), c2v = new Map();
// ОЗУ игры без стека и буфера OS7, указатели картриджа не сравниваются (7190-7193, 71B0)
function ramsum(_, rd) { const b = []; for (let a = 0x7000; a < 0x7340; a++) { if (a >= 0x7210 && a < 0x7240) continue; if (a >= 0x7190 && a < 0x7194) continue; b.push(rd(a)); } return b; }
for (const [k, v] of Object.entries(sym)) if (/^L_[0-9A-F]{4}$/.test(k)) { v2c.set(v, parseInt(k.slice(2), 16)); c2v.set(parseInt(k.slice(2), 16), v); }
function msx() {
  const m = new MSX1().loadSnap('entry');
  if (process.env.COOP !== '0') { m.coop = new Set([0xA5CA, 0x8C19]); } const path = []; let st = false, t = -1, f = 0; const ev = { 30: [1, 1], 48: [1, 0] };
  while (t <= IT && f < 20000) {
    if (ev[f]) m.key(ev[f][0], ev[f][1]);
    const end = m.frames + 1;
    while (m.frames < end && t <= IT) {
      const pc = m.pc;
      if (pc === 0xa59d) st = true;
      if (st && pc === 0xa5d1) { t++; for (const [k, d] of plan[t] || []) m.key(MSXK[k], d); }
      if (t === IT && c2v.has(pc)) { const st = m.cpu.getState(); path.push([pc, ramsum(m.mem, (a) => m.mem[a]), [st.a, st.b, st.c, st.d, st.e, st.h, st.l]]); }
      m.step();
    }
    f++;
  }
  return path;
}
function vec() {
  const m = E.mk('build/vec/monty.bin'); const path = []; let st = false, t = -1;
  m.onInstr = (pc) => {
    if (pc === sym.L_A59D) st = true;
    if (st && pc === sym.L_A5D1) { t++; for (const [k, d] of plan[t] || []) { const e = VECK[k]; if (d) m.keyboard.matrix[e[0]] |= e[1]; else m.keyboard.matrix[e[0]] &= ~e[1]; } }
    if (t === IT && v2c.has(pc)) { const r = m.cpu.regs || []; path.push([v2c.get(pc), ramsum(null, m.rd), [m.cpu.regs[7], m.cpu.regs[0], m.cpu.regs[1], m.cpu.regs[2], m.cpu.regs[3], m.cpu.regs[4], m.cpu.regs[5]]]); }
  };
  let f = 0; while (t <= IT && f < 30000) { if (f === 300) m.keyboard.matrix[2] |= 2; if (f === 320) m.keyboard.matrix[2] &= ~2; m.frame(); f++; }
  return path;
}
const SPIN = new Set([0x8C19, 0xA5CA]);          // точки ожидания кадра: число повторов зависит от скорости
const dedup = (p) => p.filter((x) => !SPIN.has(x[0]));
const A = dedup(msx()), B = dedup(vec());
let i = 0; while (i < A.length && i < B.length && A[i][0] === B[i][0]) i++;
console.log('длина пути MSX', A.length, 'Вектор', B.length, 'совпадает до', i);
const h = (x) => x[0].toString(16).toUpperCase();
console.log('MSX   :', A.slice(Math.max(0, i - 6), i + 12).map(h).join(' '));
console.log('Вектор:', B.slice(Math.max(0, i - 6), i + 12).map(h).join(' '));
const RN = 'ABCDEHL';
for (let j = Math.max(0, i - 6); j < i; j++) console.log('шаг', j, h(A[j]), 'MSX', A[j][2].map((x, k) => RN[k] + '=' + x.toString(16)).join(' '), '| Вектор', B[j][2].map((x, k) => RN[k] + '=' + x.toString(16)).join(' '));
for (let j = 0; j < i; j++) {
  const ra = A[j][2], rb = B[j][2];
  if (ra && rb && ra.some((x, k) => x !== rb[k] && k > 0)) { console.log('регистры расходятся на шаге', j, h(A[j]), 'MSX', ra.map((x, k) => RN[k] + '=' + (x ?? '?').toString(16)).join(' '), '| Вектор', rb.map((x, k) => RN[k] + '=' + (x ?? '?').toString(16)).join(' ')); break; }
}
for (let j = 0; j < i; j++) {
  const a = A[j][1], b = B[j][1]; const d = []; for (let k = 0; k < a.length; k++) if (a[k] !== b[k]) d.push(k);
  if (d.length) { console.log('первое расхождение ОЗУ на шаге', j, 'перед', h(A[j]), 'после', j ? h(A[j - 1]) : '-', 'байт', d.length);
    const addr = (k) => { let a2 = 0x7000 + k; if (a2 >= 0x7190) a2 += 4; if (a2 >= 0x7210) a2 += 0x30; return a2; };
    console.log(d.slice(0, 10).map((k) => `${addr(k).toString(16)}=${a[k].toString(16)}/${b[k].toString(16)}`).join(' ')); break; }
}
