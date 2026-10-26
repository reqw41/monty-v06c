// Машина JS-игры без процессора: память 64 КБ (картридж 8000-BFFF, ОЗУ игры 7000-73FF, переменные прослойки),
// VRAM 16 КБ, регистры VDP, PSG. Состояние — со снимка модели MSX на входе в главный цикл (A5D1).
// Ввод: keys = набор {'left','right','up','down','space'} -> 73EE..73F1 как у CONTROLLER_SCAN прослойки.
'use strict';
const { Regs } = require('../model/core');

class Machine {
  constructor(msx) {
    this.mem = Uint8Array.from(msx.mem); this.vram = Uint8Array.from(msx.vram);
    this.vreg = Uint8Array.from(msx.vreg); this.vstat = msx.vstat; this.vaddr = msx.vaddr;
    this.psg = Uint8Array.from(msx.psg); this.psgSel = msx.psgSel; this.frames = 0; this.keys = new Set();
    this.r = new Regs({ a: 0, b: 0, c: 0, d: 0, e: 0, h: 0, l: 0, ix: 0, iy: 0, sp: 0x73c0, pc: 0xa5d1, flags: { Z: 0, C: 0 } });
  }
  input(m) {
    const k = this.keys; const v = (k.has('up') ? 1 : 0) | (k.has('right') ? 2 : 0) | (k.has('down') ? 4 : 0) | (k.has('left') ? 8 : 0) | (k.has('space') ? 0x40 : 0);
    this.mem[0x73ee] = this.mem[0x73ef] = v; this.mem[0x73f0] = this.mem[0x73f1] = 0x80;
  }
  key(name, down) { if (down) this.keys.add(name); else this.keys.delete(name); }
}
module.exports = Machine;
