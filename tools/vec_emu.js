// vec_emu.js — общий запуск vector06js для стендов упакованного релиза (unpack/splashpix/
// tracecmp/c64tune). Каждый вызов mk() — СВОЙ vm-контекст (своя копия эмулятора), поэтому два
// образа можно гонять рядом в одном процессе.
//   const E = require("./vec_emu"); const m = E.mk(romPath);
//   m.rd(a), m.wr(a,v), m.frame() — кадр по 59904 такта с прерыванием, m.cpu, m.keyboard, m.io
//   m.onInstr = pc => {...}   — перед каждой командой (PC начала команды)
//   m.onRead / m.onWrite = (a, v) => {...} — каждое обращение к памяти (адрес 0..0xFFFF)
//   m.taps — [порт, байт, ...] выводов в порты 0x08..0x0B за текущий кадр (сбрасывает вызывающий)
//   m.outs — если массив: туда же ВСЕ выводы в порты (m.outs = [] включает запись)
"use strict";
const path = require('path'), fs = require("fs"), vm = require("vm");
const base = process.env.V06 || (process.env.HOME + "/projects/vector06js");
const FILES = ["i8080-js/i8080_trace.js", "i8080-js/i8080_disasm.js", "i8080-js/i8080.js",
  "src/fili.js", "src/ay.js", "src/fd1793.js", "src/fddimage.js", "src/i8253.js",
  "src/io.js", "src/keyboard.js", "src/memory.js", "src/sound.js", "src/tv.js"];
const SRC = FILES.map(f => [f, fs.readFileSync(base + "/" + f, "utf8")]);

function labels(sld) {
  const L = {};
  for (const l of fs.readFileSync(sld, "latin1").split("\n")) {
    const p = l.split("|");
    if (p.length >= 8 && p[6] === "L") { const n = p[7].split(",")[1]; if (n && !(n in L)) L[n] = +p[5]; }
  }
  return L;
}

