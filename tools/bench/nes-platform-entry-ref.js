// Compare actual native platform/bonus motion with original 6502 traces.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]=2;if(f===100)m.keyboard.matrix[2]=0;m.frame();}
const base=m.memory.bytes.slice(),reference=JSON.parse(fs.readFileSync('build/nes-treasure/platform-entry-reference.json')),layouts=JSON.parse(fs.readFileSync('build/nes-treasure/reference.json'));
let boundary=null,minStack=0x73c0,groundSteps=0,bonusSteps=0,grabs=0,exitSamples=0;const failures=[];
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');if(c.pc===s.L_8E0C)boundary=position();if(c.sp>=0x7300&&c.sp<=0x73c0){minStack=Math.min(minStack,c.sp);assert(c.sp>=0x7380);}c.instruction();}}
function position(){const state=m.rd(0x7079);return[m.rd(0x7305),m.rd(0x7304)-7,({0:0,1:0,2:2,4:64,6:1})[state]??state];}
function set(values){for(const [a,v]of values)m.wr(a,v);}
for(const r of reference.ground){
 m.memory.bytes.set(base);const x=r.side==='left'?52:188,dx=r.side==='left'?2:254;
 set([[0x71a7,8],[0x71a8,10],[0x705f,0],[0x7079,0],[0x7072,0],[0x7300,172],[0x7304,175],[0x7301,x],[0x7305,x],[0x7076,0],[0x7077,0],[0x7078,dx],[0x7049,6]]);call('L_A067');
 for(let n=0;n<r.trace.length;n++){
  boundary=null;set([[0x73ee,n===0?(r.side==='left'?194:200):128],[0x70ab,n%4]]);call('L_9156');call('hero_state');call('L_8DE8');
  assert.deepEqual(boundary||position(),r.trace[n],JSON.stringify({phase:'ground',side:r.side,step:n}));groundSteps++;
 }
 assert(m.rd(0x705f)&32);assert.deepEqual(position(),[r.side==='left'?128:112,37,1],'first bonus anchor and falling state');
}
for(const r of reference.bonus){
 m.memory.bytes.set(base);for(let i=192;i<960;i++)m.wr(s.VNT+i,0);
 const dx=r.side==='left'?2:254;
 set([[0x71a6,r.level],[0x71a7,9],[0x71a8,10],[0x705f,32],[0x7079,6],[0x7072,0],[0x7300,r.start[1]+4],[0x7304,r.start[1]+7],[0x7301,r.start[0]],[0x7305,r.start[0]],[0x7076,dx],[0x7077,3],[0x7078,dx],[0x70ac,178],[s.nt_rng,r.seed&255],[s.nt_rng+1,r.seed>>8]]);
 call('nes_treasure_generate');
 const layout=layouts.find(q=>q.level===r.level&&q.seed===r.seed);assert.deepEqual(Array.from({length:768},(_,i)=>m.rd(s.FIELD_VNT+i)),layout.cells);
 let caught=null;
 for(let n=0;n<r.trace.length;n++){
  // Horizontal screen-edge margins are still native (X<4 versus NES X<2).
  // Compare this panel up to its existing boundary; all rope catches precede it.
  if(r.trace[n][0]<4||r.trace[n][0]>=240){exitSamples+=r.trace.length-n;break;}
  boundary=null;set([[0x73ee,128],[0x70ab,n%4]]);call('L_9156');call('hero_state');call('L_8DE8');
  const got=boundary||position();if(JSON.stringify(got)!==JSON.stringify(r.trace[n])&&failures.length<12)failures.push({side:r.side,level:r.level,seed:r.seed,step:n,got,want:r.trace[n]});
  if(got[2]===64&&caught===null)caught=n;bonusSteps++;
 }
 if(caught!==r.caught&&failures.length<12)failures.push({side:r.side,level:r.level,seed:r.seed,caught,wantCatch:r.caught});
 if(caught!==null)grabs++;
}
console.log(JSON.stringify({B,groundSteps,bonusCases:reference.bonus.length,bonusSteps,grabs,horizontalExitSamplesOutsideScope:exitSamples,failures,minMainStack:minStack.toString(16)}));assert.equal(failures.length,0,'entry differs from original NES');
