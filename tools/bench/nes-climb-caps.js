// Decode every ordinary room and level, then exercise each climb run.
'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
const boot=m.memory.bytes.slice();let crossed=false;
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){
  if(n>400000)throw Error(name+' hung at '+c.pc.toString(16)+' '+globalThis.climbCase);
  if(c.pc===s.L_8C13){crossed=true;c.pc=s.L_A067;}
  if(c.pc===s.L_8E0C&&m.rd(0x71a7)===9){crossed=true;break;}
  c.instruction();
 }
}
const sem=t=>t===11?8:t===0x95?0x90:t>=0xc8&&t<0xd8?[0x88,0x89,8,8,0x95,0x95,0xce,0xcf,0xd0,0xd1,0xd2,0xd3,0xd4,0xd5,8,8][t-0xc8]:t;

const data=JSON.parse(fs.readFileSync(process.env.AUDIT||'build/climb-audit/runs.json')),results=[];
for(const run of data.variants){
 const {level,index,kind,x,top,bottom}=run;
 if(bottom-top<2)continue;
 m.memory.bytes.set(boot);m.wr(0x71a6,level);m.wr(0x71a7,run.room[0]);m.wr(0x71a8,run.room[1]);m.wr(0x705f,0);m.wr(s.nes_q_idle,1);
 for(let a=0x70c0;a<0x7186;a++)m.wr(a,255);call('L_A067');m.wr(0x705f,0);const scene=m.memory.bytes.slice();
 const at=(xx,yy)=>xx<0||xx>31||yy<6||yy>29?0:run.nt[yy*32+xx];
 const cap=kind==='ladder'&&at(x,top-1)===16?top-1:top;
 if(kind==='ladder'&&at(x,cap)!==16)continue;
 if(kind==='rope'&&run.raw!==144)continue;
 const sides=kind==='ladder'?[0]:[-1,1].filter(z=>at(x+z,top)===8&&at(x+z,top-1)!==8);
 if(kind==='rope'&&s.nes_chain_idle&&sides.length)for(let delta=-4;delta<=3;delta++){
  m.memory.bytes.set(scene);crossed=false;
  const base=x*8-4,ledgeY=8*cap-17,xx=base+delta;
  if(xx<4||xx>=240)continue;
  for(const [a,v]of [[0x7300,ledgeY-3],[0x7304,ledgeY],[0x7301,xx],[0x7305,xx],[0x7079,1],[0x7076,0],[0x7077,0],[0x707c,ledgeY-3],[0x7072,18]])m.wr(a,v);
  m.wr(s.kbmat,0);m.wr(s.kbmat+7,0);const trace=[];
  for(let n=0;n<16;n++){call('L_88D1');trace.push([m.rd(0x7305),m.rd(0x7304),m.rd(0x7079)]);}
  results.push({...run,test:'cap-idle',delta,ledgeY,start:[xx,ledgeY],trace,ok:trace.every(q=>q[0]===base&&q[1]===ledgeY&&q[2]===4)});
 }
 for(const side of sides)for(const delta of [-2,0,2])for(const dir of ['down','up']){
  globalThis.climbCase=JSON.stringify({index,kind,x,top,bottom,side,delta,dir});
  m.memory.bytes.set(scene);crossed=false;
  const base=x*8-(kind==='ladder'?1:4),ledgeY=8*cap-17,xx=base+(dir==='down'?side*8+delta:delta),yy=ledgeY+(dir==='up'?16:0);
  if(xx<4||xx>=240)continue;
  m.wr(0x7300,yy-3);m.wr(0x7304,yy);m.wr(0x7301,xx);m.wr(0x7305,xx);m.wr(0x7079,dir==='down'?0:kind==='ladder'?3:4);m.wr(0x70b2,0);m.wr(0x7076,0);m.wr(0x7077,0);m.wr(0x707c,yy-3);
  let trace=[];
  for(let n=0;n<(dir==='down'?18:44);n++){
   m.wr(s.kbmat,dir==='down'?128:32);call('L_88D1');trace.push([m.rd(0x7305),m.rd(0x7304),m.rd(0x7079)]);if(crossed||(dir==='up'&&m.rd(0x7304)<=ledgeY+1&&[0,1].includes(m.rd(0x7079))))break;
  }
  const end=trace.at(-1),ok=dir==='down'?end[1]>yy&&trace.every(q=>(q[2]===3||q[2]===4)&&(kind!=='rope'||q[0]===base)):end[1]<=ledgeY+1&&([0,1].includes(end[2])||(kind==='ladder'&&at(x,cap-1)===0x88&&end[2]===3));
  results.push({...run,test:'cap-'+dir,side,delta,start:[xx,yy],ledgeY,trace,ok});
 }
}
const summary={cases:results.length,failures:results.filter(q=>!q.ok).map(q=>({index:q.index,kind:q.kind,x:q.x,top:q.top,bottom:q.bottom,side:q.side,delta:q.delta,test:q.test,start:q.start,end:q.trace.at(-1)}))};
const report=process.env.OUT||'build/climb-audit/caps.json';fs.mkdirSync(path.dirname(report),{recursive:true});
fs.writeFileSync(report,JSON.stringify({summary,results},null,2));console.log(JSON.stringify(summary));

const live=new Map();
for(const q of results.filter(q=>q.delta===0)){
 const key=JSON.stringify([q.kind,q.test,q.side,q.top,q.bottom-q.top,Array.from({length:5},(_,yy)=>Array.from({length:5},(_,xx)=>q.nt[(q.top-2+yy)*32+q.x-2+xx]))]);
 if(!live.has(key))live.set(key,q);
}
fs.writeFileSync(path.join(path.dirname(report),'live-cases.json'),JSON.stringify([...live.values()]));
assert.equal(summary.failures.length,0,'climb cap regression');
