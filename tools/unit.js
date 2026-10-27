#!/usr/bin/env node
// Поштучная сверка нативных процедур (src/native) с JS-моделью (src/model): JS-игра без процессора (src/opt)
// идёт по сценарию; на входе в процедуру модели <модуль>.<имя> снимается состояние (ОЗУ, VRAM, регистры VDP),
// модель выполняет её — снимается результат. Та же точка в эмуляторе Вектора: ОЗУ игры 7000-73FF, VNT, VCOL,
// vregs из входа, вызов метки <метка> (регистры — по args), до возврата; сравнение ОЗУ 7000-733F, VNT, VCOL.
//   node tools/unit.js <модуль.имя> <метка> [случаев] [уровень] ["план"] [args: a,b,c,de,hl через =]
// Пример: node tools/unit.js drawroom.A067 nat_A067 50
'use strict';
const fs = require('fs');
const MSX1 = require('./msx1');
const Machine = require('../src/opt/machine');
const E = require('./vec_emu');
const [FN, LABEL, NC = '40', LV = '1', PLAN = ''] = process.argv.slice(2);
const [MOD, NAME] = FN.split('.');
const SKIP = (process.env.SKIP || '7340-73FF').split(',').map((r) => r.split('-').map((x) => parseInt(x, 16)));
const cart = (w) => (w >= 0x800C && w < 0xC000 ? sym['C_' + w.toString(16).toUpperCase().padStart(4, '0')] : undefined);
const nativeDir = process.env.B || 'build/native';
const sym = {}; for (const l of fs.readFileSync(nativeDir + '/monty.sym', 'latin1').split('\n')) { const m = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (m) sym[m[1]] = parseInt(m[2], 16); }
if (sym[LABEL] === undefined) throw new Error('нет метки ' + LABEL);

// --- старт JS-игры: снимок модели MSX на первой итерации уровня LV
const msx = new MSX1().loadSnap('entry'); msx.coop = new Set([0xA5CA, 0x8C19, 0xA5D8]);
{ const ev = { 30: [+LV, 1], 48: [+LV, 0] }; let st = false, f = 0, done = false;
  while (!done && f < 3000) { if (ev[f]) msx.key(ev[f][0], ev[f][1]); const end = msx.frames + 1;
    while (msx.frames < end && !done) { const pc = msx.pc; if (pc === 0xa59d) st = true; if (st && pc === 0xa5d1) done = true; else msx.step(); } f++; } }
