// Compare only mask-generation loops; cache lookup/selection is excluded.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
process.chdir(path.resolve(__dirname,'../..'));const root=process.cwd();
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
const dir=path.join(root,'build/shift-neighbor');fs.mkdirSync(dir,{recursive:true});
cp.execFileSync(path.join(root,'tools/sjasmplus'),['--nologo','--i8080',path.join(root,'tools/bench/shift-neighbor.asm')],{cwd:dir,stdio:'pipe'});
const code=fs.readFileSync(dir+'/near.bin');
for(let f=0;f<320;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
for(let i=0;i<code.length;i++)m.wr(0xe000+i,code[i]);
function call(pc,{hl=0,de=0,bc=0,a=0}={}){
 const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=pc;c.sp=0x73be;
 c.regs[4]=hl>>8;c.regs[5]=hl&255;c.regs[2]=de>>8;c.regs[3]=de&255;c.regs[0]=bc>>8;c.regs[1]=bc&255;c.regs[7]=a;
 m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);let cycles=0;
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<100000,'mask loop hung');c.instruction();cycles+=c.vcycles;}
 return cycles;
}
const cases=[];
for(let n=0;n<s.PS_N;n++){
 const nm=m.rd(s.ps_names+n),p=m.rd(s.sprite_sources+(nm-12)/2)|m.rd(s.sprite_sources+(nm-12)/2+1)<<8;
 let first=16,last=-1;for(let y=0;y<16;y++)if(m.rd(p+y)||m.rd(p+16+y)){first=Math.min(first,y);last=y;}
 const rows=last-first+1;
 for(const shift of [1,3,5,7]){
  const want=Array(3*rows).fill(0),seed=want.slice();
  for(let y=0;y<rows;y++){
   const v=(m.rd(p+first+y)<<16)|(m.rd(p+16+first+y)<<8);
   for(let col=0;col<3;col++){
    want[col*rows+y]=(v>>>shift>>>((2-col)*8))&255;
    seed[col*rows+y]=(v>>>(shift-1)>>>((2-col)*8))&255;
   }
  }
  call(s.rotate_select,{a:shift});const mask=255>>>shift;
  for(const a of [s.smk_m0,s.smk_m1])m.wr(a+1,mask);
  for(const a of [s.smk_n1,s.smk_n2])m.wr(a+1,mask^255);
  m.wr(s.sp_line,rows);
  const full=call(s.smk1,{hl:p+first,de:0xfbd0});
  for(let col=0;col<3;col++)for(let y=0;y<rows;y++)assert.equal(m.rd(0xfbd0+16*col+y),want[col*rows+y],'full source loop');
  for(let i=0;i<seed.length;i++)m.wr(0x8000+i,seed[i]);
  const near=call(0xe000,{hl:0x8000,de:0xfbd0,bc:rows*257});
  for(let col=0;col<3;col++)for(let y=0;y<rows;y++)assert.equal(m.rd(0xfbd0+16*col+y),want[col*rows+y],'one-bit refinement');
  cases.push({name:nm.toString(16),shift,rows,full,near});
 }
}
const mean=k=>Math.round(cases.reduce((v,q)=>v+q[k],0)/cases.length);
console.log(JSON.stringify({B,cases:cases.length,fullMean:mean('full'),refineMean:mean('near'),innerLoopOnly:true,lookupExcluded:true,rows14:cases.filter(q=>q.rows===14).slice(0,4)}));
