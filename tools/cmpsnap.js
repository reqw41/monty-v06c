#!/usr/bin/env node
// Сверка модели с openMSX: прогон от entry с вводом старого сценария (tools/openmsx/dump-entry.tcl)
// до момента снимка <name> и побайтное сравнение ОЗУ (кроме картриджа 8000-BFFF) и VRAM.
//   node tools/cmpsnap.js [game16|game20]
'use strict';
const fs = require('fs');
const path = require('path');
const MSX1 = require('./msx1');
const name = process.argv[2] || 'game16';
const T0 = 4.789;                                   // вход в 2000h по журналу A8 openMSX (с)
const tsnap = { game16: 16, game20: 20 }[name];
const fr = (t) => Math.round((t - T0) * 60);
const plan = {};
for (const [t, k] of [[6, 0x40], [9, 0x40], [12, 0x01], [15, 0x40]]) {
  (plan[fr(t)] ||= []).push(() => m.key(k, true)); (plan[fr(t + 0.3)] ||= []).push(() => m.key(k, false));
}
const m = new MSX1().loadSnap('entry');
for (let f = 0; f < fr(tsnap); f++) { for (const a of plan[f] || []) a(); m.runFrames(1); }
const R = path.join(MSX1.ROOT, 'build/runtime');
const ram = fs.readFileSync(path.join(R, `${name}_ram.bin`)), vram = fs.readFileSync(path.join(R, `${name}_vram.bin`));
const diff = (a, b, lo, hi) => { let n = 0, first = -1; for (let i = lo; i < hi; i++) if (a[i] !== b[i]) { n++; if (first < 0) first = i; } return [n, first]; };
const [r1, f1] = diff(m.mem, ram, 0, 0x8000), [r2, f2] = diff(m.mem, ram, 0xc000, 0x10000), [v, fv] = diff(m.vram, vram, 0, 0x4000);
console.log(name, 'pc', m.pc.toString(16), 'кадров', m.frames, 'irq', m.irqs,
  `ОЗУ 0000-7FFF: ${r1} (с ${f1.toString(16)})`, `C000-FFFF: ${r2} (с ${f2.toString(16)})`, `VRAM: ${v} (с ${fv.toString(16)})`);
fs.writeFileSync(path.join(MSX1.ROOT, `build/shots/${name}_model.ppm`), m.ppm());
