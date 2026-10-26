#!/usr/bin/env node
// Покрытие обходом комнат: для каждой из 99 комнат уровня — старт (уровень, огонь), читы, телепорт,
// затем случайный ввод (стрелки и пробел строки 8, клавиша отпускается между нажатиями).
// Пишет build/cov/L<уровень>.json {pc:[исполненные адреса команд], rd:[прочитанные], wr:[записанные]}
//   node tools/cover_run.js <уровень 1..3> [кадров на комнату] [seed]
'use strict';
const fs = require('fs');
const MSX1 = require('./msx1');
const lv = +(process.argv[2] || 1), N = +(process.argv[3] || 1500), seed = +(process.argv[4] || lv);
let s = seed * 2654435761 >>> 0;
const rnd = () => (s = (s * 1103515245 + 12345) >>> 0) / 4294967296;
const cov = new Set(), rd = new Uint8Array(0x10000), wr = new Uint8Array(0x10000);
const KEYS = [0x44, 0x45, 0x46, 0x47];   // влево, вверх, вниз, вправо
fs.mkdirSync('build/cov', { recursive: true });
for (let r = 0; r < 9; r++) for (let c = 8 - r; c <= 10 + r; c++) {
  const m = new MSX1().loadSnap('entry');
  m.cov = cov; m.onRead = (a) => { rd[a] = 1; }; m.onWrite = (a) => { wr[a] = 1; };
  m.cheats().startGame(lv).teleport(r, c);
  let hold = 0, k = -1, jump = false;
  for (let f = 0; f < N; f++) {
    if (--hold <= 0) {
      if (k >= 0) m.key(k, false); if (jump) m.key(0x40, false);
      k = rnd() < 0.15 ? -1 : KEYS[rnd() * 4 | 0]; jump = rnd() < 0.25;
      if (k >= 0) m.key(k, true); if (jump) m.key(0x40, true);
      hold = 5 + rnd() * 40 | 0;
    }
    m.runFrames(1);
  }
}
const sel = (u) => [...u.keys()].filter((a) => u[a]);
fs.writeFileSync(`build/cov/L${lv}.json`, JSON.stringify({ pc: [...cov], rd: sel(rd), wr: sel(wr) }));
console.log('уровень', lv, 'pcs', cov.size);
