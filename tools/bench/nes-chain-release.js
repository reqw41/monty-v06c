// Releasing Left exactly over a rope cap must not start a vertical free fall.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/rope-release-final',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]=2;if(f===100)m.keyboard.matrix[2]=0;m.frame();}
const boot=m.memory.bytes.slice(),results=[];
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;
 m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<2000000,name+' hung');if(c.pc===s.L_8C13)c.pc=s.L_A067;c.instruction();}
}
for(const flags of [0,255])for(const startRoom of [9,10])for(const target of [198,199])for(const delay of [1,3,8,32]){
 m.memory.bytes.set(boot);m.wr(0x71a7,1);m.wr(0x71a8,startRoom);m.wr(0x705f,0);m.wr(s.nes_q_idle,1);
 for(let a=0x70c0;a<0x7186;a++)m.wr(a,flags);call('L_A067');
 const x=(startRoom===9?232:18)+(target&1);
 for(const [a,v]of [[0x7300,92],[0x7304,95],[0x7301,x],[0x7305,x],[0x7079,0],[0x7076,0],[0x7077,0],[0x707c,92],[0x7072,18]])m.wr(a,v);
 for(let n=0;m.rd(0x71a8)!==9||m.rd(0x7305)!==target;n++){assert(n<80,'approach missed target');m.wr(s.kbmat,16);call('L_88D1');}
 const trace=[];
 for(let n=0;n<delay;n++){m.wr(s.kbmat,0);call('L_88D1');trace.push([m.rd(0x7305),m.rd(0x7304),m.rd(0x7079)]);}
 const held=trace.every(q=>q[0]===196&&q[1]===95&&q[2]===4);
 for(let n=0;n<24;n++){m.wr(s.kbmat,128);call('L_88D1');trace.push([m.rd(0x7305),m.rd(0x7304),m.rd(0x7079)]);}
 results.push({flags,startRoom,target,delay,held,descended:m.rd(0x7305)===196&&m.rd(0x7304)===119&&m.rd(0x7079)===4,trace});
}
const failures=results.filter(q=>!q.held||!q.descended);
const report={B,cases:results.length,failures:failures.length,examples:failures.slice(0,2)};
if(process.env.OUT)fs.writeFileSync(process.env.OUT,JSON.stringify({summary:report,results},null,2)+'\n');
console.log(JSON.stringify(report));assert.equal(failures.length,0,'idle on rope cap fell before Down');

// Idle on adjacent brick must not pull Joe sideways; Fire keeps jump priority.
m.memory.bytes.set(boot);m.wr(0x71a7,1);m.wr(0x71a8,9);m.wr(0x705f,0);m.wr(s.nes_q_idle,1);call('L_A067');
const scene=m.memory.bytes.slice();let controls=0;
for(const kind of ['ledge','jump','air'])for(const x of kind==='ledge'?Array.from({length:32},(_,i)=>200+i):kind==='jump'?[198,199]:[190,191]){
 m.memory.bytes.set(scene);
 for(const [a,v]of [[0x7300,92],[0x7304,95],[0x7301,x],[0x7305,x],[0x7079,0],[0x7076,0],[0x7077,0],[0x707c,92],[0x7075,128]])m.wr(a,v);
 m.wr(s.kbmat,0);m.wr(s.kbmat+7,kind==='jump'?128:0);
 for(let n=0;n<(kind==='jump'?1:8);n++)call('L_88D1');
 if(kind==='ledge')assert.deepEqual([m.rd(0x7305),m.rd(0x7304),m.rd(0x7079)],[x,95,0],'idle brick ledge must not snap to the rope');
 if(kind==='jump'){assert.equal(m.rd(0x7079),2,'Fire must still jump from the cap');assert.equal(m.rd(0x7305),x,'jump must not snap sideways');}
 if(kind==='air'){assert.equal(m.rd(0x7079),6,'empty air must remain a fall');assert(m.rd(0x7304)>95);}
 controls++;
}

// Release the real key on reaching the requested completed-step coordinate.
// A keyboard IRQ need not occur at every X: several game steps can share one
// frame. Requiring kb_scan at precisely X=199 can miss the release entirely.
// The next ordinary scan samples the release; only initial placement is injected.
const live=[];
for(const startRoom of [9,10])for(const target of [198,199])for(const wait of [8,24]){
 const v=E.mk(B+'/monty.bin');let steps=0,phase=0,released=null,downAt=null,releaseX=null,firstScan=null;
 const trace=[];
 v.onInstr=pc=>{
  if(pc===s.L_A5D1&&++steps===80){
   const x=(startRoom===9?232:18)+(target&1);
   for(const [a,b]of [[0x71a7,1],[0x71a8,startRoom],[0x705f,0],[0x7300,92],[0x7304,95],[0x7301,x],[0x7305,x],[0x7079,0],[0x7076,0],[0x7077,0],[0x707c,92],[0x7072,18]])v.wr(a,b);
   const c=v.cpu;c.sp-=2;v.wr(c.sp,pc&255);v.wr(c.sp+1,pc>>8);c.pc=s.L_A067;v.keyboard.matrix[0]=16;phase=1;return;
  }
  if(pc===s.L_A5D1&&phase===1&&v.rd(0x71a8)===9&&v.rd(0x7305)===target){
   v.keyboard.matrix[0]=0;released=v.frames;releaseX=v.rd(0x7305);phase=2;
  }
  if(pc===s.kb_scan&&phase===2&&firstScan===null)firstScan=v.frames;
  if(pc===s.L_A5D1&&phase>=2){
   trace.push([v.frames,v.rd(0x7305),v.rd(0x7304),v.rd(0x7079)]);
   // A previously sampled Left can leave state6 at the same Y for one step;
   // that pending horizontal approach must catch before any vertical fall.
   if(downAt===null)assert.equal(v.rd(0x7304),95,'live release fell through the cap: '+JSON.stringify(trace));
   else if(v.rd(0x7304)>=111){assert.equal(v.rd(0x7305),196);assert.equal(v.rd(0x7079),4);phase=3;}
  }
 };
 for(let f=0;f<750&&phase!==3;f++){
  if(f===10)v.keyboard.matrix[2]=2;if(f===100)v.keyboard.matrix[2]=0;
  if(phase===2&&downAt===null&&v.frames-released>=wait){v.keyboard.matrix[0]=128;downAt=v.frames;}
  v.frame();
 }
 assert.equal(phase,3,'live release/hold/descent did not finish: '+[startRoom,target,wait]);
 assert.equal(releaseX,target,'release must exercise the requested X parity');
 assert(firstScan!==null&&firstScan<=downAt,'ordinary IRQ must sample release before Down');
 live.push({startRoom,target,wait,releaseFrame:released,firstScan,downFrame:downAt,trace});
}
const final={...report,controls,liveCases:live.length,keyboardRelease:true};
if(process.env.OUT)fs.writeFileSync(process.env.OUT,JSON.stringify({summary:final,results,live},null,2)+'\n');
console.log(JSON.stringify(final));
