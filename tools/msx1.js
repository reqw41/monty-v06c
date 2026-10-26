// msx1.js — минимальная модель MSX1 для эталонных прогонов Montezuma's Revenge.
//
// Z80 (tools/vendor/Z80.js, MIT). Память плоская 64К в раскладке игры после 200Ch (A8=DF):
// ОЗУ 0000-7FFF и C000-FFFF, картридж 8000-BFFF (запись игнорируется). Старт с образа
// build/runtime/entry_cpu.bin — вход в 2000h, снят в openMSX (tools/openmsx/dump-entry.tcl).
// Переключение слотов (A8) не моделируется: игра пишет DF один раз в 200Ch.
// VDP TMS9918A: порты 98/99, VRAM 16К; флаг кадра в статусе, прерывание IM1 при R1 бит 5.
// PPI: AAh — строка матрицы, A9h — чтение строки. PSG: A0h/A1h/A2h, рег.14 — джойстик 1
// (биты 0..5: вверх, вниз, влево, вправо, кнопки A, B; 0 = нажато).
// Кадр 60 Гц = 59736 тактов (3,579545 МГц, 262 строки по 228). Задержки VDP/M1 не моделируются.
'use strict';
const fs = require('fs');
const path = require('path');
const Z80 = require('./vendor/Z80.js');

const ROOT = path.join(__dirname, '..');
const T_FRAME = 59736;
const RUN = path.join(ROOT, 'build/runtime');

class MSX1 {
  constructor() {
    this.mem = new Uint8Array(0x10000);
    this.vram = new Uint8Array(0x4000);
    this.vreg = new Uint8Array(8);
    this.vaddr = 0; this.vlatch = -1; this.vread = 0; this.vstat = 0;
    this.kb = new Uint8Array(11).fill(0xff); this.kbrow = 0;
    this.psg = new Uint8Array(16); this.psgSel = 0; this.joy = 0x3f;
    this.t = 0; this.total = 0; this.frames = 0; this.irqs = 0;
    this.cov = null;                 // Set исполненных адресов команд, если включено
    this.onRead = null; this.onWrite = null; this.onOut = null; this.onPsg = null;
    const self = this;
    this.cpu = new Z80({
      mem_read: (a) => { const v = self.mem[a]; if (self.onRead) self.onRead(a, v); return v; },
      mem_write: (a, v) => {
        if (self.onWrite) self.onWrite(a, v);
        if ((a & 0xc000) !== 0x8000) self.mem[a] = v & 0xff;
      },
      io_read: (p) => self._in(p & 0xff),
      io_write: (p, v) => self._out(p & 0xff, v & 0xff),
    });
  }

  // снимок openMSX: <name>_ram.bin, _cpu.bin (вид CPU), _vram, _vdp, _regs.txt
  loadSnap(name = 'entry') {
    // ОЗУ — Main RAM целиком, 8000-BFFF — картридж из вида CPU (на входе страница 1 ещё картридж, A8=D7)
    this.mem.set(fs.readFileSync(path.join(RUN, `${name}_ram.bin`)));
    this.mem.set(fs.readFileSync(path.join(RUN, `${name}_cpu.bin`)).subarray(0x8000, 0xc000), 0x8000);
    this.vram.set(fs.readFileSync(path.join(RUN, `${name}_vram.bin`)));
    this.vreg.set(fs.readFileSync(path.join(RUN, `${name}_vdp.bin`)));
    const r = {};
    for (const l of fs.readFileSync(path.join(RUN, `${name}_regs.txt`), 'utf8').split('\n')) {
      const [k, v] = l.split(' '); if (k) r[k] = +v;
    }
    const st = this.cpu.getState();
    const lo = (w) => w & 0xff, hi = (w) => w >> 8;
    Object.assign(st, {
      pc: r.pc, sp: r.sp, ix: r.ix, iy: r.iy, i: r.i, r: r.r, imode: r.im,
      a: hi(r.af), flags: unpackF(lo(r.af)), b: hi(r.bc), c: lo(r.bc), d: hi(r.de), e: lo(r.de), h: hi(r.hl), l: lo(r.hl),
      a_prime: hi(r.af2), flags_prime: unpackF(lo(r.af2)), b_prime: hi(r.bc2), c_prime: lo(r.bc2),
      d_prime: hi(r.de2), e_prime: lo(r.de2), h_prime: hi(r.hl2), l_prime: lo(r.hl2),
      iff1: r.iff & 1, iff2: (r.iff >> 1) & 1, halted: false,
    });
    this.cpu.setState(st);
    return this;
  }

