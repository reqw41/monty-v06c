// Cached images against independent NES CHR reference after the palette split.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),ref=require('./nes-video-ref');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<320;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<400000,name+' hung');c.instruction();}}
let cases=0;
for(const dark of [false,true])for(const t of [...Array(224).keys(),0xf8,0xf9,0xfa,0xfb,0xfc,0xfd]){
 m.wr(s.room_colors+1,dark?0:0x31);m.wr(s.rr_t,t);
 const count=ref.animated.has(t)?4:1;m.wr(s.tile_frames,count);m.cpu.regs[7]=0;call('tile_build');
 for(let phase=0;phase<count;phase++){
  const want=ref.cell(m,s,t,phase,m.rd(s.belt_shown));
  for(let i=0;i<24;i++)assert.equal(m.rd(s.TILE_IMAGES+24*phase+i),want[i],`tile ${t.toString(16)} phase ${phase}, byte ${i}, dark ${dark}`);
  cases++;
 }
}
console.log(JSON.stringify({B,cases,source:'original NES CHR/OAM',lighting:['lit','dark']}));
