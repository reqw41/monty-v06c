// The recovered cache overlaps title-only data: verify both lifetimes.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<600;f++)m.frame();
for(let a=s.nes_title_notes;a<s.nes_title_end;a++)assert.equal(m.rd(a),m.img[a],'cold title music overwritten at '+a.toString(16));
let count=0;for(let i=0;i<s.PS_N*(s.PS_SHIFTS||8);i++)if(m.rd(s.ps_tab+2*i)||m.rd(s.ps_tab+2*i+1))count++;
assert.equal(count,0,'cache waits until title music has stopped');
m.keyboard.matrix[2]=2;for(let f=0;f<400;f++)m.frame();m.keyboard.matrix[2]=0;
const cache=[];
for(let i=0;i<s.PS_N*(s.PS_SHIFTS||8);i++){
 const a=m.rd(s.ps_tab+2*i)|m.rd(s.ps_tab+2*i+1)<<8,rows=m.rd(s.ps_rr+Math.floor(i/(s.PS_SHIFTS||8)));
 if(a)cache.push({a,bytes:Array.from({length:3*rows},(_,j)=>m.rd(a+j))});
}
const protectedBlocks=cache.slice();
if(s.nes_seed_masks)protectedBlocks.push({a:s.nes_seed_masks,skip:s.nsm_page+1,bytes:Array.from({length:s.nes_seed_end-s.nes_seed_masks},(_,j)=>m.rd(s.nes_seed_masks+j))});
assert(cache.length>=(s.PS_SEED_POSES?4*s.PS_SEED_POSES:(s.PS_BLOCKS||29)));let forced=false,warm=false,restarted=false,steps=0;
if(s.NES_CHEAT_PACKED&&!s.PS_SEED_POSES)assert.equal(cache.length,s.PS_BLOCKS||32,'packed trainer must preserve every configured shift');
m.onInstr=pc=>{
 if(pc===s.L_A5D1){steps++;if(!forced){forced=true;m.cpu.sp=s.GSTACK;m.cpu.pc=s.game_over;}}
 if(pc===s.go1)m.keyboard.matrix[7]=128;
 if(pc===s.title_warm_menu){
  warm=true;m.keyboard.matrix[7]=0;
  for(const {a,bytes,skip}of protectedBlocks)for(let i=0;i<bytes.length;i++)if(a+i!==skip)assert.equal(m.rd(a+i),bytes[i],'warm title overwrote a shift');
  m.keyboard.matrix[2]=4;
 }
 if(warm&&pc===s.L_A5D1&&m.rd(0x71a6)===2&&!(m.rd(0x705f)&4))restarted=true;
};
for(let f=0;f<800&&!restarted;f++)m.frame();
assert(forced&&warm&&restarted,'warm restart keeps the installed cache');
for(const {a,bytes,skip}of protectedBlocks)for(let i=0;i<bytes.length;i++)if(a+i!==skip)assert.equal(m.rd(a+i),bytes[i],'restarted game overwrote a shift');
console.log(JSON.stringify({B,coldTitleFrames:600,titleMusicBytes:s.nes_title_end-s.nes_title_notes,cachedShifts:cache.length,warmRestart:true}));
