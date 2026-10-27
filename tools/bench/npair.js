const fs = require('fs'); process.chdir('/Users/boris/projects/monty-v06c');
const E = require('/Users/boris/projects/monty-v06c/tools/vec_emu');
const sym = {}; for (const l of fs.readFileSync('build/native/monty.sym', 'latin1').split('\n')) { const m = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (m) sym[m[1]] = parseInt(m[2], 16); }
const m = E.mk('build/native/monty.bin'); { const _fr = m.frame; let _fc = 0; m.frame = () => { if (_fc === 10) m.keyboard.matrix[2] |= 2; if (_fc === 100) m.keyboard.matrix[2] &= ~2; _fc++; _fr(); }; } const K = (r, b, d) => { if (d) m.keyboard.matrix[r] |= b; else m.keyboard.matrix[r] &= ~b; };
const R = m.cpu.regs; let pc = 0, f = 0; const src = {}; let bad = 0, ok = 0; const ex = [];
const HL = () => (R[4] << 8) | R[5], DE = () => (R[2] << 8) | R[3];
const sv0 = sym.st_sv, sv1 = sym.st_rs, rs1 = sym.st_rs + 23 * 4 + 1;
m.onInstr = (p) => { pc = p; };
m.onWrite = (a, v) => {
  if (pc >= sv0 && pc < sv1 && a >= 0xF900 && a < 0xFF00) src[a] = HL();           // ld (de),a: HL — откуда
  if (pc >= sv1 && pc < rs1 && a >= 0x8000 && a < 0xE000) { const s = src[DE()]; if (s === a) ok++; else { bad++; if (ex.length < 8) ex.push(`f${f} slot ${DE().toString(16)} -> ${a.toString(16)} saved from ${s && s.toString(16)}`); } }
};
console.log('regs', R.length, 'st_sv', sv0.toString(16));
for (f = 0; f < 900; f++) { if (f === 130) K(7, 0x80, 1); if (f === 140) K(7, 0x80, 0); m.frame(); }
console.log('ok', ok, 'bad', bad); console.log(ex.join('\n'));
