// All ten large HUD digits against original NES CHR, including digit 8.
// Tile 38 is reserved for the static fire body and cannot also be its glyph.
'use strict';
const fs=require('fs'),assert=require('assert/strict'),path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');
const rom=fs.readFileSync('orig/nes/monty.nes'),chr=rom.subarray(32784);
const joe=JSON.parse(fs.readFileSync('build/joe_nes/frames.json','utf8')).frames[0];
assert.equal(joe.rows,23);
assert(joe.pixels.slice(3,11).some(row=>row.includes(1)),'hat includes Joe green edge');
const inks=B.includes('3color')?[0,2,3,1]:[0,1,3,1];
for(let half=0;half<2;half++)for(let plane=0;plane<3;plane++)for(let y=0;y<8;y++){
 let expected=0;
 for(let x=0;x<8;x++)if(inks[Number(joe.pixels[y+3][(half*8+x)>>1])]&(4>>plane))expected|=128>>x;
 assert.equal(m.rd((half?s.style_hat_right:s.style_hat)+plane*8+y),expected,`Joe hat source half ${half} plane ${plane} row ${y}`);
}
for(let f=0;f<320;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
function call(name,{a=0,de=0}={}){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73BE;c.regs[7]=a;c.regs[2]=de>>8;c.regs[3]=de&255;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');c.instruction();}}
let bytes=0;
for(let digit=0;digit<10;digit++){
 call('nf_digit',{a:digit,de:0x4E});
 const ids=[0,1,32,33].map(d=>m.rd(s.VNT+0x4E+d));assert(!ids.includes(0x38),'digit overlaps fire body');
 call('nf_draw_hud');
 const first=digit===0?0x1F8:0x1D0+4*digit;
 for(let part=0;part<4;part++)for(let plane=0;plane<3;plane++)for(let y=0;y<8;y++){
  const pattern=chr[16*(first+part)+y]|chr[16*(first+part)+8+y];
  const col=14+part%2,row=2+(part>>1),address=0x8000+0x2000*plane+256*col+s.SCREEN_TOP-8*row-y;
  assert.equal(m.rd(address),plane===1?pattern:0,'digit '+digit+' part '+part+' plane '+plane+' row '+y);bytes++;
 }
}
for(const lives of [0,1,3,6,7,11,12,255]){
 m.wr(0x7049,lives);call('L_AABB');
 assert.equal(m.rd(0x7049),lives,'HUD drawing preserves the actual life count');
 const bottom=Math.min(Math.max(lives-1,0),5);
 for(let i=0;i<5;i++)for(const [row,count] of [[4,bottom],[0,0]]){
  const off=row*32+1+2*i;
  assert.equal(m.rd(s.VNT+off),i<count?0x6f:0,`lives ${lives} hat left ${row},${i}`);
  assert.equal(m.rd(s.VNT+off+1),i<count?0x6e:0,`lives ${lives} hat right ${row},${i}`);
 }
}
m.wr(0x7049,6);call('L_AABB');call('nf_draw_hud');
for(let half=0;half<2;half++)for(let plane=0;plane<3;plane++)for(let y=0;y<8;y++){
 const addr=0x8000+0x2000*plane+256*(1+half)+s.SCREEN_TOP-8*4-y;
 const source=half?s.style_hat_right:s.style_hat;
 assert.equal(m.rd(addr),m.rd(source+plane*8+y),`Joe hat half ${half} plane ${plane} row ${y}`);
}
console.log(JSON.stringify({B,digits:10,originalChrTiles:40,comparedBytes:bytes,fireBodyOverlap:false,lifeHatCases:8,lifeHatSourceBytesCompared:48,lifeHatPixelsCompared:48}));
