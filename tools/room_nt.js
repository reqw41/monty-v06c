#!/usr/bin/env node
// Эталон для декодера комнат: таблица имён (VRAM 1800-1AFF) в момент выхода из A067 (RET в A114)
// после телепорта, для 99 комнат уровня. -> build/rooms/nt_L<у>.json {номер: {r, c, a6, bits: 70C0-718F (взятые объекты), nt: hex 768 байт}}
//   node tools/room_nt.js <уровень 1..3>
'use strict';
const fs = require('fs');
const MSX1 = require('./msx1');
const lv = +(process.argv[2] || 1);
const out = {};
fs.mkdirSync('build/rooms', { recursive: true });
for (let r = 0; r < 9; r++) for (let c = 8 - r; c <= 10 + r; c++) {
  const m = new MSX1().loadSnap('entry').cheats().startGame(lv);
  let nt = null, a6 = null, bits = null, armed = false;
  const step = m.step.bind(m);
  m.step = () => {
    const pc = m.cpu.get_pc();
    if (pc === 0xa067) { armed = true; a6 = m.mem[0x71a6]; bits = Buffer.from(m.mem.subarray(0x70c0, 0x7190)).toString('hex'); }
    if (armed && pc === 0xa114 && !nt) nt = Buffer.from(m.vram.subarray(0x1800, 0x1b00)).toString('hex');
    return step();
  };
  m.teleport(r, c);
  const now = Buffer.from(m.vram.subarray(0x1800, 0x1b00)).toString('hex');   // таблица имён в момент снимка экрана
  const col = Buffer.from(m.vram.subarray(0x2000, 0x2020)).toString('hex');
  out[MSX1.roomIndex(r, c)] = { r, c, a6, bits, nt, now, col, r7: m.vreg[7], r4: m.vreg[4] };
  // экран без спрайтов после телепорта (с палитрой этажа) — для сверки рендера ресурсов (tools/export_res.py)
  fs.writeFileSync(`build/rooms/rgb_L${lv}_${MSX1.roomIndex(r, c)}.bin`, m.rgb(false));
}
fs.mkdirSync('build/rooms', { recursive: true });
fs.writeFileSync(`build/rooms/nt_L${lv}.json`, JSON.stringify(out));
console.log('уровень', lv, 'комнат', Object.keys(out).length, '71A6', [...new Set(Object.values(out).map((v) => v.a6))]);
