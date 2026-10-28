// NES start-room key must remain taken after a room redraw (including death).
const assert=require('node:assert/strict'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');
function call(name,a=0){const c=m.cpu;c.iff=false;c.iff_pending=0;c.sp=0x73be;c.pc=s[name];c.regs[7]=a;
 m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');c.instruction();}}
const key=0x204,cell=s.FIELD_VNT+key-192,tiles=()=>[0,1,32,33].map(i=>m.rd(cell+i));
m.wr(0x71a6,1);m.wr(0x71a7,0);m.wr(0x71a8,10);m.wr(0x7049,6);m.wr(0x70b3,0);m.wr(s.nes_q_idle,1);
for(let i=0;i<198;i++)m.wr(0x70c0+i,0);
for(let i=0;i<7;i++)m.wr(0x71b2+i,255);
for(let i=0;i<8;i++)m.wr(0x7300+i,[75,120,52,6,78,120,152,11][i]);
for(let i=0x7308;i<0x7329;i++)m.wr(i,0);
call('L_A067');assert.deepEqual(tiles(),[0x70,0x71,0x72,0x73]);
m.wr(0x71b0,key&255);m.wr(0x71b1,key>>8);call('L_901B',0x62);
assert.equal(m.rd(0x71b2),0x62,'key in inventory');
assert.equal(m.rd(0x70c4)&4,4,'persistent key flag');
call('L_A067');assert.deepEqual(tiles(),[0,0,0,0],'key absent after redraw');
console.log(JSON.stringify({B,key:'0,10 white',inventory:0x62,persistentFlag:m.rd(0x70c4),afterRedraw:tiles()}));
