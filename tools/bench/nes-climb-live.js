// Real-frame regressions for each distinct local climb-cap geometry.
'use strict';
const fs=require('node:fs'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),input=JSON.parse(fs.readFileSync(process.env.CASES||'build/climb-audit/live-cases.json'));
const results=[];
for(const q of input)for(const approach of q.test==='cap-down'&&q.kind==='ladder'?[-1,1]:[q.side]){
 const m=E.mk(B+'/monty.bin'),down=q.test==='cap-down',idle=q.test==='cap-idle',base=q.x*8-(q.kind==='ladder'?1:4),ledge=q.ledgeY;
 let steps=0,phase=0,t0=0,trace=[],loaded=false,walking=true;
 m.onInstr=pc=>{
  if(pc!==s.L_A5D1)return;steps++;
  if(steps===80){
   m.wr(0x71a6,q.level);m.wr(0x71a7,q.room[0]);m.wr(0x71a8,q.room[1]);m.wr(0x705f,0);for(let a=0x70c0;a<0x7186;a++)m.wr(a,255);
   let x=Math.max(4,Math.min(239,base+(idle?2:down?approach*18:0)));const y=ledge+(down||idle?0:16);
   if(down){
    const target=base+(q.kind==='ladder'?approach*2:approach*8),row=Math.floor((y+17)/8);
    for(let px=Math.min(x,target);px<=Math.max(x,target);px++){
     const middle=Math.ceil((px+1)/8),leading=middle+(approach<0?1:-1);
     if([8,0x38,0xe0,0xd2,0xd3,0xd4,0xd5].includes(q.nt[(row-1)*32+middle])||q.nt[(row-1)*32+leading]===8)walking=false;
    }
    const cell=Math.ceil((x+1)/8),foot=q.nt[row*32+cell],body=q.nt[(row-1)*32+cell];
    const floor=[8,11,16,17,4,5,6,0xb8,0xb9,0xba,0xe8].includes(foot);
    if(!floor||[8,0x38,0xe0,0xd2,0xd3,0xd4,0xd5].includes(body))walking=false;
    if(!walking)x=base;
   }
   m.wr(0x7300,y-3);m.wr(0x7304,y);m.wr(0x7301,x);m.wr(0x7305,x);m.wr(0x7079,idle?1:down?0:q.kind==='ladder'?3:4);m.wr(0x70b2,0);m.wr(0x7076,0);m.wr(0x7077,0);m.wr(0x707c,y-3);
   const c=m.cpu;c.sp-=2;m.wr(c.sp,pc&255);m.wr(c.sp+1,pc>>8);c.pc=s.L_A067;
   phase=down?(walking?1:2):3;t0=steps;m.keyboard.matrix[0]=idle?0:down?(walking?(approach<0?64:16):0):32;loaded=true;return;
  }
  if(phase===1){
   const x=m.rd(0x7305),target=base+(q.kind==='ladder'?approach*2:approach*8);
   if(approach<0?x>=target:x<=target){phase=2;t0=steps;m.keyboard.matrix[0]=0;}
   if(steps>140)phase=4;
  }
  if(phase===2&&steps-t0>=2){phase=3;t0=steps;m.keyboard.matrix[0]=128;}
  if(phase===3){trace.push([m.frames,m.rd(0x7304),m.rd(0x7305),m.rd(0x7079),m.rd(s.kbmat)]);if(idle?trace.length>=16:down?(trace.at(-1)[1]>=ledge+12||trace.length>=24):trace.length>=44)phase=4;}
 };
 for(let frame=0;frame<420&&phase!==4;frame++){if(frame===10)m.keyboard.matrix[2]|=2;if(frame===100)m.keyboard.matrix[2]&=~2;m.frame();}
 const end=trace.at(-1),ok=loaded&&end&&(idle?end[1]===ledge&&end[2]===base&&end[3]===4&&trace.every(z=>z[1]===ledge):down?end[1]>ledge&&[3,4].includes(end[3])&&trace.every(z=>z[1]<=ledge+8||[3,4].includes(z[3])):end[1]<=ledge+1&&[0,3].includes(end[3]));
 results.push({index:q.index,level:q.level,kind:q.kind,top:q.top,bottom:q.bottom,x:q.x,test:q.test,approach,walking,ok:!!ok,trace});
 if(results.length%10===0)console.log('checked',results.length);
}
const summary={B,cases:results.length,failures:results.filter(q=>!q.ok)};
const report=process.env.OUT||'build/climb-audit/live.json';fs.mkdirSync(path.dirname(report),{recursive:true});
fs.writeFileSync(report,JSON.stringify({summary:{...summary,failures:summary.failures.length},results},null,2));
console.log(JSON.stringify({...summary,failures:summary.failures.map(q=>({...q,trace:q.trace.filter((v,i)=>i<8||i===q.trace.length-1)}))}));
if(summary.failures.length)process.exitCode=1;
