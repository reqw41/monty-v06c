// All ten large HUD digits against original NES CHR, including digit 8.
// Tile 38 is reserved for the static fire body and cannot also be its glyph.
'use strict';
const fs=require('fs'),assert=require('assert/strict'),path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');
const rom=fs.readFileSync('orig/nes/monty.nes'),chr=rom.subarray(32784);
const hatInks=[0,2,1,1];
for(let half=0;half<2;half++)for(let plane=0;plane<3;plane++)for(let y=0;y<8;y++){
 let expected=0;
 const tile=0x154+half;
 for(let x=0;x<8&&y>0;x++){
  const off=16*tile+y-1,bit=7-x;
  const pixel=((rom[32784+off]>>bit)&1)|(((rom[32784+off+8]>>bit)&1)<<1);
  if(hatInks[pixel]&(4>>plane))expected|=128>>x;
 }
 assert.equal(m.rd((half?s.style_hat_right:s.style_hat)+plane*8+y),expected,`NES CHR hat ${tile.toString(16)} plane ${plane} row ${y}`);
}
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
assert.deepEqual(Array.from({length:9},(_,i)=>m.rd(s.style_accents+i)),
 [5,103,186,5,159,234,96,196,173],'room accent table survives boot');
assert.equal(m.rd(s.pal+6),103,'fixed skin palette');
assert.equal(m.rd(s.pal+14),103,'start-room accent palette');
function call(name,{a=0,de=0}={}){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73BE;c.regs[7]=a;c.regs[2]=de>>8;c.regs[3]=de&255;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');c.instruction();}}
let scorePlaneWrites=0;
if(s.NES_SCORE_TWO_TONE)m.onWrite=(a,v)=>{
 if(((a>=0x8e00&&a<0x9000)||(a>=0x9200&&a<0x9e00)||(a>=0xce00&&a<0xd000)||(a>=0xd200&&a<0xde00))&&(a&255)>=216&&(a&255)<=223){
  assert.equal(v,0,'score must never be drawn in the accent before recolouring');scorePlaneWrites++;
 }
};
let bytes=0;
for(let digit=0;digit<10;digit++){
 call('nf_digit',{a:digit,de:0x4E});
 const ids=[0,1,32,33].map(d=>m.rd(s.VNT+0x4E+d));assert(!ids.includes(0x38),'digit overlaps fire body');
 call('nf_draw_hud');
 const first=digit===0?0x1F8:0x1D0+4*digit;
 for(let part=0;part<4;part++)for(let plane=0;plane<3;plane++)for(let y=0;y<8;y++){
  const pattern=chr[16*(first+part)+y]|chr[16*(first+part)+8+y];
  const col=14+part%2,row=2+(part>>1),address=0x8000+0x2000*plane+256*col+s.SCREEN_TOP-8-8*row-y;
  const want=s.NES_LEVEL_TWO_TONE&&part>=2&&plane!==1?0:pattern;
  assert.equal(m.rd(address),want,'digit '+digit+' part '+part+' plane '+plane+' row '+y);bytes++;
 }
}
let twoToneCases=0;
if(s.NES_SCORE_TWO_TONE)for(let floor=0;floor<9;floor++){
 m.wr(0x71a7,floor);call('style_palette');
 assert.equal(m.rd(s.pal+4),4,'score lower red remains fixed');
 for(const startCol of s.NES_LEVEL_TWO_TONE?[14,18]:[18])for(let digit=0;digit<10;digit++){
  call('nf_digit',{a:digit,de:64+startCol});call('nf_draw_hud');
  const first=digit===0?0x1f8:0x1d0+4*digit;
  for(let part=0;part<4;part++)for(let plane=0;plane<3;plane++)for(let y=0;y<8;y++){
   const source=16*(first+part)+y,pattern=chr[source]|chr[source+8];
   const col=startCol+part%2,row=2+(part>>1),address=0x8000+0x2000*plane+256*col+s.SCREEN_TOP-s.HUD_YSHIFT-8*row-y;
   const want=part>=2&&plane!==1?0:pattern;
   assert.equal(m.rd(address),want,`HUD col ${startCol} floor ${floor} digit ${digit} part ${part} plane ${plane} row ${y}`);
  }
  for(const plane of [0,2])for(let col=18;col<30;col++)for(let y=0;y<8;y++)assert.equal(m.rd(0x8000+0x2000*plane+256*col+s.SCREEN_TOP-s.HUD_YSHIFT-24-y),0,'entire lower score row is red');
  twoToneCases++;
 }
}
if(s.NES_SCORE_TWO_TONE){
 call('room_redraw');
 for(const plane of [0,2])for(let col=18;col<30;col++)for(let y=0;y<8;y++)assert.equal(m.rd(0x8000+0x2000*plane+256*col+s.SCREEN_TOP-s.HUD_YSHIFT-24-y),0,'room redraw preserves the red lower half');
}
for(const lives of [0,1,3,6,7,11,12,13,255]){
 m.wr(0x7049,lives);call('L_AABB');
 assert.equal(m.rd(0x7049),lives,'HUD drawing preserves the actual life count');
 const shown=Math.min(Math.max(lives-1,0),11);
 for(const [base,slots,skip] of [[0x81,5,0],[0x92,6,5]])for(let i=0;i<slots;i++){
  const off=base+2*i;
  assert.equal(m.rd(s.VNT+off),i+skip<shown?0x6f:0,`lives ${lives} hat left ${off.toString(16)}`);
  assert.equal(m.rd(s.VNT+off+1),i+skip<shown?0xde:0,`lives ${lives} hat right ${off.toString(16)}`);
 }
}
m.wr(0x7049,6);call('L_AABB');call('nf_draw_hud');
for(let half=0;half<2;half++)for(let plane=0;plane<3;plane++)for(let y=0;y<8;y++){
 const addr=0x8000+0x2000*plane+256*(1+half)+s.SCREEN_TOP-8-8*4-y;
 const source=half?s.style_hat_right:s.style_hat;
 assert.equal(m.rd(addr),m.rd(source+plane*8+y),`Joe hat half ${half} plane ${plane} row ${y}`);
}
console.log(JSON.stringify({B,digits:10,twoToneCases,scorePlaneWrites,levelTwoTone:!!s.NES_LEVEL_TWO_TONE,originalChrTiles:40,comparedBytes:bytes,fireBodyOverlap:false,lifeHatCases:9,lifeHatSourceBytesCompared:48,lifeHatSourceTiles:[0x154,0x155],lifeHatSlots:11}));
