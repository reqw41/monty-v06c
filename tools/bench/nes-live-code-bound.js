// Every row/plane mask fits the reserved live-code span without touching cached shifts.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
const cache=[];
for(let i=0;i<s.PS_N*(s.PS_SHIFTS||8);i++){
 const a=m.rd(s.ps_tab+2*i)|(m.rd(s.ps_tab+2*i+1)<<8),rows=m.rd(s.ps_rr+Math.floor(i/(s.PS_SHIFTS||8)));
 if(a)cache.push({a,bytes:Array.from({length:3*rows},(_,j)=>m.rd(a+j))});
}
if(s.STABLE_OBJECT_COLORS)assert(cache.length>=(s.PS_SEED_POSES?4*s.PS_SEED_POSES:(s.PS_BLOCKS||29)),'prepared enemy cache must retain every configured shift');
let max=-1,cases=0;m.onWrite=(a)=>{if(a>=s.live_code&&a<s.live_code+125)max=Math.max(max,a-s.live_code);};
function call(){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s.fl_compile;c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<100000,'compile hung');c.instruction();}}
for(let rows=0;rows<256;rows++)for(let planes=0;planes<8;planes++){
 m.wr(s.dc_pt,1);m.wr(s.fl_n,8);m.wr(s.rr_t,4);m.wr(s.full_anim_rowmask+m.rd(s.lv_idx+4),rows);
 m.wr(s.fl_pm,((planes&4)?0x80:0)|((planes&2)?0x20:0)|((planes&1)?8:0));
 m.wr(s.fl_source,s.TILE_IMAGES&255);m.wr(s.fl_source+1,s.TILE_IMAGES>>8);call();cases++;
}
assert.equal(max+1,s.LIVE_CODE_BYTES,'exact worst-case compiler bound');
for(const {a,bytes}of cache)for(let i=0;i<bytes.length;i++)assert.equal(m.rd(a+i),bytes[i],'cached sprite mask overwritten at '+(a+i).toString(16));
console.log(JSON.stringify({B,cases,reservedBytes:s.LIVE_CODE_BYTES,maxGeneratedBytes:max+1,cachedShiftsPreserved:cache.length}));
