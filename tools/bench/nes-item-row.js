// NES_FULL uses only L_A378's two-cell row writer, including NT boundary clips.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin'),original=fs.readFileSync('build/monty_entry.bin');
function call(set,offset){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s.L_A378;c.sp=0x73be;c.regs[7]=set;c.regs[0]=0x56;c.regs[1]=0x78;c.regs[2]=offset>>8;c.regs[3]=offset&255;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,'item draw hung');c.instruction();}assert.equal(c.regs[0],1);assert.equal(c.regs[1],2);assert.equal(c.de(),offset);}
m.wr(s.nes_q_idle,1);let cases=0;
for(const set of [0x0b,0x44,0x49,0x4e,0x53,0x58,0x5d,0x62,0x67,0x6e,0x75,0x7c,0x81])for(const offset of [0,191,192,223,448,925,927,928,958,959,960,1023]){
 for(let i=0;i<960;i++)m.wr(s.VNT+i,0xcc);
 m.wr(s.VNT-1,0xa5);m.wr(s.VNT+960,0x5a);m.wr(s.video_dirty,s.DIRTY_ROOM);
 const want=Array(960).fill(0xcc);for(const [i,d]of[0,1,32,33].entries())if(offset+d<960)want[offset+d]=original[0x9fd2+set+i];
 call(set,offset);assert.deepEqual(Array.from({length:960},(_,i)=>m.rd(s.VNT+i)),want,'item row '+[set,offset]);assert.equal(m.rd(s.VNT-1),0xa5);assert.equal(m.rd(s.VNT+960),0x5a);assert.equal(m.rd(s.video_edit),0);cases++;
}
console.log(JSON.stringify({B,cases,rows:'native two-cell writer',bounds:'clean',destination:'preserved'}));
