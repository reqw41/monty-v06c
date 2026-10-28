// Независимый пиксельный эталон: исходные снимки MSX, а не готовая графика Вектора.
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '../..');
const v0 = fs.readFileSync(path.join(root, 'build/native/vram0.bin'));
const v = fs.readFileSync(path.join(root, 'build/native/vram.bin'));
const cart = fs.readFileSync(path.join(root, 'build/monty_entry.bin'));
const animated = new Set([4,5,6,0xA0,0xA3,0xA4,0xA7,0xB8,0xB9,0xBA,0xD0,0xD1,0xD2,0xD3,0xD4,0xD5]);
const fireBody = new Uint8Array(8);
function pattern(t, frame, belt) {
  if (t === 0x38) return fireBody; // Static solid group background, as in ZX.
  if (t === 0xE0) return cart.subarray(0x85BC + 2*belt, 0x85BC + 2*belt + 8);
  if (t === 0xE8) return cart.subarray(0x85CA + 8*(belt&1), 0x85CA + 8*(belt&1) + 8);
  const bank = animated.has(t) ? [0,0x800,0x1000,0x2800][frame] : 0;
  return (bank ? v : v0).subarray(bank + 8*t, bank + 8*t + 8);
}
function modes(m, sym, t) {
  const col = m.rd(sym.room_colors + (t >> 3));
  const fg = m.rd(sym.cmap + ((col >> 4) || 1));
  const bg = m.rd(sym.cmap + ((col & 15) || 1));
  let out = 0;
  for (let bit = 2; bit >= 0; bit--) out |= (((fg >> bit)&1) | (((bg >> bit)&1) << 1)) << (2*bit);
  return out;
}
function cell(m,s,t,frame,belt,options={}) {
  if(s.SCREEN_HEIGHT===240)return require('./nes-video-ref').cell(m,s,t,frame,belt,options);
  const p=pattern(t,frame,belt),color=options.color===undefined?m.rd(s.room_colors+(t>>3)):options.color,
    fg=m.rd(s.cmap+((color>>4)||1)),bg=m.rd(s.cmap+((color&15)||1)),out=[];
  for(let bit=2;bit>=0;bit--)for(let y=0;y<8;y++){const mode=((fg>>bit)&1)|(((bg>>bit)&1)<<1);out.push([0,p[y],p[y]^255,255][mode]);}
  return out;
}
function isAnimated(s,t){return s.SCREEN_HEIGHT===240?require('./nes-video-ref').animated.has(t):animated.has(t);}
module.exports = { animated, pattern, modes, cell, isAnimated, sprite: (nm, half, y) => v[0x3800 + 8*nm + 16*half + y] };
