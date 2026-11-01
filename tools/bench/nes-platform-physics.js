// Real native movement through the two NES small-platform rooms.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-platform-safe',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]=2;if(f===100)m.keyboard.matrix[2]=0;m.frame();}
const boot=m.memory.bytes.slice(),ref=JSON.parse(fs.readFileSync('build/nes-platforms/reference.json'));
function call(n){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[n];c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let k=0;c.pc!==s.unit_trap;k++){assert(k<700000,n+' hung');if(c.pc===s.L_8C13)c.pc=s.L_A067;c.instruction();}}
function load(index,level=1,flags=255){m.memory.bytes.set(boot);const row=Math.floor(Math.sqrt(index))-1,col=index-row*row-3*row+8;
 for(const[a,v]of[[0x71a6,level],[0x71a7,row],[0x71a8,col],[0x705f,0],[s.nes_q_idle,1]])m.wr(a,v);
 for(let a=0x70c0;a<0x7186;a++)m.wr(a,flags);call('L_A067');m.wr(0x705f,0);
 for(const[a,v]of[[0x7300,91],[0x7304,94],[0x7301,232],[0x7305,232],[0x7079,0],[0x7076,0],[0x7077,0],[0x7072,0],[0x7075,128],[0x7078,254],[0x707c,91]])m.wr(a,v);
 call("nphys_box_reset");
}
function step(key,n){m.wr(0x73ee,key);m.wr(0x70ab,n%4);if(n%4===0)call('proc_8F5F');call('L_9156');call('hero_state');call('L_8DE8');return [m.rd(0x7305),m.rd(0x7304),m.rd(0x7079)];}
// Contact points and cooldown are covered by the unmodified NES trace suite.
const wallCases=0,floorCases=0,cooldownCases=0;
const traces=[],routes=[];
for(const r of ref.cases){load(27);const trace=[];for(let n=0;n<40;n++)trace.push(step(r.name==='walk'||n===0?(r.name==='walk'?136:200):128,n));
 if(r.name==='jump'){
  // Before the landing, original NES ascent and jump-fall velocities match.
  for(let n=0;n<24;n++)assert.deepEqual(trace[n].slice(0,2),[r.trace[n][0],r.trace[n][1]+7],'NES airborne path at '+n);
  assert(trace.slice(24).some(q=>q[1]===102&&q[2]<=1),'land on first small platform');
 }
 assert(trace.every(q=>q[2]<8),'first platform is reachable without dying');traces.push({name:r.name,trace});
}
for(const index of [27,32])for(let level=1;level<=9;level++)for(const flags of [0,255]){
 load(index,level,flags);const trace=[];let jumps=0,n=0;
 while(jumps<12&&!(m.rd(0x7305)<=32&&m.rd(0x7304)<=95)){
  // Let an ordinary released key arm the next jump; never write the latch.
  for(let k=0;k<16&&(m.rd(0x7075)!==128||m.rd(0x7079)>1);k++)trace.push(step(128,n++));
  trace.push(step(200,n++));jumps++;
  for(let k=0;k<70&&m.rd(0x7079)>1&&m.rd(0x7079)<8;k++)trace.push(step(128,n++));
  assert(m.rd(0x7079)<8,'platform route killed Joe');
 }
 const end=[m.rd(0x7305),m.rd(0x7304),m.rd(0x7079)];
 assert(end[0]<=32&&end[1]<=95&&end[2]<=1,'room must have a right-to-left route: '+[index,level,flags,end]);
 routes.push({index,level,flags,jumps,end,trace});
}
const live=[];
for(const index of [27,32]){
 const v=E.mk(B+'/monty.bin'),check=require('./framecheck')(v,s);let steps=0,phase=0,jumps=0,done=null;const trace=[];
 v.onInstr=pc=>{check.instruction(pc);if(pc!==s.L_A5D1)return;
  if(++steps===80){const row=4,col=index-row*row-3*row+8;
   for(const[a,b]of[[0x71a6,1],[0x71a7,row],[0x71a8,col],[0x705f,0],[0x7300,91],[0x7304,94],[0x7301,232],[0x7305,232],[0x7079,0],[0x7076,0],[0x7077,0],[0x7072,0],[0x7075,128],[0x7078,254],[0x707c,91]])v.wr(a,b);
   for(let a=0x70c0;a<0x7186;a++)v.wr(a,255);const c=v.cpu;c.sp-=2;v.wr(c.sp,pc&255);v.wr(c.sp+1,pc>>8);c.pc=s.L_A067;phase=1;return;
  }
  if(!phase)return;const x=v.rd(0x7305),y=v.rd(0x7304),state=v.rd(0x7079);trace.push([v.frames,x,y,state]);
  assert(state<8,'actual keyboard route killed Joe');assert.equal(v.rd(0x71a5),index,'route stays inside reported room');
  if(done!==null)return;
  if(x<=32&&y<=95&&state<=1){done=v.frames;v.keyboard.matrix[0]=v.keyboard.matrix[7]=0;return;}
  if(phase===1&&state<=1&&v.rd(0x7075)===128){v.keyboard.matrix[0]=16;v.keyboard.matrix[7]=128;phase=2;jumps++;}
  if(phase===2&&state===2){v.keyboard.matrix[0]=v.keyboard.matrix[7]=0;phase=1;}
 };
 for(let f=0;f<1800&&(done===null||v.frames-done<8);f++){if(f===10)v.keyboard.matrix[2]=2;if(f===100)v.keyboard.matrix[2]=0;v.frame();}
 assert(done!==null,'real keyboard must cross the platform room');const pixels=check.result();assert.equal(pixels.bad,0,'platform render artifacts');
 live.push({index,jumps,done,end:[v.rd(0x7305),v.rd(0x7304),v.rd(0x7079)],pixels,trace});
}
const summary={B,wallCases,floorCases,cooldownCases,originalNesJumpStepsCompared:24,ordinaryFall:3,jumpMomentum:true,platformRoutes:routes.length,liveCases:live.length,failures:0};
if(process.env.OUT)fs.writeFileSync(process.env.OUT,JSON.stringify({summary,traces,routes,live},null,2)+'\n');
console.log(JSON.stringify({...summary,live:live.map(({trace,...q})=>q)}));