function mk(romPath, opt) {
  opt = opt || {};
  const g = {}; g.window = g;
  function fcx() { return { createImageData: () => ({ data: new Uint8ClampedArray(4) }), putImageData() {}, getImageData: () => ({ data: new Uint8ClampedArray(4) }), fillRect() {}, drawImage() {} }; }
  function fc() { return { width: 0, height: 0, style: {}, getContext: () => fcx() }; }
  g.document = { createElement: () => fc(), getElementById: () => fc() };
  g.requestAnimationFrame = () => 0; g.setTimeout = () => 0; g.print = () => 0;
  g.console = { log() {}, debug() {}, warn() {}, error() {}, info() {} };
  const ctx = vm.createContext(g);
  for (const [f, s] of SRC) vm.runInContext(s, ctx, { filename: f });
  const memory = new ctx.Memory(), keyboard = new ctx.Keyboard(), timer = new ctx.I8253(), ay = new ctx.AY(),
        floppy = new (ctx.Floppy().FD1793)(), io = new ctx.IO(keyboard, timer, memory, ay, floppy);
  const m = { memory, keyboard, timer, io, JOY: 0xFF, taps: [], outs: null, onInstr: null, onRead: null, onWrite: null, frames: 0 };
  { const _rd = io.input.bind(io); io.input = p => ((p & 0xFF) === 0x0E ? m.JOY : _rd(p)); }
  { const _wr = io.output.bind(io);
    io.output = (p, v) => { if ((p & 0xFF) >= 0x08 && (p & 0xFF) <= 0x0B) m.taps.push(p & 0xFF, v);
                            if (m.outs) m.outs.push(p & 0xFF, v & 0xFF); _wr(p, v); }; }
  const cpu = new ctx.I8080(memory, io), tape = { advance: () => {}, sample: 0, reset: () => {} },
        v06c = new ctx.Vector06c(cpu, memory, io, ay, tape);
  v06c.bmp = new Uint32Array(576 * 288); v06c.displayFrame = () => {}; v06c.dbg = null;
  // COVER=файл: накопление адресов выполненных команд (объединяется между процессами) для поиска мёртвого кода
  let cov = null;
  if (process.env.COVER) {
    cov = new Uint8Array(65536);
    process.on("exit", () => { try { const f = process.env.COVER; let o = fs.existsSync(f) ? fs.readFileSync(f) : Buffer.alloc(65536);
      if (o.length !== 65536) o = Buffer.alloc(65536); for (let i = 0; i < 65536; i++) if (cov[i]) o[i] = 1; fs.writeFileSync(f, o); } catch (e) {} });
  }
  if (cov) { const oi = cpu.instruction.bind(cpu); cpu.instruction = function () { cov[cpu.pc] = 1; return oi.apply(null, arguments); }; }
  v06c.check_breakpoint = () => { if (m.onInstr) m.onInstr(cpu.pc); return false; };
  const IMG = new Uint8Array(fs.readFileSync(romPath)).subarray(0, 0x10000);
  if (IMG[0] !== 0xF3 || IMG[1] !== 0x31) throw new Error(romPath + ": загрузчик не `di / ld sp,imm`");
  memory.init_from_array(IMG, 0); memory.detach_boot && memory.detach_boot();
  const oread = memory.read.bind(memory), owrite = memory.write.bind(memory);
  let acc = null;
  if (process.env.ACCESS) {
    acc = new Uint8Array(65536);
    process.on("exit", () => { try { const f = process.env.ACCESS; let o = fs.existsSync(f) ? fs.readFileSync(f) : Buffer.alloc(65536);
      if (o.length !== 65536) o = Buffer.alloc(65536); for (let i = 0; i < 65536; i++) if (acc[i]) o[i] = 1; fs.writeFileSync(f, o); } catch (e) {} });
  }
  memory.read = function (a, s) { const v = oread(a, s); if (acc) acc[a & 0xffff] = 1; if (m.onRead) m.onRead(a & 0xffff, v); return v; };
  memory.write = function (a, w, s) { if (acc) acc[a & 0xffff] = 1; if (m.onWrite) m.onWrite(a & 0xffff, w & 0xff); return owrite(a, w, s); };
  cpu.pc = 0; cpu.sp = IMG[2] | (IMG[3] << 8); cpu.iff = false;
  m.cpu = cpu; m.v06c = v06c; m.img = IMG; m.ctx = ctx;
  m.rd = a => memory.bytes[memory.tobank(a & 0xffff)];
  m.wr = (a, v) => { memory.bytes[memory.tobank(a & 0xffff)] = v & 0xff; };
  m.dump = () => { const d = new Uint8Array(0x10000); for (let a = 0; a < 0x10000; a++) d[a] = m.rd(a); return d; };
  // fix36: в меню титула нет цифр 1/2/3 — только стрелки и огонь. Стенды по-прежнему «нажимают» цифру:
  // она снимается с ряда 2, в память пишется уровень (menu_level), и огонь жмётся свежим нажатием,
  // пока меню его не примет (запись menu_keys с битом огня). Отключить: opt.rawDigits.
  let digit = 0, fireByShim = false, menuTook = false;
  const symf = path.join(path.dirname(romPath), 'monty.sym');
  const msym = {};
  if (!opt.rawDigits && fs.existsSync(symf)) for (const l of fs.readFileSync(symf, 'latin1').split('\n')) {
    const mm = l.match(/^(menu_level|menu_keys):\s+EQU\s+0x([0-9A-F]+)/i); if (mm) msym[mm[1]] = parseInt(mm[2], 16); }
  if (msym.menu_level !== undefined && msym.menu_keys !== undefined) {
    const raw = keyboard.matrix;
    keyboard.matrix = new Proxy(raw, { get(t, k) { const v = t[k]; return typeof v === 'function' ? v.bind(t) : v; }, set(t, k, v) {
      if (k === '2') { const d = v & 2 ? 1 : v & 4 ? 2 : v & 8 ? 3 : 0; if (d) digit = d; else if (!(v & 14)) { digit = 0; if (fireByShim) { t[7] &= ~0x80; fireByShim = false; } } v &= ~14; }
      t[k] = v; return true; } });
    const w0 = memory.write;
    memory.write = function (a, w, s) { if ((a & 0xffff) === msym.menu_keys && (w & 1) && fireByShim) menuTook = true; return w0(a, w, s); };
  }
  m.frame = () => {
    if (digit) { m.wr(msym.menu_level, digit); m.wr(msym.menu_keys, 0); if (!(keyboard.matrix[7] & 0x80)) { keyboard.matrix[7] |= 0x80; fireByShim = true; } }
    v06c.oneInterrupt(true); m.frames++;
    if (menuTook) { menuTook = false; digit = 0; if (fireByShim) { keyboard.matrix[7] &= ~0x80; fireByShim = false; } }
  };
  m.palette = () => Array.from(io.Palette.slice(0, 16));
  m.regs = () => [cpu.pc, cpu.sp, cpu.iff ? 1 : 0, cpu.store_flags(), ...cpu.regs].join(",");
  return m;
}

// цвет палитры эмулятора (io.commit_palette) из байта BBGGGRRR
function palColor(w8) {
  const b = (w8 & 0xc0) >> 6, g = (w8 & 0x38) >> 3, r = w8 & 7;
  return (0xff000000 | (b << (6 + 16)) | (g << (5 + 8)) | (r << 5)) >>> 0;
}

module.exports = { mk, labels, palColor };
