const fs = require('fs'); process.chdir('/Users/boris/projects/monty-v06c');
const E = require('/Users/boris/projects/monty-v06c/tools/vec_emu'); const B = 'build/native';
const sym = {}; for (const l of fs.readFileSync(B + '/monty.sym', 'latin1').split('\n')) { const q = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const m = E.mk(B + '/monty.bin'); let steps = 0, fc = 0, red = 0, f0 = 0, nred = 0, nfr = 0, lastName = -1; const rows = [];
m.onInstr = (pc) => {
  if (pc === sym.draw1 && m.cpu.regs && steps > 300) { /* B = номер */ }
  if (pc === sym.spr_put && m.rd(sym.sp_k) === 2) red++;
  if (pc === sym.L_8DA2 && steps > 60) { const c = m.cpu; c.pc = m.rd(c.sp) | (m.rd(c.sp + 1) << 8); c.sp += 2; return; }
  if (pc === sym.L_A5D1) { steps++; m.wr(0x7049, 6); m.wr(0x707C, m.rd(0x7300)); if (steps === 50) { m.wr(0x705F, m.rd(0x705F) & ~4); m.wr(0x71A7, 1); m.wr(0x71A8, 9); m.wr(0x7079, 9); }
    if (steps === 300) { f0 = m.frames; red = 0; }
    if (steps > 300) { const nm = m.rd(0x730A) & 0xFC; if (nm !== lastName) nfr++; lastName = nm; nred += red;
      if (rows.length < 30) rows.push(`шаг ${steps - 300}: X=${m.rd(0x7309)} кадр ${nm.toString(16)}${red ? '  <- перерисован на экране' : ''}`); red = 0; } } };
while (steps < 800) { if (fc === 10) m.keyboard.matrix[2] |= 2; if (fc === 100) m.keyboard.matrix[2] &= ~2; fc++; m.frame(); }
console.log(rows.join('\n')); const sec = (m.frames - f0) / 50;
console.log(`за ${sec.toFixed(1)} с (500 шагов): перерисован ${nred} раз = ${(nred / sec).toFixed(1)} раз/с; смен кадра ${nfr} = ${(nfr / sec).toFixed(1)} раз/с; шагов/с ${(500 / sec).toFixed(1)}`);
