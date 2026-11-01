// Compare actual cached pixels through actual palettes before/after ink repacking.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const dirs=process.argv.slice(2);assert.equal(dirs.length,2,'pass before and after builds');
const snapshots=[];
for(const B of dirs){
 const s=symbols(B),m=E.mk(B+'/monty.bin');
 for(let f=0;f<320;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
 function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;c.regs[7]=0;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');c.instruction();}}
 m.wr(s.nf_snake_count,1);m.wr(s.nes_amulet_ticks,0);m.wr(s.nes_amulet_ticks+1,0);call('nes_snake_palette');
 const pal=Array.from({length:8},(_,i)=>m.rd(s.pal+2*i)),joe=[];
 for(let i=0;i<211;i++)for(const base of [s.joe_row_lo,s.joe_row_hi])for(let x=3;x>=0;x--){const byte=m.rd(base+i),ink=((byte>>(4+x))&1)*2+((byte>>x)&1);joe.push(pal[ink]);}
 const tiles=[];
 for(const dark of [false,true])for(const t of [...Array(224).keys(),0xf8,0xf9,0xfa,0xfb,0xfc,0xfd]){
  m.wr(s.room_colors+1,dark?0x11:0x31);m.wr(s.rr_t,t);const count=[4,5,6,0xa8,0xae,0xb8,0xb9,0xba].includes(t)||t>=0xa0&&t<=0xa7||t>=0xd2&&t<=0xd5?4:1;
  m.wr(s.tile_frames,count);call('tile_build');
  for(let phase=0;phase<count;phase++)for(let y=0;y<8;y++)for(let x=0;x<8;x++){
   const base=s.TILE_IMAGES+24*phase,ink=[4,2,1].reduce((v,b,p)=>v+((m.rd(base+8*p+y)&(128>>x))?b:0),0);tiles.push(pal[ink]);
  }
 }
 snapshots.push({B,joe,tiles});
}
assert.deepEqual(snapshots[1].joe,snapshots[0].joe,'Joe visible colours changed');
assert.deepEqual(snapshots[1].tiles,snapshots[0].tiles,'ordinary tile visible colours changed');
console.log(JSON.stringify({before:dirs[0],after:dirs[1],joeLogicalPixels:snapshots[0].joe.length,tilePixels:snapshots[0].tiles.length,visibleColours:'identical'}));
