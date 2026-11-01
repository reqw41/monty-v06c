// Start-room right door: NES $9C50 increments room index 2 -> 3 while
// $079A (floor 1) stays unchanged. The native equivalent is 0,10 -> 0,11.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
let steps=0,phase=0,opened=0,clamps=0,returned=false;
m.onInstr=pc=>{
 if(pc===s.nf_room_edge)clamps++;
 if(pc===s.L_A3F1)opened++;
 if(pc!==s.L_A5D1)return;
 steps++;
 if(phase===0&&steps===80){
  // Place Joe on the right ledge with its white key. The actual door
  // collision, key consumption, redraw and both exits run unmodified.
  m.wr(0x7300,92);m.wr(0x7304,95);
  m.wr(0x7301,216);m.wr(0x7305,216);
  m.wr(0x7079,0);m.wr(0x7076,0);m.wr(0x7077,0);
  m.wr(0x705f,m.rd(0x705f)&~4);m.wr(0x71b2,0x62);
  m.keyboard.matrix[0]=0x40;phase=1;
 }else if(phase===1&&m.rd(0x71a5)===3){
  assert.deepEqual([m.rd(0x71a7),m.rd(0x71a8)],[0,11]);
  assert.equal(m.rd(0x71b2),255,'key consumed');assert.equal(opened,1);
  m.keyboard.matrix[0]=0x10;phase=2;
 }else if(phase===2&&m.rd(0x71a5)===2){
  assert.deepEqual([m.rd(0x71a7),m.rd(0x71a8)],[0,10]);
  assert.equal(m.rd(s.VNT+13*32+29),0xc5,'door remains open after return');
  assert.equal(m.rd(0x71b2),255,'key is not restored');
  m.keyboard.matrix[0]=0;returned=true;
 }
};
for(let f=0;f<500&&!returned;f++){
 if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();
}
assert(returned,'Joe must leave through the opened right door and return');
assert.equal(clamps,0,'valid horizontal transitions must not be rejected');
console.log(JSON.stringify({B,route:'index 2 -> 3 -> 2, floor unchanged',steps,doorPersists:true,keyConsumed:true,clamps}));
