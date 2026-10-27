// Кадров на N шагов (ввод по номеру шага — как ab.js), node nsteps.js dir... [N]
const fs = require('fs'); process.chdir(require('path').resolve(__dirname, '../..'));
const E = require('../vec_emu');
const args = process.argv.slice(2); const N = /^\d+$/.test(args[args.length - 1]) ? +args.pop() : 2000;
for (const dir of args) {
  const sym = {}; for (const l of fs.readFileSync(dir + '/monty.sym', 'latin1').split('\n')) { const q = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
  const m = E.mk(dir + '/monty.bin'); { const _fr = m.frame; let _fc = 0; m.frame = () => { if (_fc === 10) m.keyboard.matrix[2] |= 2; if (_fc === 100) m.keyboard.matrix[2] &= ~2; _fc++; _fr(); }; } const K = (r, b, d) => { if (d) m.keyboard.matrix[r] |= b; else m.keyboard.matrix[r] &= ~b; };
  let steps = 0, f = 0, f0 = 0;
  const keys = (s) => { K(7, 0x80, (s >= 20 && s < 30) || (s > 200 && s % 37 < 4)); const ph = s < 100 ? -1 : Math.floor((s - 100) / 70) % 3;
    K(0, 0x40, ph === 0); K(0, 0x10, ph === 1); };
  m.onInstr = (pc) => { if (pc === sym.L_A5D1) { steps++; if (steps === 100) f0 = f; keys(steps); m.wr(0x7049, 6); } };
  for (f = 0; steps < N; f++) m.frame();
  console.log(dir, `шаги 100..${N}: ${f - f0} кадров, ${((N - 100) * 50 / (f - f0)).toFixed(1)} шаг/с`);
}
