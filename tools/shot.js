#!/usr/bin/env node
// Прогон модели с расписанием ввода и снимками экрана.
//   node tools/shot.js <кадров> <out-префикс> [кадр:действие ...]
// действие: j=<биты джойстика 0..31, 1=нажато: 1 вверх 2 вниз 4 влево 8 вправо 16 A 32 B>, k=<код (строка<<3|бит)>, k-=<код> отпуск, s — снимок
'use strict';
const fs = require('fs');
const MSX1 = require('./msx1');
const m = new MSX1().loadSnap(process.env.SNAP || "entry");
const [N, pre, ...ev] = process.argv.slice(2);
const plan = {};
for (const e of ev) { const [f, a] = e.split(':'); (plan[f] ||= []).push(a); }
for (let f = 0; f < +N; f++) {
  for (const a of plan[f] || []) {
    if (a === 's') fs.writeFileSync(`${pre}_${f}.ppm`, m.ppm());
    else if (a.startsWith('j=')) m.joy = (~+a.slice(2)) & 0x3f;
    else if (a.startsWith('k-=')) m.key(+a.slice(3), false);
    else if (a.startsWith('k=')) m.key(+a.slice(2), true);
  }
  m.runFrames(1);
}
fs.writeFileSync(`${pre}_end.ppm`, m.ppm());
console.log('pc', m.pc.toString(16), 'frames', m.frames, 'R', [...m.vreg].map((x) => x.toString(16)).join(' '));
