// Exercise the real GAME OVER/fire/warm-start path after bootstrap overlays
// have been reused by tiles. Compare essential state and continue real play.
'use strict';
const assert=require('assert/strict'),fs=require('fs'),path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');
assert.equal(s.SCREEN_HEIGHT,240);
let steps=0,forced=0,restarts=0,entered=false,after=0;
m.onInstr=pc=>{
 if(pc===s.go1){m.keyboard.matrix[7]|=128;}
 if(pc===s.warm_restart){restarts++;m.keyboard.matrix[7]&=~128;entered=true;}
 if(pc===s.L_A59D&&entered){
  assert.equal(m.cpu.regs[0],1,'restart level');
  for(let p=0x70C0;p<0x7186;p++)assert.equal(m.rd(p),0,'persistent flag '+p.toString(16));
  for(const p of [0x7012,0x7068,0x7073,0x7074])assert.equal(m.rd(p),2,'process counter');
  assert.equal(m.rd(0x7303),6);assert.equal(m.rd(0x7307),11);entered=false;
 }
 if(pc===s.L_A5D1){
  steps++;if(restarts===2)after++;
  if((steps===300||steps===650)&&forced<2){
   forced++;m.wr(0x70C0,255);m.wr(0x7017,0x45);m.cpu.sp=s.GSTACK;m.cpu.pc=s.game_over;
  }
 }
};
for(let f=0;after<300&&f<5000;f++){
 if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;
 m.frame();
}
assert.equal(restarts,2);assert(after>=300,'game stopped after restart');
assert.equal(m.rd(0x71A6),1);assert.equal(m.rd(0x71A7),0);assert.equal(m.rd(0x71A8),10);
assert.equal(m.rd(0x7049),6);assert.equal(m.rd(0x7017),0);
console.log(JSON.stringify({B,restarts,stepsAfterSecond:after,room:[m.rd(0x71A7),m.rd(0x71A8)],lives:m.rd(0x7049),bootstrap:'not re-entered'}));