  _in(p) {
    switch (p) {
      case 0x98: { const v = this.vread; this.vread = this.vram[this.vaddr]; this.vaddr = (this.vaddr + 1) & 0x3fff; this.vlatch = -1; return v; }
      case 0x99: { const v = this.vstat; this.vstat &= 0x1f; this.vlatch = -1; return v; }
      case 0xa2: return this.psgSel === 14 ? this.joy | 0xc0 : this.psg[this.psgSel];
      case 0xa8: return 0xdf;
      case 0xa9: return this.kb[this.kbrow] ?? 0xff;
      case 0xaa: return this.kbrow | 0xf0;
      default: return 0xff;
    }
  }

  _out(p, v) {
    if (this.onOut) this.onOut(p, v);
    switch (p) {
      case 0x98: this.vram[this.vaddr] = v; this.vread = v; this.vaddr = (this.vaddr + 1) & 0x3fff; this.vlatch = -1; break;
      case 0x99:
        if (this.vlatch < 0) { this.vlatch = v; break; }
        if (v & 0x80) this.vreg[v & 7] = this.vlatch;
        else {
          this.vaddr = ((v & 0x3f) << 8) | this.vlatch;
          if (!(v & 0x40)) { this.vread = this.vram[this.vaddr]; this.vaddr = (this.vaddr + 1) & 0x3fff; }
        }
        this.vlatch = -1; break;
      case 0xa0: this.psgSel = v & 15; break;
      case 0xa1: this.psg[this.psgSel] = v; if (this.onPsg) this.onPsg(this.psgSel, v, this.frames); break;
      case 0xaa: this.kbrow = v & 15; break;
    }
  }

  // клавиша матрицы MSX: (строка<<3)|бит. Enter = 0x3f (7,7), пробел = 0x40 (8,0), «1» = 0x01
  key(code, down) { const r = code >> 3, b = code & 7; if (down) this.kb[r] &= ~(1 << b); else this.kb[r] |= 1 << b; }
  keysOff() { this.kb.fill(0xff); }

  // Старт игры: на 30-м кадре клавиша уровня «1»..«3», на 150-м огонь (пробел). До огня идёт
  // вступительная сцена (ряд 0, столбец 8 = комната 0, флаг 705F бит 2); по огню переход на два столбца
  // вправо, в стартовую комнату (0,10) = 2, там 8AB3 снимает флаг и 8E7E рисует инвентарь. Плюс 120 кадров.
  startGame(level = 1) {
    const ev = { 30: [level, 1], 48: [level, 0], 150: [0x40, 1], 168: [0x40, 0] };
    for (let f = 0; f < 300; f++) { if (ev[f]) this.key(ev[f][0], ev[f][1]); this.runFrames(1); }
    return this;
  }
  // Телепорт в идущей игре (после startGame). Номер комнаты = A4C5[ряд 71A7] + столбец 71A8: пирамида 9 рядов
  // по 3..19 комнат, в ряду r столбцы 8-r..10+r, комнаты 0..98. Ряд и столбец подменяются, затем гибель
  // (7079 := 9): при возрождении A067 рисует новую комнату; потом вызывается 8EB0 — палитра этажа
  // (93C0 + 7*min(ряд,8)) и темнота нижних этажей, как при естественной смене ряда (A9B3).
  // Герой появляется в точке возрождения прежней комнаты (707C-7085, пишет 8E7E) — с cheats() падение безопасно.
  // Вызывать до teleport() нельзя, пока не прошла вступительная сцена (флаг 705F бит 2).
  teleport(r, c) {
    this.mem[0x71a7] = r; this.mem[0x71a8] = c; this.mem[0x7079] = 9;
    let drawn = -1;
    for (let f = 0; f < 300; f++) {
      const end = this.frames + 1;
      while (this.frames < end) { if (drawn < 0 && this.cpu.get_pc() === 0xa067) drawn = f; this.step(); }
      if (drawn >= 0 && f === drawn + 20) break;
    }
    if (drawn < 0) throw new Error('телепорт: A067 не вызвана');
    this.callSub(0x8eb0);
    return this;
  }
  // Вызов подпрограммы игры как CALL: возврат на ловушку FFF0, затем PC восстанавливается
  callSub(addr, limit = 2e6, regs = {}) {
    const st = this.cpu.getState(), ret = st.pc;
    Object.assign(st, regs);
    st.sp = (st.sp - 2) & 0xffff; this.mem[st.sp] = 0xf0; this.mem[(st.sp + 1) & 0xffff] = 0xff; st.pc = addr;
    this.cpu.setState(st);
    let n = 0; while (this.cpu.get_pc() !== 0xfff0 && n++ < limit) this.step();
    if (n >= limit) throw new Error(`callSub ${addr.toString(16)}: нет возврата`);
    const s2 = this.cpu.getState(); s2.pc = ret; this.cpu.setState(s2);
    return n;
  }
  // Читы для обхода: падение любой высоты безопасно (8AD5 CP 1Ch -> CP FFh; высота = 7300 - 707C),
  // жизни 7049 держатся на 6 (проверяется каждый кадр в runFrames)
  cheats() { this.mem[0x8ad6] = 0xff; this.infLives = true; return this; }
  static roomIndex(r, c) { return [-8, -4, 2, 10, 20, 32, 46, 62, 80][r] + c; }

