// JS-модель Montezuma's Revenge (Coleco/MSX): общие средства. Процедура модели — fn(m, r): m — модель MSX
// (tools/msx1.js), r — регистры (a, b, c, d, e, h, l, ix, iy, zf, cf; пары hl/de/bc). Подмена Z80-кода
// (hooks) — hook(fn): регистры из процессора, fn, запись регистров и возврат как RET.
'use strict';
const C = module.exports = {};

class Regs {
  constructor(s) { Object.assign(this, { a: s.a, b: s.b, c: s.c, d: s.d, e: s.e, h: s.h, l: s.l, ix: s.ix, iy: s.iy, sp: s.sp, pc: s.pc, zf: s.flags.Z, cf: s.flags.C }); this._s = s; }
  get hl() { return this.h << 8 | this.l; } set hl(v) { this.h = v >> 8 & 0xff; this.l = v & 0xff; }
  get de() { return this.d << 8 | this.e; } set de(v) { this.d = v >> 8 & 0xff; this.e = v & 0xff; }
  get bc() { return this.b << 8 | this.c; } set bc(v) { this.b = v >> 8 & 0xff; this.c = v & 0xff; }
}
C.R = (m) => new Regs(m.cpu.getState());
C.W = (m, r) => {
  const s = r._s;
  Object.assign(s, { a: r.a & 0xff, b: r.b & 0xff, c: r.c & 0xff, d: r.d & 0xff, e: r.e & 0xff, h: r.h & 0xff, l: r.l & 0xff,
    ix: r.ix & 0xffff, iy: r.iy & 0xffff, sp: r.sp & 0xffff, pc: r.pc & 0xffff });
  s.flags.Z = r.zf ? 1 : 0; s.flags.C = r.cf ? 1 : 0;
  m.cpu.setState(s);
};
C.rd = (m, a) => m.mem[a & 0xffff];
C.wr = (m, a, v) => { a &= 0xffff; if ((a & 0xc000) !== 0x8000) m.mem[a] = v & 0xff; };
C.rd16 = (m, a) => m.mem[a & 0xffff] | m.mem[(a + 1) & 0xffff] << 8;
C.wr16 = (m, a, v) => { C.wr(m, a, v & 0xff); C.wr(m, a + 1, v >> 8); };
C.ret = (m, r) => { r.pc = C.rd16(m, r.sp); r.sp = (r.sp + 2) & 0xffff; C.W(m, r); };
// подмена: процедура модели вместо Z80-кода
C.hook = (fn) => (m) => { const r = C.R(m); fn(m, r); C.ret(m, r); };
// модуль: { 'адрес': fn } -> { 'адрес': hook(fn) }
C.hooks = (mod) => Object.fromEntries(Object.entries(mod).filter(([k]) => /^[0-9A-F]{4}$/.test(k)).map(([k, fn]) => [k, C.hook(fn)]));
