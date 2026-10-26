#!/usr/bin/env node
// Все 99 комнат уровня телепортом (MSX1.teleport, с читами): node tools/rooms.js <уровень 1..3> [кадров после старта]
// -> build/rooms/L<уровень>_<номер>.ppm и build/rooms/L<уровень>.json {номер: [ряд, столбец, md5 таблицы имён]}
'use strict';
const fs = require('fs');
const crypto = require('crypto');
const MSX1 = require('./msx1');
const lv = +(process.argv[2] || 1), N = +(process.argv[3] || 60);
fs.mkdirSync('build/rooms', { recursive: true });
const out = {};
for (let r = 0; r < 9; r++) for (let c = 8 - r; c <= 10 + r; c++) {
  const m = new MSX1().loadSnap('entry').cheats().startGame(lv).teleport(r, c);
  m.runFrames(N);
  const i = MSX1.roomIndex(r, c);
  out[i] = [r, c, crypto.createHash('md5').update(m.vram.subarray(0x1800, 0x1b00)).digest('hex').slice(0, 8)];
  fs.writeFileSync(`build/rooms/L${lv}_${i}.ppm`, m.ppm());
}
fs.writeFileSync(`build/rooms/L${lv}.json`, JSON.stringify(out));
console.log('уровень', lv, 'комнат', Object.keys(out).length, 'разных таблиц имён', new Set(Object.values(out).map((v) => v[2])).size);
