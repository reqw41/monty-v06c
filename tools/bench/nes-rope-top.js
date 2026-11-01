// Free rope caps must permit climbing the final cell and jumping out of shafts.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-cap-candidate',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]=2;if(f===100)m.keyboard.matrix[2]=0;m.frame();}
const boot=m.memory.bytes.slice(),rooms=JSON.parse(fs.readFileSync('build/nes_full/rooms.json')).records;
const reference=JSON.parse(fs.readFileSync('build/nes-rope-top/reference.json'));
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.sp=0x73be;c.pc=s[name];m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<500000,name+' hung');if(c.pc===s.L_8C13)c.pc=s.L_A067;c.instruction();}}
function set(values){for(const [a,v]of values)m.wr(a,v);}
function load(index,level=1,flags=255){m.memory.bytes.set(boot);const r=index?Math.floor(Math.sqrt(index))-1:0,col=index-r*r-3*r+8;
 set([[0x71a6,level],[0x71a7,r],[0x71a8,col],[0x705f,0],[s.nes_q_idle,1]]);for(let a=0x70c0;a<0x7186;a++)m.wr(a,flags);call('L_A067');m.wr(0x705f,0);}
function place(x,y,state=4){set([[0x7300,y-3],[0x7304,y],[0x7301,x],[0x7305,x],[0x7079,state],[0x7076,0],[0x7077,0],[0x7072,0],[0x7075,128],[0x707c,y-3]]);}
function step(key,n){set([[0x73ee,key],[0x70ab,n%4]]);
 // Real ordinary rooms can put a collectible directly over the rope cap.
 // Run its normal four-step pickup process before probing movement, as main_loop.
 if(n%4===0)call('proc_8F5F');
 call('L_9156');call('hero_state');call('L_8DE8');return [m.rd(0x7305),m.rd(0x7304),m.rd(0x7079)];}
const caps=[],failures=[],results=[],jumps=[];
for(const room of rooms)for(let y=7;y<29;y++)for(let x=1;x<31;x++){
 const at=(xx,yy)=>room.native[(yy-6)*32+xx];
 if(at(x,y)===0x90&&at(x,y-1)===0&&![8,11].includes(at(x-1,y))&&![8,11].includes(at(x+1,y)))caps.push({index:room.index,x,y});
}
for(const cap of caps)for(let level=1;level<=9;level++)for(const flags of [0,255]){
 load(cap.index,level,flags);const x=cap.x*8-4,top=cap.y*8-17;place(x,top+12);
 const trace=[];for(let n=0;n<80;n++)trace.push(step(129,n));
 const end=trace.at(-1),ok=end[0]===x&&end[1]===top&&end[2]===4&&trace.slice(-8).every(q=>q[1]===top);
 if(!ok)failures.push({test:'climb',cap,level,flags,end,want:[x,top,4]});
 if(ok){for(let n=0;n<8;n++)trace.push(step(128,n));for(let n=0;n<8;n++)trace.push(step(132,n));
  if(m.rd(0x7304)!==top+8||m.rd(0x7079)!==4)failures.push({test:'descend',cap,level,flags,end:trace.at(-1)});}
 results.push({cap,level,flags,end,ok,trace:ok?undefined:trace});
}
for(const level of [1,5,9])for(const flags of [0,255])for(const side of ['left','right'])for(const held of [false,true]){
 load(12,level,flags);place(108,100);for(let n=0;n<80;n++)step(129,n);
 const start=[m.rd(0x7305),m.rd(0x7304)],trace=[];
 for(let n=0;n<45;n++)trace.push(step(n===0||held?(side==='left'?200:194):128,n));
 const end=trace.at(-1),min=Math.min(...trace.map(q=>q[1]));
 const ok=start[1]===reference.up.at(-1)[1]+8&&min===start[1]-19&&end[1]===55&&[0,1].includes(end[2])&&(side==='left'?end[0]<=96:end[0]>=128);
 if(!ok)failures.push({test:'jump-out',level,flags,side,held,start,end,min});
 jumps.push({level,flags,side,held,start,end,min,trace,ok});
}
const summary={B,freeCapGeometries:caps.length,capCases:results.length,jumpCases:jumps.length,room:[2,10],failures:failures.length,examples:failures.slice(0,8)};
if(process.env.OUT)fs.writeFileSync(process.env.OUT,JSON.stringify({summary,results,jumps},null,2)+'\n');
console.log(JSON.stringify(summary));assert.equal(failures.length,0,'free rope cap/shaft exit regression');

const live=[];
for(const side of ['left','right']){
 const v=E.mk(B+'/monty.bin'),check=require('./framecheck')(v,s);let steps=0,phase=0,capFrame=null,jumpFrame=null,doneFrame=null;
 const trace=[];
 v.onInstr=pc=>{check.instruction(pc);if(pc!==s.L_A5D1)return;
  if(++steps===80){
   for(const[a,b]of[[0x71a6,1],[0x71a7,2],[0x71a8,10],[0x705f,0],[0x7300,97],[0x7304,100],[0x7301,108],[0x7305,108],[0x7079,4],[0x7076,0],[0x7077,0],[0x7072,0],[0x7075,128],[0x707c,97]])v.wr(a,b);
   for(let a=0x70c0;a<0x7186;a++)v.wr(a,255);
   const c=v.cpu;c.sp-=2;v.wr(c.sp,pc&255);v.wr(c.sp+1,pc>>8);c.pc=s.L_A067;v.keyboard.matrix[0]=32;phase=1;return;
  }
  if(!phase)return;
  const x=v.rd(0x7305),y=v.rd(0x7304),state=v.rd(0x7079);trace.push([v.frames,x,y,state]);
  assert(state<8,'live shaft exit must preserve Joe');
  if(phase===1&&y===71&&capFrame===null)capFrame=v.frames;
  if(phase===1&&capFrame!==null&&v.frames-capFrame>=8){v.keyboard.matrix[0]=side==='left'?16:64;v.keyboard.matrix[7]=128;phase=2;}
  if(phase===2&&state===2){v.keyboard.matrix[0]=v.keyboard.matrix[7]=0;jumpFrame=v.frames;phase=3;}
  if(phase===3&&y===55&&state<=1&&(side==='left'?x<=96:x>=128)){phase=4;doneFrame=v.frames;}
 };
 for(let f=0;f<1100&&(doneFrame===null||v.frames-doneFrame<8);f++){
  if(f===10)v.keyboard.matrix[2]=2;if(f===100)v.keyboard.matrix[2]=0;v.frame();
 }
 assert.equal(phase,4,'actual keyboard must climb, hold and jump out: '+side);
 const pixels=check.result();assert.equal(pixels.bad,0,'shaft jump must preserve graphics');
 live.push({side,capFrame,jumpFrame,doneFrame,end:[v.rd(0x7305),v.rd(0x7304),v.rd(0x7079)],pixels,trace});
}
if(process.env.OUT)fs.writeFileSync(process.env.OUT,JSON.stringify({summary:{...summary,liveCases:live.length},results,jumps,live},null,2)+'\n');
console.log(JSON.stringify({B,liveCases:live.length,exits:live.map(({trace,...q})=>q)}));
