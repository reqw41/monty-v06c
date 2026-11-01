// Real frame/keyboard path; verify rendering and IRQ cannot overwrite motion RAM.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B);let results=[];
for(const direction of ['left','right']){
 const m=E.mk(B+'/monty.bin');let phase=0,held=0,air=0,minStack=0x73c0,start,end,frame,steps=0,entry=false,seeded=false;
 m.onInstr=pc=>{
  // This test starts its input on a rope. Use an original NES seed whose
  // generated column15 intersects the vertical setup fall; do not rely on
  // code-size-dependent frame timing to randomly provide that prerequisite.
  if(pc===s.L_A60B&&entry&&!seeded){seeded=true;m.wr(0x7047,9);m.wr(0x7048,0);}
  if(phase&&m.cpu.sp>=0x7300&&m.cpu.sp<=0x73c0){minStack=Math.min(minStack,m.cpu.sp);assert(m.cpu.sp>=0x7380,'main stack reached motion RAM');}
  if(pc!==s.L_A5D1)return;
  if(++steps===80&&!entry){entry=true;for(const [a,v]of[[0x71a7,8],[0x71a8,10],[0x705f,0],[0x7079,6],[0x7300,221],[0x7304,224],[0x7301,116],[0x7305,116],[0x7076,0],[0x7077,1]])m.wr(a,v);}
  if(!phase&&(m.rd(0x705f)&32)&&m.rd(0x7079)===4&&++held>5){
   start=[m.rd(0x7305),m.rd(0x7304)];m.keyboard.matrix[0]=direction==='left'?16:64;m.keyboard.matrix[7]=128;phase=1;
  }else if(phase===1&&m.rd(0x7079)===2){phase=2;m.keyboard.matrix[0]=m.keyboard.matrix[7]=0;}
  else if(phase===2&&++air>=25){end=[m.rd(0x7305),m.rd(0x7304),m.rd(0x7079)];phase=3;}
 };
 for(frame=0;frame<1800&&phase<3;frame++){if(frame===10)m.keyboard.matrix[2]=2;if(frame===100)m.keyboard.matrix[2]=0;m.frame();}
 assert.equal(phase,3,'real keyboard rope jump');assert(direction==='left'?end[0]<start[0]:end[0]>start[0]);
 for(let i=0;i<s.nt_motion_end-s.nt_jump_curve;i++)assert.equal(m.rd(s.nt_jump_curve+i),m.img[s.nt_motion_source+i],'motion image survived real rendering/IRQ');
 results.push({direction,frames:frame,start,end,minMainStack:minStack.toString(16),motionImageIntact:true});
}
console.log(JSON.stringify({B,keyboardCases:results}));
