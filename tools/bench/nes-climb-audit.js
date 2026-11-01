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
  if(n>400000)throw Error(name+' hung');
  if(c.pc===s.L_8C13){crossed=true;c.pc=s.L_A067;}
  if(c.pc===s.L_8E0C&&m.rd(0x71a7)===9){crossed=true;break;}
  c.instruction();
 }
}
const sem=t=>t===11?8:t===0x95?0x90:t>=0xc8&&t<0xd8?[0x88,0x89,8,8,0x95,0x95,0xce,0xcf,0xd0,0xd1,0xd2,0xd3,0xd4,0xd5,8,8][t-0xc8]:t;
const rows=[],results=[];const variants=new Map();
for(let level=1;level<=9;level++)for(let index=0;index<99;index++){
 m.memory.bytes.set(boot);const roomRow=index?Math.floor(Math.sqrt(index))-1:0,col=index-roomRow*roomRow-3*roomRow+8;
 m.wr(0x71a6,level);m.wr(0x71a7,roomRow);m.wr(0x71a8,col);m.wr(0x705f,0);m.wr(s.nes_q_idle,1);
 for(let a=0x70c0;a<0x7186;a++)m.wr(a,255);call('L_A067');m.wr(0x705f,0);
 for(const [first,last] of [[s.nes_chain_catch,s.nes_chain_catch_end],[s.nes_chain_align_both,s.nes_chain_align_end],[s.nes_chain_enter_left,s.nes_chain_low_end],[s.nes_chain_exit,s.nes_chain_exit_end]])
  for(let a=first;a<last;a++)assert.equal(m.rd(a),m.img[a],'permanent climb helper overwritten');
 const nt=Array.from({length:960},(_,i)=>sem(m.rd(s.VNT+i))),at=(x,y)=>x<0||x>31||y<6||y>29?0:nt[y*32+x];
 const scene=m.memory.bytes.slice();
 for(let x=0;x<32;x++)for(let y=6;y<30;y++){
  let kind=at(x,y)===0x88&&at(x+1,y)===0x89?'ladder':[0x90,0x95].includes(at(x,y))?'rope':null;
  if(!kind)continue;
  const match=r=>kind==='ladder'?at(x,r)===0x88&&at(x+1,r)===0x89:[0x90,0x95].includes(at(x,r));
  if(match(y-1))continue;let end=y;while(end<29&&match(end+1))end++;
  const run={level,index,room:[roomRow,col],kind,x,top:y,bottom:end,cap:at(x,y-1),raw:m.rd(s.VNT+y*32+x),left:at(x-1,y),right:at(x+1,y),aboveLeft:at(x-1,y-1),aboveRight:at(x+1,y-1)};
  rows.push(run);
  const key=JSON.stringify([kind,x,y,end,nt.slice(Math.max(6,y-2)*32,Math.min(30,end+2)*32)]);
  if(!variants.has(key))variants.set(key,{...run,nt});
  if(end-y<2)continue;
  const bodyRow=y+Math.floor((end-y)/2),startY=bodyRow*8-9,startX=x*8-(kind==='ladder'?1:4);
  for(const direction of ['up','down']){
   m.memory.bytes.set(scene);crossed=false;
   m.wr(0x7300,startY-3);m.wr(0x7304,startY);m.wr(0x7301,startX);m.wr(0x7305,startX);
   m.wr(0x7079,kind==='ladder'?3:4);m.wr(0x70b2,0);m.wr(0x7076,0);m.wr(0x7077,0);m.wr(0x707c,startY-3);
   const trace=[];
   for(let n=0;n<8;n++){m.wr(s.kbmat,direction==='up'?32:128);call('L_88D1');trace.push([m.rd(0x7305),m.rd(0x7304),m.rd(0x7079)]);if(crossed)break;}
   const delta=m.rd(0x7304)-startY;
   results.push({...run,test:'body-'+direction,start:[startX,startY],delta,trace,ok:crossed||(direction==='up'?delta<0:delta>0)&&trace.every(q=>[3,4,5].includes(q[2]))});
  }
  // A free rope end above ordinary floor must measure the remaining drop,
  // not reuse the MSX absolute Y=160. Exercise the complete landing.
  if(kind==='rope'&&end<28&&at(x,end+1)===0){
   let floor=end+1;while(floor<30&&at(x,floor)===0)floor++;
   if(floor<30&&at(x,floor)===8){
    m.memory.bytes.set(scene);crossed=false;
    const edgeY=end*8-9,drop=8*(floor-end)-8,lives=m.rd(0x7049);
    m.wr(0x7300,edgeY-3);m.wr(0x7304,edgeY);m.wr(0x7301,startX);m.wr(0x7305,startX);
    m.wr(0x7079,4);m.wr(0x70b2,0);m.wr(0x7076,0);m.wr(0x7077,0);m.wr(0x707c,0);
    const trace=[];
    for(let n=0;n<32;n++){
     m.wr(s.kbmat,128);call('L_88D1');trace.push([m.rd(0x7305),m.rd(0x7304),m.rd(0x7079),m.rd(0x707c)]);
     if(m.rd(0x7049)!==lives||[0,1].includes(m.rd(0x7079)))break;
    }
    const safe=drop<28;
    results.push({...run,test:'bottom-free-landing',drop,trace,ok:safe?m.rd(0x7049)===lives&&[0,1].includes(m.rd(0x7079)):m.rd(0x7049)===lives-1});
   }
  }
  if(end<29&&at(x,end+1)===8&&(kind==='rope'||at(x+1,end+1)===8)){
   m.memory.bytes.set(scene);crossed=false;
   const ground=end*8-9;
   m.wr(0x7300,ground-3);m.wr(0x7304,ground);m.wr(0x7301,startX);m.wr(0x7305,startX);
   m.wr(0x7079,kind==='ladder'?3:4);m.wr(0x70b2,0);m.wr(0x7076,0);m.wr(0x7077,0);m.wr(0x707c,ground-3);
   const trace=[];
   for(let n=0;n<12;n++){m.wr(s.kbmat,128);call('L_88D1');trace.push([m.rd(0x7305),m.rd(0x7304),m.rd(0x7079)]);}
   results.push({...run,test:'bottom-floor',start:[startX,ground],trace,ok:m.rd(0x7079)===0&&trace.every(q=>q[1]<=ground+1)});
   if(kind==='ladder'){
    const trace=[];
    for(let n=0;n<12;n++){m.wr(s.kbmat,32);call('L_88D1');trace.push([m.rd(0x7305),m.rd(0x7304),m.rd(0x7079)]);}
    results.push({...run,test:'bottom-reenter',start:[startX,ground],trace,ok:m.rd(0x7304)<ground&&m.rd(0x7079)===3});
   }
  }
 }
}
const out={B,rooms:99,levels:9,runs:rows.length,unique:variants.size,counts:rows.reduce((a,q)=>(a[q.kind]=(a[q.kind]||0)+1,a),{}),movementCases:results.length,failures:results.filter(q=>!q.ok)};
const report=process.env.OUT||'build/climb-audit/runs.json';fs.mkdirSync(path.dirname(report),{recursive:true});
fs.writeFileSync(report,JSON.stringify({summary:out,runs:rows,variants:[...variants.values()],results},null,2));
console.log(JSON.stringify(out));

assert.equal(out.failures.length,0,'climb movement/floor regression');
