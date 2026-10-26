#!/usr/bin/env node
// Снимки игры на Векторе без окна (vector06js): N кадров с планом клавиш, PNG поля 256x192 (+ отчёт).
//   node tools/vshot.js <кадров> "<кадр>:<клавиша>+ <кадр>:<клавиша>- ..." [префикс снимков] [кадры снимков через запятую]
// Клавиши: left up right down space 1 2 3. Палитра — переменная pal программы (байты BBGGGRRR, пары).
'use strict';
const fs = require('fs'), { execFileSync } = require('child_process');
const E = require('./vec_emu');
const sym = {};
for (const l of fs.readFileSync('build/vec/monty.sym', 'latin1').split('\n')) {
  const m = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (m) sym[m[1]] = parseInt(m[2], 16);
}
const KEYS = { left: [0, 0x10], up: [0, 0x20], right: [0, 0x40], down: [0, 0x80], space: [7, 0x80], 1: [2, 0x02], 2: [2, 0x04], 3: [2, 0x08] };
const [NS, PLAN, PRE, SHOTS] = process.argv.slice(2);
const plan = {};
for (const it of (PLAN || '').split(/\s+/).filter(Boolean)) {
  const mm = it.match(/^(\d+):(\w+)([+-])$/); (plan[+mm[1]] = plan[+mm[1]] || []).push([mm[2], mm[3] === '+']);
}
const shots = new Set((SHOTS || '').split(',').filter(Boolean).map(Number));
const m = E.mk('build/vec/monty.bin');
function shot(name) {
  const pal = []; for (let i = 0; i < 16; i++) pal.push(m.rd(sym.pal + i));
  const rgb = Buffer.alloc(256 * 192 * 3);
  for (let y = 0; y < 192; y++) for (let x = 0; x < 256; x++) {
    const lo = 0xDF - y, c = x >> 3, bit = 7 - (x & 7);
    const i = ((m.rd(0x8000 + c * 256 + lo) >> bit) & 1) << 2 | ((m.rd(0xA000 + c * 256 + lo) >> bit) & 1) << 1 | ((m.rd(0xC000 + c * 256 + lo) >> bit) & 1);
    const b = pal[i * 2], o = (y * 256 + x) * 3;
    rgb[o] = (b & 7) * 36; rgb[o + 1] = ((b >> 3) & 7) * 36; rgb[o + 2] = (b >> 6) * 85;
  }
  fs.writeFileSync(name + '.ppm', Buffer.concat([Buffer.from('P6 256 192 255\n'), rgb]));
  execFileSync('python3', ['tools/ppm2png.py', name + '.ppm']);
}
const N = +NS || 300;
for (let f = 0; f < N; f++) {
  for (const [k, d] of plan[f] || []) { const e = KEYS[k]; if (d) m.keyboard.matrix[e[0]] |= e[1]; else m.keyboard.matrix[e[0]] &= ~e[1]; }
  m.frame();
  if (shots.has(f)) shot(`${PRE}_${f}`);
}
shot(`${PRE || 'build/shots/v'}_end`);
const pc = m.cpu.pc, near = Object.entries(sym).filter(([k, v]) => v <= pc).sort((a, b) => b[1] - a[1])[0];
console.log('кадров', N, 'pc', pc.toString(16), near ? near[0] + '+' + (pc - near[1]).toString(16) : '', 'frames(isr)', m.rd(sym.frames) | m.rd(sym.frames + 1) << 8,
  'VR1', m.rd(sym.vregs + 1).toString(16), 'vdirty', m.rd(sym.vdirty).toString(16));
