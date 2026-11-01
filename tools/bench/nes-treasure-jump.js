// Execute original NES rope-jump sequences against the real native hero step.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]=2;if(f===100)m.keyboard.matrix[2]=0;m.frame();}
const base=m.memory.bytes.slice(),ref=JSON.parse(fs.readFileSync('build/nes-treasure/jump-reference.json'));let minStack=0x73c0;
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung at '+c.pc.toString(16));
  if(c.sp>=0x7300&&c.sp<=0x73c0){minStack=Math.min(minStack,c.sp);assert(c.sp>=0x7380,'main stack reached the motion image');}c.instruction();}}
function checkImage(){for(let i=0;i<s.nt_motion_end-s.nt_jump_curve;i++)assert.equal(m.rd(s.nt_jump_curve+i),m.img[s.nt_motion_source+i],'motion image overwritten '+i);}
checkImage();
for(const r of ref){
 m.memory.bytes.set(base);for(let i=192;i<960;i++)m.wr(s.VNT+i,0);
 for(let row=12;row<18;row++)m.wr(s.VNT+row*32+15,0x95);
 if(r.target!==null)for(let row=9;row<25;row++)m.wr(s.VNT+row*32+r.target,0x95);
 for(const [a,v]of [[0x705f,32],[0x7079,4],[0x7076,0],[0x7077,0],[0x7072,0],[0x7300,r.y+4],[0x7304,r.y+7],[0x7301,116],[0x7305,116],[0x7075,128],[0x70ac,178]])m.wr(a,v);
 for(let n=0;n<r.trace.length;n++){
  const key=(!r.held&&n>0)?128:r.direction==='left'?200:194;m.wr(0x73ee,key);m.wr(0x70ab,n%4);
  call('L_9156');call('hero_state');call('L_8DE8');
  const state=m.rd(0x7079),got=[m.rd(0x7305),m.rd(0x7304)-7,({2:2,4:64,6:1})[state]];
  assert.deepEqual(got,r.trace[n],JSON.stringify({y:r.y,direction:r.direction,held:r.held,target:r.target,step:n,state}));checkImage();
 }
}
console.log(JSON.stringify({B,originalNESCases:ref.length,comparedSteps:ref.length*45,initialDisplacement:0,riseSteps:16,sideMomentumAfterRelease:true,motionImageIntact:true,minMainStack:minStack.toString(16)}));
