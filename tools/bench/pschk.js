const fs = require('fs'); process.chdir(require('path').resolve(__dirname, '../..'));
const E = require('../vec_emu'); const B = process.env.B || 'build/native';
const sym = {}; for (const l of fs.readFileSync(B + '/monty.sym', 'latin1').split('\n')) { const q = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const m = E.mk(B + '/monty.bin'); for (let i = 0; i < 200; i++) m.frame();
let ok = 0, miss = 0; for (let i = 0; i < 8 * 12; i++) { const a = m.rd(sym.ps_tab + 2 * i) | (m.rd(sym.ps_tab + 2 * i + 1) << 8); a ? ok++ : miss++; }
console.log('ps_heap', sym.ps_heap.toString(16), 'сдвигов есть', ok, 'нет', miss);