const g = new Machine(msx);
// --- сценарий: случайный ввод, телепорты по комнатам (цвета ряда — 70B1 бит 4)
let x = 7; const rnd = (n) => { x = (x * 1103515245 + 12345) & 0x7fffffff; return x % n; };
const rooms = []; for (let r = 0; r < 9; r++) for (let c = 8 - r; c <= 10 + r; c++) rooms.push([r, c]);
// --- перехват процедуры модели
const mod = require('../src/model/' + MOD); const orig = mod[NAME]; const cases = [];
const snapState = (m, r) => ({ keys: new Set(g.keys), mem: Uint8Array.from(m.mem), vram: Uint8Array.from(m.vram), vreg: Uint8Array.from(m.vreg), r: { a: r.a, b: r.b, c: r.c, d: r.d, e: r.e, h: r.h, l: r.l, zf: r.zf, cf: r.cf } });
let calls = 0; mod[NAME] = function (m, r) { calls++; if (cases.length >= +NC) return orig(m, r); const pre = snapState(m, r); const ret = orig(m, r); cases.push({ pre, post: snapState(m, r) }); return ret; };
const main = require('../src/model/main');
for (let t = 0; t < 40000 && cases.length < +NC; t++) {
  g.mem[0x7049] = 6;
  if (t > 120 && t % (6 + rnd(20)) === 0) for (const k of ['left', 'right', 'up', 'down', 'space']) g.key(k, rnd(3) === 0);
  if (t === 120) g.key('space', true); if (t === 128) g.key('space', false);
  if (t >= 200 && t % 45 === 0) { const [r, c] = rooms[rnd(rooms.length)]; g.mem[0x71a7] = r; g.mem[0x71a8] = c; g.mem[0x7079] = 9; g.mem[0x70a9] = 0xff; g.mem[0x70b1] |= 0x10; }
  try { main.A5D1(g, g.r); } catch (e) { if (e.message !== 'конец игры') throw e; break; }
}
mod[NAME] = orig;
if (process.env.DEBUG) console.log('вызовов', calls);
console.log(`случаев ${cases.length} (${FN} -> ${LABEL})`);
// --- проверка на Векторе
const v = E.mk(nativeDir + '/monty.bin');
const TRAP = sym.unit_trap; if (TRAP === undefined) throw new Error('нет метки unit_trap');
let bad = 0, maxCyc = 0, sumCyc = 0;
for (let k = 0; k < cases.length; k++) {
  const { pre, post } = cases[k];
  for (let a = 0x7000; a < 0x7400; a++) v.wr(a, pre.mem[a]);
  for (const p of [0x7190, 0x7192, 0x702E]) {                   // указатели в данные картриджа — адреса Вектора
    const w = pre.mem[p] | pre.mem[p + 1] << 8, c = cart(w); if (c !== undefined) { v.wr(p, c & 0xff); v.wr(p + 1, c >> 8); }
  }
  for (let i = 0; i < 768; i++) v.wr(sym.VNT + i, pre.vram[0x1800 + i]);
  for (let i = 0; i < 32; i++) v.wr((sym.room_colors ?? sym.VCOL) + i, pre.vram[0x2000 + i]);
  if (sym.vregs !== undefined) for (let i = 0; i < 8; i++) v.wr(sym.vregs + i, pre.vreg[i]);
  const kb = [0, 0, 0, 0, 0, 0, 0, 0];                          // клавиши модели -> матрица Вектора (kbmat)
  for (const [k, row, bit] of [['left', 0, 0x10], ['up', 0, 0x20], ['right', 0, 0x40], ['down', 0, 0x80], ['space', 7, 0x80]]) if (pre.keys.has(k)) kb[row] |= bit;
  for (let i = 0; i < 8; i++) v.wr(sym.kbmat + i, kb[i]);
  const R = v.cpu.regs; const r = pre.r; [R[0], R[1], R[2], R[3], R[4], R[5], R[7]] = [r.b, r.c, r.d, r.e, r.h, r.l, r.a];
  for (const [hi, lo] of [[0, 1], [2, 3], [4, 5]]) {          // адрес картриджа в паре — метка данных C_xxxx
    const w = R[hi] << 8 | R[lo], c = sym['C_' + w.toString(16).toUpperCase().padStart(4, '0')];
    if (w >= 0x800C && w < 0xC000 && c !== undefined) { R[hi] = c >> 8; R[lo] = c & 0xff; }
  }
  v.cpu.iff = false; v.cpu.sp = 0x73C0; v.cpu.sp -= 2; v.wr(v.cpu.sp, TRAP & 0xff); v.wr(v.cpu.sp + 1, TRAP >> 8); v.cpu.pc = sym[LABEL];
  let cyc = 0, n = 0;
  while (v.cpu.pc !== TRAP && n < 5e6) { if (v.cpu.pc === sym.frame_wait) v.cpu.pc = sym.unit_fw; v.cpu.instruction(); cyc += v.cpu.vcycles || 0; n++; }   // ожидание кадра — сразу обработчик
  if (n >= 5e6) { console.log(`случай ${k}: нет возврата (pc ${v.cpu.pc.toString(16)})`); bad++; continue; }
  maxCyc = Math.max(maxCyc, cyc); sumCyc += cyc;
  const d = [];
  const skip = (a) => SKIP.some(([lo, hi]) => a >= lo && a <= hi);
  const ptrOk = (a) => [a, a - 1].some((j) => { const w = post.mem[j] | post.mem[j + 1] << 8, c = cart(w); return c !== undefined && (v.rd(j) | v.rd(j + 1) << 8) === c; });
  for (let a = 0x7000; a < 0x7400; a++) if (!skip(a) && v.rd(a) !== post.mem[a] && !ptrOk(a)) d.push(`${a.toString(16)}=${post.mem[a].toString(16)}/${v.rd(a).toString(16)}`);
  for (let i = 0; i < 768; i++) if (v.rd(sym.VNT + i) !== post.vram[0x1800 + i]) d.push(`NT${i.toString(16)}=${post.vram[0x1800 + i].toString(16)}/${v.rd(sym.VNT + i).toString(16)}`);
  for (let i = 0; i < 32; i++) if (v.rd((sym.room_colors ?? sym.VCOL) + i) !== post.vram[0x2000 + i]) d.push(`COL${i.toString(16)}=${post.vram[0x2000 + i].toString(16)}/${v.rd((sym.room_colors ?? sym.VCOL) + i).toString(16)}`);
  if (d.length) { bad++; if (bad <= 5) console.log(`случай ${k}: ${d.length} расхождений:`, d.slice(0, 12).join(' ')); }
}
console.log(bad ? `расхождений в ${bad} случаях из ${cases.length}` : 'совпадение во всех случаях', `| тактов Вектора: в среднем ${Math.round(sumCyc / Math.max(1, cases.length))}, макс. ${maxCyc}`);
process.exit(bad ? 1 : 0);
