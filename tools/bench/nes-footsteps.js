// Foot plants drive PC0; idle, blocked walking, ladders and airborne poses stay silent.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-blend80-sp',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<320;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
function clock(){
 const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s.joe_clock;c.sp=0x73BE;
 for(let r=0;r<8;r++)c.regs[r]=17*r+3;
 c.retrieve_flags(0xD7);const regs=Array.from(c.regs),flags=c.store_flags();
 m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000,'joe_clock hung');c.instruction();m.io.commit();}
 assert.deepEqual(Array.from(c.regs),regs);assert.equal(c.store_flags(),flags);
 assert.equal(c.sp,0x73C0);
}
let cases=0,clicks=0;
for(let state=0;state<=10;state++)for(const dx of [0,1,255]){
 m.wr(0x7079,state);m.wr(0x7076,dx);m.wr(0x7077,0);
 m.wr(s.jn_tick,0);m.wr(s.jn_walk,0);let count=0;
 for(let tick=1;tick<=48;tick++){
  m.outs=[];m.io.PC=0xA8;clock();
  if(m.outs.length){
   assert.deepEqual(m.outs,[0,1]);assert.equal(state,1);assert.notEqual(dx,0);
   assert.equal(tick%12,0);assert.equal(m.rd(s.jn_walk)&1,0);
   assert.equal(m.io.PC,0xA9,'BSR preserves other port C bits');count++;
  }else assert.equal(m.io.PC,0xA8);
 }
 assert.equal(count,state===1&&dx!==0?4:0);clicks+=count;cases++;
}
// IRQ must end the pulse even when keyboard scanning was not requested.
m.wr(s.kb_req,0);m.cpu.pc=s.isr;m.cpu.sp=0x73BE;m.io.PC=0xA9;m.outs=[];
for(let n=0;m.cpu.pc!==s.isr1;n++){assert(n<100,'ISR prefix hung');m.cpu.instruction();m.io.commit();}
assert.deepEqual(m.outs,[0,0]);assert.equal(m.io.PC,0xA8);
console.log(JSON.stringify({B,cases,clicks,footPlantPeriod:12,registersPreserved:true,irqClearsWithoutKeyboard:true}));
