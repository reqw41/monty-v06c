// Actual beam frames must contain a complete Joe pose, before or after a paint.
// Wrap the real-keyboard pacing workload, retaining every original assertion.
'use strict';
const path=require('path'),assert=require('assert/strict');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),joe=require('./joe-ref');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),mk=E.mk,results=[];
E.mk=(...args)=>{
 const m=mk(...args);let hook=null,steps=0,paint=null,latest=null,candidates=[];
 const q={frames:0,partial:0,examples:[]};results.push(q);
 function snapshot(){const points=[],palette=m.palette();joe(m,s,(x,y)=>{const a=(x>>3)*256+s.SCREEN_TOP-s.FIELD_YSHIFT-y,bit=128>>(x&7),ink=(m.rd(0x8000+a)&bit?4:0)|(m.rd(0xa000+a)&bit?2:0)|(m.rd(0xc000+a)&bit?1:0);points.push([(16+s.FIELD_YSHIFT+y)*576+32+2*x,palette[2*ink]]);});return points.length?points:null;}
 Object.defineProperty(m,'onInstr',{get:()=>pc=>{
  if(paint&&pc===paint.pc&&m.cpu.sp===paint.sp+2){latest=snapshot();if(latest)candidates.push(latest);paint=null;}
  if(pc===s.joe_put){const sp=m.cpu.sp;paint={sp,pc:m.rd(sp)|(m.rd(sp+1)<<8)};}
  if(pc===s.L_A5D1)steps++;
  if(hook)hook(pc);
 },set:fn=>{hook=fn;}});
 const frame=m.frame;m.frame=()=>{candidates=latest?[latest]:[];frame();if(steps<150||!latest)return;q.frames++;if(!candidates.some(points=>points.every(([a,c])=>m.v06c.bmp[a]===c))){q.partial++;if(q.examples.length<5)q.examples.push({frame:m.frames,x:m.rd(s.spr_rec+2),y:m.rd(s.spr_rec+1),state:m.rd(0x7079)});}};
 return m;
};
process.on('exit',()=>{console.log('Raster',JSON.stringify({B,results}));if(!process.env.ALLOW_TEAR)for(const q of results)assert.equal(q.partial,0,'partial Joe pose in a beam-rendered frame');});
process.env.LIVE='1';process.env.ROOM='1,9';require('./nes-frame-pacing');
