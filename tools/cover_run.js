#!/usr/bin/env node
// Покрытие: старт игры как в cmpsnap (пробел, пробел, «1», пробел), дальше случайный ввод и перезапуски —
// джойстик (PSG рег.14) и стрелки/пробел клавиатуры (строка 8). Пишет build/cov/<seed>.json
// {pc:[исполненные адреса команд], rd:[прочитанные адреса], wr:[записанные]}
//   node tools/cover_run.js <seed> <кадров>
'use strict';
const fs = require('fs');
const MSX1 = require('./msx1');
const seed = +(process.argv[2] || 1), N = +(process.argv[3] || 20000);
let s = seed * 2654435761 >>> 0;
const rnd = () => (s = (s * 1103515245 + 12345) >>> 0) / 4294967296;
const m = new MSX1().loadSnap('entry');
m.cov = new Set();
const rd = new Uint8Array(0x10000), wr = new Uint8Array(0x10000);
m.onRead = (a) => { rd[a] = 1; }; m.onWrite = (a) => { wr[a] = 1; };
fs.mkdirSync('build/cov', { recursive: true }); fs.mkdirSync('build/shots', { recursive: true });
const start = { 72: 0x40, 252: 0x40, 432: 0x01, 612: 0x40 };
const ROW8 = [0x40, 0x44, 0x45, 0x46, 0x47];   // пробел, влево, вверх, вниз, вправо
let hold = 0, k = -1, lv = 1;
for (let f = 0; f < N; f++) {
  if (start[f] !== undefined) m.key(start[f], true); if (start[f - 18] !== undefined) m.key(start[f - 18], false);
  // перезапуск из меню после конца игры: случайный уровень «1»..«3» и пробел (в игре это лишний прыжок)
  if (f > 700 && f % 300 === 0) { lv = 1 + (rnd() * 3 | 0); m.key(lv, true); }
  if (f > 700 && f % 300 === 18) m.key(lv, false);
  if (f > 700 && f % 300 === 60) m.key(0x40, true);
  if (f > 700 && f % 300 === 78) m.key(0x40, false);
  if (f > 700 && --hold <= 0) {
    if (k >= 0) m.key(k, false); k = -1;
    if (rnd() < 0.5) m.joy = (~((rnd() < 0.15 ? 0 : (1 << (rnd() * 4 | 0))) | (rnd() < 0.3 ? 16 : 0))) & 0x3f;
    else { m.joy = 0x3f; k = ROW8[rnd() * 5 | 0]; m.key(k, true); }
    hold = 5 + rnd() * 40 | 0;
  }
  m.runFrames(1);
  if (f % 2500 === 0) fs.writeFileSync(`build/shots/cov${seed}_${f}.ppm`, m.ppm());
}
const sel = (u) => [...u.keys()].filter((a) => u[a]);
fs.writeFileSync(`build/cov/${seed}.json`, JSON.stringify({ pc: [...m.cov], rd: sel(rd), wr: sel(wr) }));
console.log('seed', seed, 'pcs', m.cov.size);
