// A previous jump must not prevent catching a rope when walking off its cap.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
const boot=m.memory.bytes.slice();
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.sp=0x73be;c.pc=s[name];m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');if(c.pc===s.L_8C13)c.pc=s.L_A067;c.instruction();}}
let cases=0;
for(let counter=0;counter<=18;counter++)for(let parity=0;parity<2;parity++){
 m.memory.bytes.set(boot);m.wr(0x71a7,1);m.wr(0x71a8,10);m.wr(0x705f,0);m.wr(s.nes_q_idle,1);
 for(let a=0x70c0;a<0x7186;a++)m.wr(a,255);call('L_A067');
 for(const a of [0x7300,0x707c])m.wr(a,92);m.wr(0x7304,95);
 for(const a of [0x7301,0x7305])m.wr(a,18+parity);
 for(const a of [0x7079,0x7076,0x7077])m.wr(a,0);m.wr(0x7072,counter);
 for(let n=0;n<65;n++){
  m.wr(s.kbmat,16);call('L_88D1');
  assert.equal(m.rd(0x7304),95,`fell through cap: jump=${counter}, parity=${parity}, step=${n}`);
 }
 assert.equal(m.rd(0x71a8),9);assert.equal(m.rd(0x7305),196);assert.equal(m.rd(0x7079),4,'walking attaches without Down');
 for(let n=0;n<24;n++){m.wr(s.kbmat,128);call('L_88D1');assert.equal(m.rd(0x7079),4);}
 assert.equal(m.rd(0x7304),119);cases++;
}
let realFrames=0;
for(const counter of [0,14,15,18])for(let parity=0;parity<2;parity++){
 const v=E.mk(B+'/monty.bin');let steps=0,phase=0,held=0;
 v.onInstr=pc=>{if(pc!==s.L_A5D1)return;steps++;
  if(steps===80){for(const [a,b]of [[0x71a7,1],[0x71a8,10],[0x705f,0],[0x7300,92],[0x7304,95],[0x7301,18+parity],[0x7305,18+parity],[0x7079,0],[0x7076,0],[0x7077,0],[0x707c,92],[0x7072,counter]])v.wr(a,b);
   for(let a=0x70c0;a<0x7186;a++)v.wr(a,255);const c=v.cpu;c.sp-=2;v.wr(c.sp,pc&255);v.wr(c.sp+1,pc>>8);c.pc=s.L_A067;v.keyboard.matrix[0]=16;phase=1;return;}
  if(phase===1&&v.rd(0x71a8)===9){assert.equal(v.rd(0x7304),95,'live keyboard walk fell');if(v.rd(0x7079)===4&&++held===12)phase=2;}
 };
 for(let f=0;f<600&&phase<2;f++){if(f===10)v.keyboard.matrix[2]|=2;if(f===100)v.keyboard.matrix[2]&=~2;v.frame();}
 assert.equal(phase,2,'live walk did not catch and hold rope');realFrames++;
}
console.log(JSON.stringify({B,cases,realFrameCases:realFrames,route:'1,10 -> 1,9, Left only -> rope',previousJumpCounter:'0..18',fall:false}));
