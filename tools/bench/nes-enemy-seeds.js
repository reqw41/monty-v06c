// Independently check every pose/phase and clipped edge against raw sprite bits.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const dirs=process.argv.slice(2);assert(dirs.length,'pass baseline and/or sparse build directories');
const reports=[];
for(const B of dirs){
 const s=symbols(B),m=E.mk(B+'/monty.bin');
 for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
 function call(pc,hl=0){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=pc;c.sp=0x73be;c.regs[4]=hl>>8;c.regs[5]=hl&255;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);let cycles=0;
  for(let n=0;c.pc!==s.unit_trap;n++){assert(n<100000,'sprite preparation hung');c.instruction();cycles+=c.vcycles;}return cycles;}
 const cache=[],stride=s.PS_SHIFTS||8;
 let poolBytes=0;for(let a=s.nes_ps_pages;a<s.nes_ps_pages_end;a+=4)poolBytes+=m.img[a+2]+256*m.img[a+3]-m.img[a]-256*m.img[a+1];
 for(let i=0;i<s.PS_N*stride;i++){
  const a=m.rd(s.ps_tab+2*i)|m.rd(s.ps_tab+2*i+1)<<8,R=m.rd(s.ps_rr+Math.floor(i/stride));
  if(a)cache.push({a,bytes:Array.from({length:3*R},(_,j)=>m.rd(a+j))});
 }
 const helper=s.nes_seed_masks?Array.from({length:s.nes_seed_end-s.nes_seed_masks},(_,j)=>m.rd(s.nes_seed_masks+j)):[];
 const cases=[];
 for(const y of [80,43,231])for(let f=0;f<s.PS_N;f++)for(let shift=0;shift<8;shift++){
  const nm=m.rd(s.ps_names+f),p=m.rd(s.sprite_sources+(nm-12)/2)|m.rd(s.sprite_sources+(nm-12)/2+1)<<8;
  for(let i=0;i<4;i++)m.wr(s.mk_key+8+i,255);
  m.wr(s.sp_k,2);for(const [i,v]of [y,120+shift,nm,15].entries())m.wr(0x7308+i,v);
  const cycles=call(s.spr_one,0x7308),R=m.rd(s.st_rows),first=m.rd(s.sm_off),hi=m.rd(s.ps_hi+2),lo=m.rd(s.ps_lo+2),base=hi?(hi<<8|lo):s.SPR_SLOTS+2*256+s.SM_OFS,step=hi?m.rd(s.ps_r+2):16;
  for(let col=0;col<3;col++)for(let r=0;r<R;r++){
   if(m.rd(s.sv_zc)&(1<<col))continue;
   const bits=(m.rd(p+first+r)<<16)|(m.rd(p+16+first+r)<<8);
   assert.equal(m.rd(base+col*step+r),(bits>>>shift>>>((2-col)*8))&255,`mask ${B}/${nm.toString(16)}/${shift}/Y${y}/${col}/${r}`);
  }
  assert.equal(m.rd(s.sp_x),120+shift,'seed lookup restored real X');
  cases.push({name:nm.toString(16),shift,y,cycles,cached:!!hi});
 }
 for(const {a,bytes}of cache)for(let j=0;j<bytes.length;j++)assert.equal(m.rd(a+j),bytes[j],'immutable seed');
 for(let j=0;j<helper.length;j++)if(s.nes_seed_masks+j!==s.nsm_page+1)assert.equal(m.rd(s.nes_seed_masks+j),helper[j],'seed helper changed except patched page');
 const mean=xs=>Math.round(xs.reduce((n,q)=>n+q.cycles,0)/xs.length),normal=cases.filter(q=>q.y===80),covered=normal.filter(q=>['2c','30','c','10'].includes(q.name));
 reports.push({B,cases:cases.length,records:cache.length,maskBytes:cache.reduce((n,q)=>n+q.bytes.length,0),poolBytes,freePoolBytes:poolBytes-cache.reduce((n,q)=>n+q.bytes.length,0),tableBytes:2*stride*s.PS_N,helperBytes:helper.length,heapFree:s.PS_TOP-s.ps_heap,normalMean:mean(normal),coveredMean:mean(covered),evenMean:mean(covered.filter(q=>!(q.shift&1))),oddMean:mean(covered.filter(q=>q.shift&1)),all:cases});
}
if(process.env.OUT)fs.writeFileSync(process.env.OUT,JSON.stringify(reports,null,2));
for(const {all,...q}of reports)console.log(JSON.stringify(q));
