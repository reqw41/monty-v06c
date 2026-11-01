// Passive, exclusive cycle accounting. Charge immediately after execution,
// before interrupt acknowledgement can replace cpu.vcycles. Nothing is patched.
'use strict';
const assert=require('node:assert/strict');
module.exports=function preparationProfile(m,s){
 const names={
  disp_prep:'prepare',spr_plan:'prepare',spr_prep:'prepare',crit_plan:'prepare',
  joe_prepare:'prepare',enemy_prepare:'prepare',spr_masks:'prepare',ps_find:'prepare',
  fl_compile:'prepare',tile_build:'prepare',live_build:'prepare',
  draw_list:'background',force_live_t:'background',draw_all:'background',
  nf_draw_hud:'background',room_color_changes:'background',
  nes_snake_render:'prepare',ex_build:'prepare',band_check:'prepare',
  joe_step_gate:'scheduler',joe_gate:'gate',frame_wait:'frame',
  frame_handler:'logic',nes_poll:'audio',nes_service:'audio',nes_legacy_step:'audio',nes_prepare_core:'audio',
  crit:'irq',joe_put:'irq',joe_restore:'irq',enemy_put:'irq',enemy_restore:'irq',
 };
 const entries=new Map();for(const [name,role]of Object.entries(names))if(s[name]!==undefined){
  assert(!entries.has(s[name]),'aliased profiling entries: '+name);entries.set(s[name],{name,role});
 }
 const buckets=['logic','prepare','background','audio','scheduler','queueHero','queueTail','frameWait','gateProbe','frameProbe','irq'];
 let clock=0,active=false,measured=0,startClock=0,startCarry=0,startFrame=0,irq=null;
 const main=[],interrupt=[],totals=Object.fromEntries(buckets.map(n=>[n,0])),frames=[],stats=new Map();
 let current=null,gate=[],event=[],episode=null,ready=null;
 const waits=[],latencies=[],cache=new Map(),masks=new Map();let acks=0;
 const word=a=>m.rd(a)|(m.rd(a+1)<<8);
 const backedges=[];for(let a=s.joe_gate;a<s.joe_latch_end-2;a++)if(m.rd(a)===0xc2&&word(a+1)===s.joe_gate)backedges.push(a);
 assert.equal(backedges.length,2,'identify both queue-spin branches');
 let eventBranch=null;for(let a=s.fw_event;a<s.fw_return-2;a++)if(m.rd(a)===0xca&&word(a+1)===s.fw2)eventBranch=a;
 assert(eventBranch!==null,'identify physical-frame wait branch');
 const deferred=s.ck_defer+3;assert.equal(m.rd(deferred),0x3e); // LD A,1 follows LD(cr_read),HL.
 function finishEpisode(){if(episode){waits.push(episode);episode=null;}}
 function add(bucket,n){if(!active)return;totals[bucket]+=n;current[bucket]+=n;measured+=n;}
 function buffered(chunks,n){if(!active)return;const last=chunks.at(-1);if(last?.frame===current)last.cycles+=n;else chunks.push({frame:current,cycles:n});}
 function flush(chunks,source,target){let n=0;for(const q of chunks){totals[source]-=q.cycles;totals[target]+=q.cycles;q.frame[source]-=q.cycles;q.frame[target]+=q.cycles;n+=q.cycles;}chunks.length=0;return n;}
 function gateEnd(target){const n=flush(gate,'gateProbe',target);
  if(!n)return;if(target==='scheduler'){finishEpisode();return;}
  if(!episode||episode.kind!==target){finishEpisode();episode={kind:target,cycles:0,iterations:0,startFrame:m.frames,endFrame:m.frames};}
  episode.cycles+=n;episode.iterations++;episode.endFrame=m.frames;
 }
 function finish(frame){
  if(frame.name==='joe_gate')gateEnd('scheduler');
  if(frame.name==='frame_wait')flush(event,'frameProbe','scheduler');
  if(!active||!frame.measured)return;
  if(frame.name==='ps_find'){
   const hit=!!(m.cpu.store_flags()&0x40),key=JSON.stringify({...frame.mask,hit});
   cache.set(key,(cache.get(key)||0)+1);
  }
  if(frame.name==='spr_masks'){
   const key=JSON.stringify(frame.mask),q=masks.get(key)||{...frame.mask,calls:0,cycles:0,max:0};
   const cost=clock-frame.clock-frame.irqCost;q.calls++;q.cycles+=cost;q.max=Math.max(q.max,cost);masks.set(key,q);
  }
  const key=frame.name+(frame.name==='joe_prepare'?(frame.rows?'_rebuilt':'_cached'):['nes_poll','nes_service','nes_legacy_step'].includes(frame.name)?(frame.work?'_work':'_idle'):'');
  const q=stats.get(key)||{name:key,role:frame.role,calls:0,cycles:0,max:0,self:0,rows:0,callers:{}};
  const cost=clock-frame.clock;q.calls++;q.cycles+=cost-frame.irqCost;q.max=Math.max(q.max,cost-frame.irqCost);q.self+=frame.self;q.rows+=frame.rows;
  const caller=frame.ra.toString(16);q.callers[caller]=(q.callers[caller]||0)+1;stats.set(key,q);
 }
 function before(pc){
  const stack=irq?interrupt:main;
  while(stack.length&&pc===stack.at(-1).ra&&m.cpu.sp===stack.at(-1).sp+2)finish(stack.pop());
  if(irq&&pc===irq.ra&&m.cpu.sp===irq.sp+2){assert.equal(interrupt.length,0,'IRQ scopes must close');
   const elapsed=clock-irq.clock;for(const q of main)q.irqCost+=elapsed;irq=null;
  }
  const own=irq?interrupt:main;
  // An IRQ can land immediately after RET, before that caller PC is observed.
  while(own.length&&pc===own.at(-1).ra&&m.cpu.sp===own.at(-1).sp+2)finish(own.pop());
  if(active&&!irq&&pc===s.L_A5D1)assert.equal(main.length,0,'all main scopes must close before the next game step: '+main.map(q=>q.name));
  const entry=entries.get(pc);
  if(entry&&!own.some(q=>q.name===entry.name&&q.sp===m.cpu.sp)){
   if(entry.name==='disp_prep'){gateEnd('scheduler');finishEpisode();}
   const item={...entry,sp:m.cpu.sp,ra:word(m.cpu.sp),clock,irqCost:0,self:0,rows:0,work:false,measured:active};
   if(entry.name==='ps_find'||entry.name==='spr_masks'){
    const name=m.rd(s.sp_name),shift=m.rd(s.sp_x)&7,rows=m.rd(s.st_rows),index=m.rd(s.ps_idx+(name>>2));
    const reason=index===255?'pose_not_cached':rows!==m.rd(s.ps_rr+index)?'clipped_rows':word(s.ps_tab+2*((s.PS_SHIFTS||8)*index+(s.PS_SHIFTS===4?shift>>1:shift)))===0?'no_memory':'available';
    item.mask={actor:m.rd(s.sp_k),name,shift,rows,reason};
   }
   own.push(item);
  }
  if(pc===s.jn_prep_row){const q=own.findLast(q=>q.name==='joe_prepare');if(q)q.rows++;}
  if(pc===s.nes_prepare_core)for(const q of own)if(q.name==='nes_poll'||q.name==='nes_service')q.work=true;
  if(pc===s.nes_legacy_step+8){const q=own.findLast(q=>q.name==='nes_legacy_step');if(q)q.work=true;}
  if(pc===s.crit&&active&&ready){latencies.push({...ready,cycles:clock-ready.clock,dispatchFrame:m.frames});ready=null;}
  let bucket;
  if(irq)bucket='irq';else{
   const scope=main.at(-1);bucket=scope?.role||'logic';
   if(bucket==='irq')bucket='prepare'; // A renderer called outside ISR is main work.
   if(bucket==='gate')bucket='gateProbe';
   if(bucket==='frame')bucket=pc>=s.fw2&&pc<=eventBranch?'frameProbe':'scheduler';
  }
  return {pc,bucket,scope:own.at(-1),irq:!!irq};
 }
 function after(q,n){
  clock+=n;add(q.bucket,n);if(q.scope&&active&&q.scope.measured)q.scope.self+=n;
  if(q.bucket==='gateProbe')buffered(gate,n);
  if(q.bucket==='frameProbe')buffered(event,n);
  if(!q.irq&&backedges.includes(q.pc)){
   if(m.cpu.pc===s.joe_gate)gateEnd(q.pc===backedges[0]?'queueHero':'queueTail');
  }
  if(!q.irq&&q.pc===eventBranch)flush(event,'frameProbe',m.cpu.pc===s.fw2?'frameWait':'scheduler');
  // Unconditional return to the gate after publishing is preparation overhead.
  if(!q.irq&&q.bucket==='gateProbe'&&m.rd(q.pc)===0xc3&&m.cpu.pc===s.joe_gate)gateEnd('scheduler');
  if(active&&m.rd(q.pc)===0x32&&word(q.pc+1)===s.crit_pend&&m.rd(s.crit_pend)===1){
   ready={clock,frame:m.frames,kind:q.irq?'deferredTail':'preparedPlan'};
  }
 }
 const instruction=m.cpu.instruction.bind(m.cpu);m.cpu.instruction=()=>{const q=before(m.cpu.pc);instruction();after(q,m.cpu.vcycles);};
 const checkInterrupt=m.v06c.checkInterrupt.bind(m.v06c);m.v06c.checkInterrupt=()=>{
  const ack=m.v06c.irq&&m.cpu.iff;checkInterrupt();if(ack){
   assert(!irq,'nested physical interrupt');assert.equal(m.cpu.pc,0x38);
   irq={sp:m.cpu.sp,ra:word(m.cpu.sp),clock};clock+=16;add('irq',16);if(active)acks++;
  }
 };
 return {
  frameStart(){if(active){current=Object.fromEntries(buckets.map(n=>[n,0]));frames.push(current);}},
  activate(){active=true;startClock=clock;startCarry=m.v06c.instr_time;startFrame=m.frames;gate.length=0;event.length=0;},
  result(){
   // A short unfinished poll at the last physical boundary is reported separately.
   finishEpisode();const count=frames.length,engine=count*59904+m.v06c.instr_time-startCarry;
   assert.equal(measured,clock-startClock,'every measured instruction was charged');
   assert.equal(measured,engine,'instruction plus IRQ-ack cycles equal physical beam time');
   assert.equal(Object.values(totals).reduce((a,b)=>a+b,0),measured,'exclusive buckets conserve cycles');
   for(const f of frames)assert(Object.values(f).every(n=>n>=0),'negative frame attribution');
   return {frames:count,startFrame,endFrame:m.frames,cycles:measured,engineCycles:engine,irqAcknowledgements:acks,
    totals,perFrame:Object.fromEntries(Object.entries(totals).map(([k,v])=>[k,+(v/count).toFixed(2)])),
    routines:[...stats.values()].map(q=>({...q,perFrame:+(q.cycles/count).toFixed(2),avg:Math.round(q.cycles/q.calls),selfPerFrame:+(q.self/count).toFixed(2)})),
    queueWaits:waits,dispatchLatency:latencies,frameBuckets:frames,
    enemyCache:[...cache].map(([key,calls])=>({...JSON.parse(key),calls})),enemyMaskWork:[...masks.values()],
    unfinishedScopes:main.map(q=>q.name),unfinishedGateCycles:totals.gateProbe,unfinishedFrameProbeCycles:totals.frameProbe};
  },
 };
};
