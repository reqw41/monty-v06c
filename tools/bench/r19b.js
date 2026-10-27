const fs = require('fs'); process.chdir('/Users/boris/projects/monty-v06c');
const E = require('/Users/boris/projects/monty-v06c/tools/vec_emu');
const sym = {}; for (const l of fs.readFileSync((process.env.B||'build/native')+'/monty.sym', 'latin1').split('\n')) { const q = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const m = E.mk((process.env.B||'build/native')+'/monty.bin'); let steps = 0, fc = 0, da = 0, sf = 0; const D = [];
m.onInstr = (pc) => { if (pc === sym.draw_all) da++; if (pc === sym.L_8DA2 && steps > 60) { const c = m.cpu; c.pc = m.rd(c.sp) | (m.rd(c.sp + 1) << 8); c.sp += 2; return; }
  if (pc === sym.L_A5D1) { steps++; m.wr(0x7049, 6); m.wr(0x707C, m.rd(0x7300)); if (steps === 50) { m.wr(0x705F, m.rd(0x705F) & ~4); m.wr(0x71A7, 1); m.wr(0x71A8, 9); m.wr(0x7079, 9); }
    if (steps > 60 && steps < 400 && steps % 10 == 0) console.log(steps, m.rd(0x7079), m.rd(0x7300), m.rd(0x7301), m.rd(0x71A7), m.rd(0x71A8)); if (steps > 160) D.push([m.frames - sf, da]); sf = m.frames; da = 0; } };
while (steps < 760) { if (fc === 10) m.keyboard.matrix[2] |= 2; if (fc === 100) m.keyboard.matrix[2] &= ~2; fc++; m.frame(); }
// окна гибели: шаги с draw_all ± 40 исключить
const bad = new Set(); D.forEach((d, i) => { if (d[1]) for (let j = i - 60; j < i + 60; j++) bad.add(j); });
const ok = D.filter((d, i) => !bad.has(i)); const s = ok.reduce((a, d) => a + d[0], 0);
console.log('draw_all', D.filter(d => d[1]).length, 'чистых шагов', ok.length, 'кадров/шаг', (s / ok.length).toFixed(3), '=', (50 * ok.length / s).toFixed(1), 'шаг/с');
const h = {}; ok.forEach(d => h[d[0]] = (h[d[0]] || 0) + 1); console.log('распределение кадров на шаг', JSON.stringify(h));
