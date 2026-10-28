// Regression for the right chain in NES room (1,9): Up lands Joe on the ledge.
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.sp=0x73be;c.pc=s[name];m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');c.instruction();}}
m.wr(0x71a6,1);m.wr(0x71a7,1);m.wr(0x71a8,9);m.wr(0x7049,6);m.wr(0x70b3,0);m.wr(s.nes_q_idle,1);
for(let i=0;i<198;i++)m.wr(0x70c0+i,0);for(let i=0;i<7;i++)m.wr(0x71b2+i,255);
for(let i=0;i<8;i++)m.wr(0x7300+i,[110,196,52,6,113,196,152,11][i]);for(let i=0x7308;i<0x7329;i++)m.wr(i,0);
call('L_A067');m.wr(0x7079,4);m.wr(0x7076,0);m.wr(0x7077,0);
for(let i=0;i<35;i++){m.wr(s.kbmat,0x20);call('L_9156');call('L_88D1');}
assert.equal(m.rd(0x7304),95,'Joe reached ledge height');assert.equal(m.rd(0x7305),204,'Joe moved from chain to right ledge');assert.equal(m.rd(0x7079),0,'Joe stands after climbing');
for(let i=0;i<10;i++){m.wr(s.kbmat,0x40);call('L_9156');call('L_88D1');}
assert(m.rd(0x7305)>204,'Joe walks right on the platform');assert.equal(m.rd(0x7304),95,'Joe does not fall');
console.log(JSON.stringify({B,room:'1,9',chain:'right',landed:[95,204],walkedTo:m.rd(0x7305)}));
