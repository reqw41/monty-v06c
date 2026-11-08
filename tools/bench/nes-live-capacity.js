// No live cell is dropped, and no cached shift is touched, across the NES maps.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const original=require('./video-ref');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
const cached=[];
for(let i=0;i<s.PS_N*(s.PS_SHIFTS||8);i++){
 const a=m.rd(s.ps_tab+2*i)|m.rd(s.ps_tab+2*i+1)<<8,rows=m.rd(s.ps_rr+Math.floor(i/(s.PS_SHIFTS||8)));
 if(a){
  const ent=Math.floor(i/(s.PS_SHIFTS||8)),virt=s.ps_vtab!==undefined&&ent>=3,name=virt?m.rd(s.ps_vtab+4*(ent-3)+((i%8)>>1)):m.rd(s.ps_names+ent),first=m.rd(s.spr_trim+name); // виртуальные кадры катящегося черепа (ps_vtab): поза по сдвигу
  const bytes=Array.from({length:3*rows},(_,j)=>m.rd(a+j));
  for(let col=0;col<3;col++)for(let y=0;y<rows;y++){
   const raw=(original.sprite(name,0,first+y)<<16)|(original.sprite(name,1,first+y)<<8);
   assert.equal(bytes[col*rows+y],(raw>>>((i%(s.PS_SHIFTS||8))*(s.PS_SHIFTS===4?2:1))>>>((2-col)*8))&255,'prepared mask matches original sprite');
  }
  cached.push({a,bytes});
 }
}
assert(cached.length>=(s.PS_SEED_POSES?4*s.PS_SEED_POSES:(s.PS_BLOCKS||29)),'every configured shift prepared');
function call(name){
 const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;
 m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){
  assert(n<1000000,name+' hung');if(c.pc===s.L_8C13)c.pc=s.L_A067;c.instruction();
 }
}
let cases=0,max=0,where=null,maxSnakes=0;
for(const flags of [0,255])for(let level=1;level<=9;level++)for(let index=0;index<99;index++){
 m.wr(0x71a6,level);m.wr(0x71a7,0);m.wr(0x71a8,index+8);
 m.wr(0x705f,0);m.wr(s.nes_q_idle,1);
 for(let a=0x70c0;a<0x7186;a++)m.wr(a,flags);
 call('L_A067');
 if(s.NES_SNAKE_LOCAL){
  const cells=[];
  for(let i=192;i<960;i++)if((m.rd(s.VNT+i)&0xf8)===0xa0)cells.push(i);
  const snakes=m.rd(s.nf_snake_count),tracked=[];
  for(let k=0;k<snakes;k++){
   const a=s.nf_snake_offsets+2*k,offset=m.rd(a)|m.rd(a+1)<<8;
   tracked.push(offset,offset+1,offset+32,offset+33);
  }
  assert.deepEqual(tracked.sort((a,b)=>a-b),cells,`every snake is tracked ${level}/${index}/${flags}`);
  maxSnakes=Math.max(maxSnakes,snakes);
 }
 const expected=[];
 for(let i=192;i<960;i++)if(m.rd(s.lv_idx+m.rd(s.VNT+i))!==255&&!(s.NES_SNAKE_LOCAL&&(m.rd(s.VNT+i)&0xf8)===0xa0))expected.push(s.VNT+i);
 assert(expected.length<=s.LIVE_N,`live capacity ${level}/${index}/${flags}: ${expected.length}`);
 call('live_build');
 const count=m.rd(s.lv_beg+s.LV_N),actual=[];
 for(let i=0;i<count;i++)actual.push(m.rd(s.live_list+i)|m.rd(s.live_hi+i)<<8);
 assert.deepEqual(actual.sort((a,b)=>a-b),expected,'every live cell was retained');
 for(const {a,bytes}of cached)for(let i=0;i<bytes.length;i++)assert.equal(m.rd(a+i),bytes[i],'shift overwritten at '+(a+i).toString(16));
 if(count>max){max=count;where={level,index,flags};}cases++;
}
console.log(JSON.stringify({B,cases,rooms:99,levels:9,capacity:s.LIVE_N,maxLiveCells:max,where,maxSnakes,cachedShiftsPreserved:cached.length}));
