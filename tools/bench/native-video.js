// Нативный вывод: неизменяемость/точность готовых сдвигов и движение в комнате 1,9.
// node tools/bench/native-video.js [build/native] [1200]
const fs = require('fs'), path = require('path');
const E = require('../vec_emu'), REF = require('./video-ref');
const dir = path.resolve(process.argv[2] || 'build/native'), limit = +(process.argv[3] || 1200);
const sym = {};
for (const l of fs.readFileSync(path.join(dir, 'monty.sym'), 'utf8').split('\n')) {
  const q = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i);
  if (q) sym[q[1]] = parseInt(q[2], 16);
}
const m = E.mk(path.join(dir, 'monty.bin'));
const image = fs.readFileSync(path.join(dir, 'monty.bin'));
const protectedBytes = new Uint8Array(65536), old = {}, sourceOld = {}, movement = {};
const room=(process.env.ROOM||'1,9').split(',').map(Number);
const lastEnemy=process.env.ROOM==='5,7'||process.env.ROOM==='7,3'?5:4;
let steps = 0, ready = false, bad = 0, frame0 = 0, fires = 0, belts = 0, lastPC = 0;
function checkMasks() {
  if (sym.joe_load !== undefined) {
    const mutable = new Set([sym.jm_alpha,sym.jm_bits+1,sym.jm_end+1,
      sym.jb_call+1,sym.jb_call+2,sym.jr_ac+1,sym.jr_mc+1,sym.jr_oc+1]);
    for (let i=0;i<4;i++) {
      const source=sym['joe_source'+i], end=sym['joe_end'+i], target=0xFB30+256*i;
      if (end-source>160) throw Error('Код Джо пересекает маску врага');
      for(let j=0;j<end-source;j++) if(!mutable.has(target+j)) {
        if(m.rd(target+j)!==image[source+j]) throw Error('Повреждён код Джо '+(target+j).toString(16));
        protectedBytes[target+j]=1;
      }
    }
    // 7F00..7F3F is the shift index; IRQ has its own 64-byte stack above it.
    protectedBytes.fill(1,sym.ps_idx,sym.ps_idx+64);
  }
  let count = 0;
  for (let f = 0; f < 12; f++) {
    const nm = m.rd(sym.ps_names + f), R = m.rd(sym.ps_rr + f);
    let first = 16, last = -1;
    for (let y = 0; y < 16; y++) if (REF.sprite(nm, 0, y) | REF.sprite(nm, 1, y)) {
      first = Math.min(first, y); last = y;
    }
    if (R !== last - first + 1) throw new Error('Неверная высота готового кадра ' + nm);
    for (let sh = 0; sh < 8; sh++) {
      const p = m.rd(sym.ps_tab + 16*f + 2*sh) | m.rd(sym.ps_tab + 16*f + 2*sh + 1) << 8;
      if (!p) continue;
      count++; protectedBytes.fill(1, p, p + 3*R);
      for (let y = 0; y < R; y++) {
        const bits = ((REF.sprite(nm, 0, first+y) << 16) | (REF.sprite(nm, 1, first+y) << 8)) >>> sh;
        for (let c = 0; c < 3; c++) if (m.rd(p + c*R + y) !== ((bits >>> (16 - 8*c)) & 255))
          throw new Error('Неверный готовый сдвиг ' + [nm, sh, c, y]);
      }
    }
  }
  if (count < 58) throw new Error('Готовых сдвигов меньше 58: ' + count);
  console.log('готовых сдвигов', count, 'все соответствуют исходной графике MSX');
}
m.onWrite = (a, v) => {
  if (ready && protectedBytes[a]) throw new Error('Перезапись сдвига: ' + a.toString(16) + ' PC=' + lastPC.toString(16));
  if (steps <= 200) return;
  if (a === sym.fire_shown && v !== m.rd(a)) fires++;
  if (a === sym.belt_shown && v !== m.rd(a)) belts++;
};
m.onInstr = pc => {
  lastPC = pc;
  if (pc === sym.L_8DA2 && steps > 60) {
    const c = m.cpu; c.pc = m.rd(c.sp) | m.rd(c.sp + 1) << 8; c.sp += 2; return;
  }
  if (pc === sym.L_A5D1) {
    steps++;
    if (!ready) { checkMasks(); ready = true; }
    m.wr(0x7049, 6); m.wr(0x707C, m.rd(0x7300));
    if (steps === 50) { m.wr(0x705F, m.rd(0x705F) & ~4); m.wr(0x71A7, room[0]); m.wr(0x71A8, room[1]); m.wr(0x7079, 9); }
    if (steps === 200) frame0 = m.frames;
    if (steps > 200) for (let k = 2; k <= lastEnemy; k++) {
      const p = 0x7300 + 4*m.rd(0x72E0 + k), x = m.rd(p+1);
      const z = movement[k] ||= {updates: 0, jump: 0, drawnDistance: 0, gameDistance: 0, maxLag: 0};
      if (sourceOld[k] !== undefined) z.gameDistance += Math.abs(x - sourceOld[k]);
      sourceOld[k] = x;
      z.maxLag = Math.max(z.maxLag, Math.abs(x - m.rd(sym.spr_rec + 16*k + 2)));
    }
  }
  if (pc === sym.spr_put && steps > 200) {
    const k = m.rd(sym.sp_k); if (k < 2 || k > lastEnemy) return;
    const p = sym.spr_new + 16*k, x = m.rd(p+2), z = movement[k];
    if (old[k] !== undefined) {
      const dx = Math.abs(x - old[k]);
      z.jump = Math.max(z.jump, dx); z.drawnDistance += dx;
      if (dx) z.updates++;
    }
    old[k] = x;
  }
};
for (let f = 0; steps < limit; f++) {
  if (f === 10) m.keyboard.matrix[2] |= 2;
  if (f === 100) m.keyboard.matrix[2] &= ~2;
  m.frame();
}
const frames = m.frames - frame0;
console.log('шагов', steps-200, 'кадров', frames, 'смен фаз огня/лент', fires, belts);
for (const [k, z] of Object.entries(movement)) {
  console.log('враг', k, JSON.stringify(z));
  if (z.jump > 3 || z.drawnDistance < 0.85*z.gameDistance || z.maxLag > 12) bad++;
}
if (bad) process.exitCode = 1;
