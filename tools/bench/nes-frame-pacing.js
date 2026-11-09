// Bounded render workload: native main loop, enemies, IRQ, music and live tiles.
// Default: replace Joe's collision/state handler with a repeatable path.
// LIVE=1 ROOM=1,9: actual keyboard and physics on the existing right platform.
// Both modes retain native enemies, tile work, sound and IRQ timing.
// PROFILE=1 adds exclusive nearest-label costs for the worst measured IRQ.
// Emit the measured row before assertions so an overrun remains diagnosable.
'use strict';
const fs=require('fs'),path=require('path'),assert=require('assert/strict');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols,profiler}=require('./logic-profile');
const live=process.env.LIVE==='1';
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),N=+(process.env.N||800),results=[];
function summary(v){if(!v.length)return null;v=[...v].sort((a,b)=>a-b);const mean=v.reduce((a,b)=>a+b,0)/v.length;return {count:v.length,mean:+mean.toFixed(2),stddev:+Math.sqrt(v.reduce((a,b)=>a+(b-mean)**2,0)/v.length).toFixed(2),p95:v[Math.min(v.length-1,Math.floor(v.length*.95))],max:v.at(-1),histogram:v.reduce((q,n)=>(q[n]=(q[n]||0)+1,q),{})};}
const profile=process.env.PROFILE==='1';
const labels=profile?Object.entries(s).filter(([n,a])=>a>=0&&a<65536&&!/^(C_|L_)/.test(n)).sort((a,b)=>a[1]-b[1]):[];
const near=[];if(profile){let j=0;for(let a=0;a<65536;a++){while(j+1<labels.length&&labels[j+1][1]<=a)j++;near[a]=labels[j]?.[0]||'?';}}
const scenes=process.env.ROOM?[[...process.env.ROOM.split(',').map(Number)]]:[[1,9],[7,2],[7,12]];
for(const room of scenes)for(const moving of (process.env.MOVING?[process.env.MOVING==='1']:[false,true])){
 const m=E.mk(B+'/monty.bin'),p=profiler(m,s);
 if(process.env.BUDGET){assert.equal(m.rd(s.ck_limit),0xfe);m.wr(s.ck_limit+1,+process.env.BUDGET);}let steps=0,start=null,active=false,until=0,clock=0,irq=null,maxIRQ=0;
 let previousPC=0,irqProfile={},worstProfile={};
 const groundY=s.NES_PHYSICS_COORDS?91:92;
 const checker=process.env.PIXELS==='1'?require('./framecheck')(m,s):null;
 const seen={},events={},gaps={},hist={},poseTrace=[],motion={};let lastStep=null;
 function motionFrame(k){const r=s.spr_rec+16*k,p=0x7300+4*m.rd(0x72e0+k);if(!m.rd(r))return;const x=m.rd(p+1),y=m.rd(p),sx=m.rd(r+2),sy=m.rd(r+1),key=sx+','+sy,q=motion[k]??={held:0,maxHeldFrames:0,maxPositionLag:0,gameTravelX:0,visibleTravelX:0};q.held=(x!==sx||y!==sy)&&key===q.key?q.held+1:0;q.maxHeldFrames=Math.max(q.maxHeldFrames,q.held);q.maxPositionLag=Math.max(q.maxPositionLag,Math.abs(x-sx),Math.abs(y-sy));if(q.gameX!==undefined){q.gameTravelX+=Math.abs(x-q.gameX);q.visibleTravelX+=Math.abs(sx-q.shownX);}q.gameX=x;q.shownX=sx;q.key=key;}
 function event(name){(events[name]??=[]).push(m.frames);if(seen[name]!==undefined)(gaps[name]??=[]).push(m.frames-seen[name]);seen[name]=m.frames;}
 function ret(){const c=m.cpu;c.pc=m.rd(c.sp)|(m.rd(c.sp+1)<<8);c.sp+=2;}
 m.onInstr=pc=>{
  const elapsed=m.cpu.vcycles||0;clock+=elapsed;if(profile&&irq){const n=near[previousPC];irqProfile[n]=(irqProfile[n]||0)+elapsed;}previousPC=pc;p.instruction(pc);if(checker)checker.instruction(pc);
  if(irq&&pc===irq.pc&&m.cpu.sp===irq.sp+2){if(active&&clock-irq.clock>maxIRQ){maxIRQ=clock-irq.clock;worstProfile=irqProfile;}irq=null;}
  if(pc===0x38&&!irq){irqProfile={};irq={sp:m.cpu.sp,pc:m.rd(m.cpu.sp)|(m.rd(m.cpu.sp+1)<<8),clock};}
  if(steps>=80&&((!live&&pc===s.hero_state)||pc===s.L_8DA2)){ret();return;}
  if(pc===s.L_A5D1){
   steps++;
   if(steps===80){m.wr(0x71a7,room[0]);m.wr(0x71a8,room[1]);m.wr(0x705f,0);for(let a=0x70c0;a<0x7186;a++)m.wr(a,0);const c=m.cpu;c.sp-=2;m.wr(c.sp,pc&255);m.wr(c.sp+1,pc>>8);c.pc=s.L_A067;return;}
   if(steps>80){
    assert.deepEqual([m.rd(0x71a7),m.rd(0x71a8)],room,'room must stay resident');
    const phase=(steps-81+(+process.env.XOFF||0))%128;/* XOFF — фаза хода Джо (худший случай 7,2: XOFF=16/72/80) */let x;
    if(live){
     assert.deepEqual(room,[1,9],'live platform fixture is specific to room 1,9');
     if(steps===81)for(const [a,v]of [[0x7300,groundY],[0x7304,groundY+3],[0x7301,220],[0x7305,220],[0x7303,6],[0x7307,11],[0x7079,0],[0x7076,0],[0x7077,0],[0x705f,0]])m.wr(a,v);
     x=m.rd(0x7301);
     if(moving){if(x>=228)m.keyboard.matrix[0]=16;else if(x<=212||!m.keyboard.matrix[0])m.keyboard.matrix[0]=64;}
     m.wr(0x7049,6);
     if(active){assert([0,1].includes(m.rd(0x7079)),'live Joe must keep walking on the platform');assert.equal(m.rd(0x7300),groundY);}
    }else{
     x=moving?72+(phase<64?phase:127-phase):104;
     for(const [a,v]of [[0x7300,76],[0x7304,79],[0x7301,x],[0x7305,x],[0x7303,6],[0x7307,11],[0x7079,moving?1:0],[0x7076,0],[0x7077,0],[0x705f,0],[0x7049,6]])m.wr(a,v);
    }
    if(steps>=150&&!active){active=true;start={...p.totals};until=m.frames+N;}
    if(active){if(lastStep!==null){const d=m.frames-lastStep;hist[d]=(hist[d]||0)+1;}lastStep=m.frames;poseTrace.push([m.rd(0x7300),x,m.rd(0x7079)]);}
   }
  }
  if(!active)return;
  if(pc===s.joe_put)event('joe');
  if(pc===s.spr_put&&m.rd(s.sp_k)>=2)event('enemy'+m.rd(s.sp_k));
  if(pc===s.disp_prep)event('preparation');
  if(pc===s.live_build)event('liveListRebuild');
 };
 let old={};
 for(let f=0;!active||m.frames<until;f++){
  assert(f<6000,'fixture timeout');if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;
  m.frame();
  if(active){for(const k of [0,2,3,4,5])motionFrame(k);for(const n of ['fire','belt']){const v=m.rd(s[n+'_shown']);if(old[n]!==undefined&&old[n]!==v)event(n);old[n]=v;}}
 }
 const context={};for(const k of Object.keys(start))context[k]=Math.round((p.totals[k]-start[k])/N);
 const shifts=Array.from({length:s.PS_N*(s.PS_SHIFTS||8)},(_,i)=>m.rd(s.ps_tab+2*i)|m.rd(s.ps_tab+2*i+1)<<8).filter(Boolean).length;
 const row={room:room.join(','),moving,frames:N,sps:50*poseTrace.length/N,steps:poseTrace.length,histogram:hist,context,maxIRQ,cachedShifts:shifts,motion,pixels:checker?checker.result():undefined,events:Object.fromEntries(Object.entries(events).map(([k,v])=>[k,v.length])),gaps:Object.fromEntries(Object.entries(gaps).map(([k,v])=>[k,summary(v)]))};
 if(profile){
  assert.equal(Object.values(worstProfile).reduce((a,b)=>a+b,0),maxIRQ,'IRQ profile conserves elapsed cycles');
  row.irqProfile=Object.fromEntries(Object.entries(worstProfile).sort((a,b)=>b[1]-a[1]));
 }
 console.log(JSON.stringify(row));
 assert(maxIRQ<59904,'atomic display work must fit in one physical frame');
 if(['1,9','7,2'].includes(row.room))assert(Object.keys(row.events).filter(k=>k.startsWith('enemy')).length>=2,'two live monsters must be covered');
 if(moving)assert(row.events.joe>40,'Joe must really redraw');assert(shifts>=+(process.env.CACHE_MIN||s.PS_BLOCKS||32),'keep full enemy cache');
 if(live&&moving&&s.NES_SNAKE_LOCAL)assert(!row.events.liveListRebuild,'snake turns must not rebuild the resident room list');
 if(moving&&process.env.JOE_GAP_MAX)assert(row.gaps.joe.max<=+process.env.JOE_GAP_MAX,'Joe paint deadline exceeded');
 if(checker)assert.equal(row.pixels.bad,0,'every completed atomic group must preserve pixels');
 results.push(row);
}
if(process.env.OUT)fs.writeFileSync(process.env.OUT,JSON.stringify({B,fixture:live?'live keyboard walk on the right platform of room 1,9':'bounded Joe trajectory; native main loop, enemy logic, live tile work and IRQ',results},null,2)+'\n');
