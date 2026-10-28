// Regression for entering and descending the right rope in NES room (1,9).
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.sp=0x73be;c.pc=s[name];m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');c.instruction();}}
m.wr(0x71a6,1);m.wr(0x71a7,1);m.wr(0x71a8,9);m.wr(0x7049,6);m.wr(0x70b3,0);m.wr(s.nes_q_idle,1);
for(let i=0;i<198;i++)m.wr(0x70c0+i,0);for(let i=0;i<7;i++)m.wr(0x71b2+i,255);
for(let i=0;i<8;i++)m.wr(0x7300+i,[110,196,52,6,113,196,152,11][i]);for(let i=0x7308;i<0x7329;i++)m.wr(i,0);
call('L_A067');m.wr(0x7079,4);m.wr(0x7076,0);m.wr(0x7077,0);
for(let i=0;i<35;i++){m.wr(s.kbmat,0x20);call('L_9156');call('L_88D1');}
assert.deepEqual([m.rd(0x7304),m.rd(0x7305),m.rd(0x7079)],[95,204,0]);
let trace=[];
for(let i=0;i<45;i++){m.wr(s.kbmat,0x80);call('L_9156');trace.push([i,m.rd(0x7304),m.rd(0x7305),m.rd(0x7079)]);call('L_88D1');}
assert.equal(trace[0][3],0,'Joe starts standing on the ledge');
assert.equal(trace[1][3],4,'Down attaches Joe to the rope');
assert(trace.every(row=>row[3]!==6),'Joe does not fall while descending');
assert.deepEqual([m.rd(0x7304),m.rd(0x7305),m.rd(0x7079)],[139,196,4]);
console.log(JSON.stringify({B,room:'1,9',start:[95,204],end:[m.rd(0x7304),m.rd(0x7305)],state:m.rd(0x7079)}));
