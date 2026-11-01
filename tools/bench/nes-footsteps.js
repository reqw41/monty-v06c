// Foot plants start the short noise click (nes_step_stream); idle, blocked walking and airborne poses stay silent;
// ladder/rope poses click on every pose change (jn_tick 4, 8). joe_clock preserves all registers and flags.
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
const fired=()=>{const hit=(m.rd(s.nes_n_ptr)|m.rd(s.nes_n_ptr+1)<<8)===s.nes_step_stream&&m.rd(s.nes_n_wait)===1;m.wr(s.nes_n_wait,0);m.wr(s.nes_n_ptr,0);m.wr(s.nes_n_ptr+1,0);return hit;};
for(let state=0;state<=10;state++)for(const dx of [0,1,255]){
 if(state===3||state===4)continue;   // лестница и канат — отдельная проверка ниже
 m.wr(0x7079,state);m.wr(0x7076,dx);m.wr(0x7077,0);
 m.wr(s.jn_tick,0);m.wr(s.jn_walk,0);m.wr(s.nes_n_wait,0);let count=0;
 for(let tick=1;tick<=48;tick++){
  clock();
  if(fired()){
   assert.equal(state,1);assert.notEqual(dx,0);
   assert.equal(tick%12,0);assert.equal(m.rd(s.jn_walk)&1,0);count++;
  }
 }
 assert.equal(count,state===1&&dx!==0?4:0);clicks+=count;cases++;
}
// лестница и канат (состояния 3, 4) при движении: щелчок на каждой смене позы
for(const state of [3,4]){
 m.wr(0x7079,state);m.wr(0x7076,0);m.wr(0x7077,1);m.wr(s.jn_tick,0);m.wr(s.nes_n_wait,0);let count=0;
 for(let tick=1;tick<=32;tick++){clock();if(fired())count++;}
 assert.equal(count,8,'состояние '+state+': щелчок каждые 4 тика');clicks+=count;cases++;
}
console.log(JSON.stringify({B,cases,clicks,footPlantPeriod:12,ladderStepPeriod:4,registersPreserved:true}));
