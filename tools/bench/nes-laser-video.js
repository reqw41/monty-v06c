// Horizontal E8 platforms use the exact two original MSX masks.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
const cart=fs.readFileSync('build/monty_entry.bin'),patterns=[...Array(2)].map((_,i)=>Array.from(cart.subarray(0x85ca+8*i,0x85d2+8*i)));
assert.deepEqual(patterns,[[255,102,195,102,255,0,0,0],[255,102,24,102,255,0,0,0]]);
assert.equal(s.MSX_PLATFORM_ROWS,4);assert.equal(s.MSX_PLATFORM_INK,1);assert.equal(s.MSX_PLATFORM_BODY_INK,6);assert.equal(m.rd(s.pal+12),160,'existing cyan chain palette');assert.equal(m.rd(s.full_laser_rowmask+1),4);
for(let phase=0;phase<4;phase++){
 const strip=m.rd(s.full_laser_h+phase);
 assert.deepEqual(Array.from({length:8},(_,y)=>m.rd(s.full_raw+8*strip+y)),patterns[phase&1],'raw MSX platform phase');
}
function call(name,a=0){const c=m.cpu;c.iff=false;c.iff_pending=0;c.sp=0x73be;c.pc=s[name];c.regs[7]=a;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');c.instruction();}}
m.wr(s.rr_t,0xe8);call('tile_belt_frames');assert.equal(m.cpu.regs[7],2,'two phases per visibility bank');
m.wr(s.mb_d+10,0x14);m.wr(s.mb_d+4,0x10);m.wr(s.tile_frames,6);call('tile_build');
for(let phase=0;phase<6;phase++)for(let p=0;p<3;p++)for(let y=0;y<8;y++){
 const ink=y===2?1:6,want=!(phase>=2&&phase<4)&&(ink&(4>>p))?patterns[phase&1][y]:0;
 assert.equal(m.rd(s.TILE_IMAGES+24*phase+8*p+y),want,`cache ${phase}/${p}/${y}`);
}
if(process.env.OUT)fs.writeFileSync(process.env.OUT,JSON.stringify({palette:Array.from({length:8},(_,i)=>m.rd(s.pal+2*i)),frames:Array.from({length:6},(_,phase)=>Array.from({length:24},(_,i)=>m.rd(s.TILE_IMAGES+24*phase+i)))}));
console.log(JSON.stringify({B,platform:'horizontal',art:'original MSX',source:'MSX ROM 85CA/85D2',poses:2,cacheImages:6,phaseRows:[2],phasePlanes:['C000'],bodyInk:6,middleInk:1}));
