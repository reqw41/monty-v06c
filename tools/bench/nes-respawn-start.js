// First landing and all death routes must restore the aligned platform anchor.
// Observe every startup/HUD write: no accent-coloured lower-score intermediate.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B);let cases=0,scoreWrites=0;
for(const death of [8,9,10]){
 const m=E.mk(B+'/monty.bin');let steps=0,forced=false,restored=false,scoreChanged=false,native=false;
 m.onWrite=(a,v)=>{if(native&&((a>=0x9200&&a<0x9e00)||(a>=0xd200&&a<0xde00))&&(a&255)>=216&&(a&255)<=223){assert.equal(v,0,'transient accent in lower score during startup/update');scoreWrites++;}};
 m.onInstr=pc=>{
  if(pc===s.room_redraw)native=true;if(pc===s.title_resume)native=false;
  if(pc===s.L_8C13&&forced&&m.rd(0x7079)<8){
   assert.deepEqual([m.rd(0x7300),m.rd(0x7304),m.rd(0x7305)],[91,94,116],'first restored frame is above the platform');
   assert.equal(m.rd(0x7079),0,'standing respawn');assert.equal(m.rd(0x7077),0,'no saved falling motion');restored=true;
  }
  if(pc!==s.L_A5D1)return;steps++;
  if(steps===80){
   assert.deepEqual([m.rd(0x704b),m.rd(0x704f),m.rd(0x7050)],[91,94,116],'aligned first checkpoint');
   assert.equal(m.rd(0x707f),0);assert.equal(m.rd(0x707d),0);
   m.wr(0x7017,0x12);m.wr(0x7018,0x34);m.wr(0x7019,0x56);
   const c=m.cpu;c.sp-=2;m.wr(c.sp,pc&255);m.wr(c.sp+1,pc>>8);c.pc=s.L_A548;scoreChanged=true;
  }
  if(steps===100){m.wr(0x7079,death);m.wr(0x70a9,0);m.wr(0x7049,6);forced=true;}
 };
 for(let f=0;f<500&&!restored;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
 assert(forced&&restored&&scoreChanged,'startup, update and death route completed');cases++;
}
console.log(JSON.stringify({B,cases,deathStates:[8,9,10],respawn:[91,94,116],standing:true,scoreWrites,transientAccentWrites:0}));
// The landing correction can be 0..3 pixels, depending on fall phase.
{
 const m=E.mk(B+'/monty.bin');for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
 const boot=m.memory.bytes.slice();
 function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<400000,name+' hung');if(c.pc===s.L_8C13){c.pc=s.unit_trap;break;}c.instruction();}}
 for(let over=0;over<4;over++)for(const death of [8,9,10]){
  m.memory.bytes.set(boot);m.wr(0x7300,91+over);m.wr(0x7304,94+over);m.wr(0x7301,120);m.wr(0x7305,120);
  m.wr(0x705f,m.rd(0x705f)|4);m.wr(0x7079,5);m.wr(0x7076,0);m.wr(0x7077,4);m.wr(s.kbmat,0);call('L_88D1');
  assert.deepEqual([m.rd(0x704b),m.rd(0x704f),m.rd(0x7050),m.rd(0x707f),m.rd(0x707d)],[91,94,120,0,0],'aligned landing checkpoint at overshoot '+over);
  m.wr(0x7079,death);m.wr(0x70a9,0);call('hs_8B8E');call('L_9156');
  assert.deepEqual([m.rd(0x7300),m.rd(0x7304),m.rd(0x7305),m.rd(0x7079),m.rd(0x7077)],[91,94,120,0,0],'restored landing at overshoot '+over);
  assert.notEqual(m.rd(0x7058),8,'body must not be embedded in brick');
 }
 console.log(JSON.stringify({B,landingOffsets:4,deathStates:3,additionalCases:12,insideBrick:false}));
}
