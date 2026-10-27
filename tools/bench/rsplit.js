const fs = require('fs'); process.chdir('/Users/boris/projects/monty-v06c');
const E = require('/Users/boris/projects/monty-v06c/tools/vec_emu');
const sym = {}; for (const l of fs.readFileSync('build/native/monty.sym', 'latin1').split('\n')) { const q = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const m = E.mk('build/native/monty.bin'); const K = (r, b, d) => { if (d) m.keyboard.matrix[r] |= b; else m.keyboard.matrix[r] &= ~b; };
let steps = 0, fc = 0, lf = 0, room = false, rooms = 0; const F = { room: 0, norm: 0 }, C = { room: 0, norm: 0 };
const keys = (s) => { K(7, 0x80, (s >= 20 && s < 30) || (s > 200 && s % 37 < 4)); const ph = s < 100 ? -1 : Math.floor((s - 100) / 70) % 3; K(0, 0x40, ph === 0); K(0, 0x10, ph === 1); };
let roomLeft = 0;
m.onInstr = (pc) => { if (pc === sym.room_redraw) { rooms++; roomLeft = 40; }
  if (pc === sym.L_A5D1) { const d = m.frames - lf; lf = m.frames; if (steps >= 100) { const k = roomLeft > 0 ? 'room' : 'norm'; F[k] += d; C[k]++; } if (roomLeft > 0) roomLeft--; steps++; keys(steps); m.wr(0x7049, 6); } };
while (steps < 3000) { if (fc === 10) K(2, 2, 1); if (fc === 100) K(2, 2, 0); fc++; m.frame(); }
console.log('смен комнаты', rooms, '| шагов рядом со сменой (40 после):', C.room, 'кадров', F.room, '| обычных шагов', C.norm, 'кадров', F.norm, '=> обычный шаг', (F.norm / C.norm).toFixed(2), 'кадра =', (50 * C.norm / F.norm).toFixed(1), 'шаг/с');
