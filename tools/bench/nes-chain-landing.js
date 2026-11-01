// The free lower end of the 1,9 rope must lead to a short, safe landing.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),results=[];
for(const action of ['down','left','right','long-fall']){
 const m=E.mk(B+'/monty.bin');let steps=0,phase=0,lives=0,trace=[];
 m.onInstr=pc=>{
  if(pc!==s.L_A5D1)return;steps++;
  if(steps===80){
   m.wr(0x71a6,1);m.wr(0x71a7,1);m.wr(0x71a8,9);m.wr(0x705f,0);
   for(let a=0x70c0;a<0x7186;a++)m.wr(a,255);
   const y=action==='long-fall'?151:action==='down'?175:183,x=196;
   m.wr(0x7300,y-3);m.wr(0x7304,y);m.wr(0x7301,x);m.wr(0x7305,x);
   m.wr(0x7079,action==='long-fall'?6:4);m.wr(0x70b2,0);m.wr(0x7076,0);m.wr(0x7077,0);m.wr(0x707c,action==='long-fall'?y-3:92);
   lives=m.rd(0x7049);const c=m.cpu;c.sp-=2;m.wr(c.sp,pc&255);m.wr(c.sp+1,pc>>8);c.pc=s.L_A067;
   m.keyboard.matrix[0]={down:128,left:16,right:64,'long-fall':0}[action];phase=1;return;
  }
  if(phase===1){
   trace.push({y:m.rd(0x7304),x:m.rd(0x7305),state:m.rd(0x7079),fallOrigin:m.rd(0x707c),lives:m.rd(0x7049)});
   if(trace.length>1&&(m.rd(0x7049)!==lives||[0,1].includes(m.rd(0x7079))))phase=2;
  }
 };
 for(let f=0;f<500&&phase!==2;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
 const ok=phase===2&&(action==='long-fall'?m.rd(0x7049)===lives-1&&m.rd(0x7079)===9:m.rd(0x7049)===lives&&[0,1].includes(m.rd(0x7079)));
 results.push({action,ok,trace});
}
const summary={B,cases:results.length,failures:results.filter(q=>!q.ok).length};
const out=process.env.OUT||'build/climb-audit/chain-landing.json';fs.mkdirSync(path.dirname(out),{recursive:true});fs.writeFileSync(out,JSON.stringify({summary,results},null,2));
console.log(JSON.stringify({summary,results}));assert.equal(summary.failures,0,'safe rope landing');
