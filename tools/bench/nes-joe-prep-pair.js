// Paired-row experiment, isolated from live VRAM and the production ROM.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-physics-checked',P=process.env.PAIR||'build/joe-prep-pair';
const s=symbols(B),p=symbols(P),before=E.mk(B+'/monty.bin'),after=E.mk(B+'/monty.bin');
const blob=fs.readFileSync(P+'/prep2.bin');for(let i=0;i<blob.length;i++)after.wr(p.p2_begin+i,blob[i]);
function call(m,pc){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=pc;c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);let cycles=0,setup=null;
 for(let i=0;c.pc!==s.unit_trap;i++){assert(i<20000,'preparation hung');if(setup===null&&[s.jn_prep_row,p.p2_jn_prep_row0,p.p2_jn_prep_row1].includes(c.pc))setup=cycles;c.instruction();cycles+=c.vcycles;}
 assert.equal(c.sp,0x73c0,'balanced stack');return {total:cycles,setup:setup??cycles,loop:setup===null?0:cycles-setup};}
const results=[];let bytes=0,cached=0;
for(let pose=0;pose<23;pose++)for(const mirror of [0,128])for(let shift=0;shift<8;shift++){
 const first=before.rd(s.joe_top_rows+pose);
 for(let skip=first;skip<23;skip++)for(const rows of new Set([1,23-skip])){
  const pictures=[],clocks=[],timings=[],cachedCosts=[];
  for(const [m,pc]of [[before,s.joe_prepare],[after,p.p2_joe_prepare]]){
   for(let i=0;i<12*23;i++)m.wr(s.JOE_PICTURE+i,0xa5);
   for(let i=0;i<5;i++)m.wr(s.jn_key+i,255);
   for(const[a,v]of[[s.jn_frame,pose],[s.jn_dir,mirror],[s.spr_new+2,120+shift],[s.jn_skip,skip],[s.jn_rows_count,rows]])m.wr(a,v);
   const timing=call(m,pc);timings.push(timing);clocks.push(timing.total);pictures.push(Buffer.from(Array.from({length:12*23},(_,i)=>m.rd(s.JOE_PICTURE+i))));
   const cost=call(m,pc).total;assert(cost<1000,'same pose stays cached: '+JSON.stringify({pc,cost,pose,mirror,shift,skip,rows,key:Array.from({length:5},(_,i)=>m.rd(s.jn_key+i))}));cached=Math.max(cached,cost);cachedCosts.push(cost);
  }
  assert.equal(cachedCosts[1],cachedCosts[0],"unchanged cached-pose cost");
  assert.deepEqual(pictures[1],pictures[0],JSON.stringify({pose,mirror,shift,skip,rows}));bytes+=12*23;
  results.push({pose,mirror,shift,skip,rows,before:clocks[0],after:clocks[1],saved:clocks[0]-clocks[1],beforeSetup:timings[0].setup,afterSetup:timings[1].setup,beforeLoop:timings[0].loop,afterLoop:timings[1].loop,full:skip===first&&rows===23-first});
 }
}
function summarize(a){const avg=k=>+(a.reduce((n,q)=>n+q[k],0)/a.length).toFixed(2);const b=avg('before'),c=avg('after');return {cases:a.length,before:b,after:c,saved:+(b-c).toFixed(2),savingPercent:+(100*(b-c)/b).toFixed(3),beforeSetup:avg("beforeSetup"),afterSetup:avg("afterSetup"),beforeLoop:avg("beforeLoop"),afterLoop:avg("afterLoop"),minSaving:Math.min(...a.map(q=>q.saved)),maxSaving:Math.max(...a.map(q=>q.saved))};}
const full=results.filter(q=>q.full),walk=full.filter(q=>q.pose<=4),out={B,experiment:P,isolated:true,all:summarize(results),full:summarize(full),walking:summarize(walk),aligned:summarize(full.filter(q=>q.shift===0)),shifted:summarize(full.filter(q=>q.shift!==0)),cachedCycles:cached,comparedBytes:bytes,memory:{beforeCode:s.joe_put-s.joe_prepare,afterCode:blob.length,extraCode:blob.length-(s.joe_put-s.joe_prepare),extraPersistentData:0},fullCases:full};
fs.writeFileSync(process.env.OUT||P+'/comparison.json',JSON.stringify(out,null,2)+'\n');console.log(JSON.stringify({...out,fullCases:undefined}));