  get pc() { return this.cpu.get_pc(); }
  step() {
    if ((this.vstat & 0x80) && (this.vreg[1] & 0x20) && this.cpu.get_iff1()) { this.cpu.interrupt(false, 0xff); this.irqs++; }
    if (this.cov) this.cov.add(this.cpu.get_pc());
    const c = this.cpu.run_instruction();
    this.t += c; this.total += c;
    if (this.t >= T_FRAME) { this.t -= T_FRAME; this.frames++; this.vstat |= 0x80; }
    return c;
  }
  runFrames(n) {
    const f = this.frames + n;
    while (this.frames < f) { this.step(); if (this.infLives && this.t < 32) this.mem[0x7049] = 6; }
  }
  // VRAM -> RGB (Graphics II / Graphics I по R0/R1), без спрайтов и с ними
  rgb(sprites = true) {
    const PAL = [[0, 0, 0], [0, 0, 0], [33, 200, 66], [94, 220, 120], [84, 85, 237], [125, 118, 252], [212, 82, 77], [66, 235, 245],
      [252, 85, 84], [255, 121, 120], [212, 193, 84], [230, 206, 128], [33, 176, 59], [201, 91, 186], [204, 204, 204], [255, 255, 255]];
    const W = 256, H = 192, out = new Uint8Array(W * H * 3), r = this.vreg, vr = this.vram;
    const g2 = r[0] & 2, nt = (r[2] & 15) << 10;
    const pt = g2 ? (r[4] & 4) << 11 : (r[4] & 7) << 11, ct = g2 ? (r[3] & 0x80) << 6 : r[3] << 6;
    const bd = r[7] & 15;
    for (let y = 0; y < H; y++) for (let cx = 0; cx < 32; cx++) {
      const ch = vr[nt + (y >> 3) * 32 + cx];
      let p, c;
      if (g2) { const o = ((y >> 6) << 11) + ch * 8 + (y & 7); p = vr[pt + (o & ((r[4] & 3) << 11 | 0x7ff))]; c = vr[ct + (o & ((r[3] & 0x7f) << 6 | 0x3f))]; }
      else { p = vr[pt + ch * 8 + (y & 7)]; c = vr[ct + (ch >> 3)]; }
      for (let b = 0; b < 8; b++) {
        let col = (p >> (7 - b)) & 1 ? c >> 4 : c & 15; if (!col) col = bd;
        out.set(PAL[col], (y * W + cx * 8 + b) * 3);
      }
    }
    if (sprites && (r[1] & 0x40)) {
      const sat = (r[5] & 0x7f) << 7, spt = (r[6] & 7) << 11, big = r[1] & 2, mag = r[1] & 1, sz = big ? 16 : 8;
      let last = 32; for (let i = 0; i < 32; i++) if (vr[sat + i * 4] === 0xd0) { last = i; break; }
      for (let i = last - 1; i >= 0; i--) {
        const a = sat + i * 4; let y = (vr[a] + 1) & 0xff; if (y > 0xe0) y -= 256;
        let x = vr[a + 1]; const nm = big ? vr[a + 2] & 0xfc : vr[a + 2], col = vr[a + 3] & 15;
        if (vr[a + 3] & 0x80) x -= 32; if (!col) continue;
        for (let yy = 0; yy < sz * (mag ? 2 : 1); yy++) for (let xx = 0; xx < sz * (mag ? 2 : 1); xx++) {
          const sy = mag ? yy >> 1 : yy, sx = mag ? xx >> 1 : xx;
          const byte = vr[spt + nm * 8 + (sx >> 3) * 16 + sy];
          if (!((byte >> (7 - (sx & 7))) & 1)) continue;
          const X = x + xx, Y = y + yy; if (X < 0 || X >= W || Y < 0 || Y >= H) continue;
          out.set(PAL[col], (Y * W + X) * 3);
        }
      }
    }
    return out;
  }
  ppm() { return Buffer.concat([Buffer.from('P6 256 192 255\n'), Buffer.from(this.rgb())]); }
}

MSX1.T_FRAME = T_FRAME;
MSX1.ROOT = ROOT;
module.exports = MSX1;

function unpackF(f) {
  return { S: f >> 7 & 1, Z: f >> 6 & 1, Y: f >> 5 & 1, H: f >> 4 & 1, X: f >> 3 & 1, P: f >> 2 & 1, N: f >> 1 & 1, C: f & 1 };
}
