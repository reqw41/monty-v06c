// Reuse the established timing workload without modifying its ROM or inputs.
'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),profile=require('./preparation-profile');
const B=process.env.B||'build/rope-release-final',s=symbols(B),mk=E.mk,records=[];
function stats(a){if(!a.length)return null;const q=[...a].sort((a,b)=>a-b),sum=q.reduce((a,b)=>a+b,0),mean=sum/q.length;
 return {count:q.length,total:sum,mean:+mean.toFixed(2),p95:q[Math.min(q.length-1,Math.floor(q.length*.95))],max:q.at(-1)};}
E.mk=(...args)=>{
 const m=mk(...args),p=profile(m,s);let hook=null,steps=0,armed=false,started=false;
 const callback=pc=>{if(pc===s.L_A5D1&&++steps===150)armed=true;if(hook)hook(pc);};
 Object.defineProperty(m,'onInstr',{get:()=>callback,set:fn=>{hook=fn;}});
 const frame=m.frame;m.frame=()=>{p.frameStart();frame();if(armed&&!started){p.activate();started=true;}};
 records.push({m,p});return m;
};
const oldOut=process.env.OUT;delete process.env.OUT;
const workload=[],log=console.log;console.log=(...args)=>{if(typeof args[0]==='string'&&args[0][0]==='{'){const q=JSON.parse(args[0]);if(q.room&&q.gaps)workload.push(q);}log(...args);};
require('./nes-frame-pacing');
console.log=log;
if(process.env.REFERENCE){const reference=JSON.parse(fs.readFileSync(process.env.REFERENCE));assert.deepEqual(workload,reference.results,'passive profiling must preserve every workload count and interval');}
const results=records.map(({m,p},index)=>{
 const q=p.result();assert(q.frames>0);
 const waitStats={};for(const kind of ['queueHero','queueTail']){const list=q.queueWaits.filter(z=>z.kind===kind);waitStats[kind]={cycles:stats(list.map(z=>z.cycles)),frameSpans:stats(list.map(z=>z.endFrame-z.startFrame))};}
 const dispatch={};for(const kind of ['preparedPlan','deferredTail'])dispatch[kind]=stats(q.dispatchLatency.filter(z=>z.kind===kind).map(z=>z.cycles));
 const frameCosts={};for(const kind of Object.keys(q.totals))frameCosts[kind]=stats(q.frameBuckets.map(f=>f[kind]));
 const row={...q,index,waitStats,dispatch,frameCosts};
 console.log('Detailed',JSON.stringify({index,frames:q.frames,perFrame:q.perFrame,waitStats,dispatch}));return row;
});
if(oldOut)fs.writeFileSync(oldOut,JSON.stringify({B,method:'Post-execution vector cycles plus16cycles/IRQ acknowledgement; whole physical frames; exclusive buckets conserve exact beam time. Routine costs are inclusive, self costs are exclusive. No ROM/input changes.',workload,passivityReference:process.env.REFERENCE||null,results},null,2)+'\n');
