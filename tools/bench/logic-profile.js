// Accounting at instruction boundaries: vcycles belongs to the previous PC.
// IRQ and disp_prep switch stacks, so SP ordering cannot identify their return.
'use strict';
const fs = require('fs');
function symbols(dir) {
  const out = {};
  for (const l of fs.readFileSync(dir + '/monty.sym', 'latin1').split('\n')) {
    const q = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i);
    if (q) out[q[1]] = parseInt(q[2], 16);
  }
  return out;
}
function profiler(m, s) {
  let irq = null, display = false, previous = 'L';
  const totals = {L: 0, D: 0, I: 0, W: 0};
  return {totals, instruction(pc) {
    const elapsed = m.cpu.vcycles || 0;
    totals[previous] += elapsed;
    if (irq && pc === irq.pc && m.cpu.sp === irq.sp + 2) irq = null;
    if (pc === 0x38 && !irq) irq = {sp: m.cpu.sp, pc: m.rd(m.cpu.sp) | m.rd(m.cpu.sp + 1) << 8};
    if (!irq) {
      if (pc === s.disp_prep) display = true;
      if (pc === s.fw_return) display = false;
    }
    previous = irq ? 'I' : display ? 'D' : pc >= s.fw2 && pc < s.fw2 + 7 ? 'W' : 'L';
    return previous;
  }};
}
module.exports = {symbols, profiler};
