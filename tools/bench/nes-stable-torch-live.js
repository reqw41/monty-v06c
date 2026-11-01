// Run the real live-cell writer and its compiled path, including colour-only changes.
'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),ref=require('./nes-video-ref');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
let compiled=0,cases=0;
function call(name,a=0){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.regs[7]=a;c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<3000000,name+' hung');if(c.pc===s.fc_rows)compiled++;c.instruction();}}
function paint(){m.wr(s.dc_pt,1);m.wr(s.fl_skm,0);call('force_live_t',s.tile_changed>>8);}
function clear(){for(let t=0;t<256;t++)m.wr(s.tile_changed+t,0);}
for(const count of [2,8]){
 for(let i=0;i<960;i++)m.wr(s.VNT+i,0);
 const cells=[];
 for(const [t,row] of [[0xa8,10],[0xae,12]])for(let col=2;col<2+count;col++){m.wr(s.VNT+row*32+col,t);cells.push({t,row,col});}
 m.wr(s.room_colors+1,0x31);m.wr(s.fire_frame,0);call('room_redraw');
 for(let old=0;old<4;old++)for(let next=0;next<4;next++){
  clear();m.wr(s.tile_changed+0xa8,1);m.wr(s.tile_changed+0xae,1);m.wr(s.fire_shown,old);paint();
  clear();m.wr(s.fire_next,next);call('fire_changes');m.wr(s.fire_shown,next);paint();
  for(const {t,row,col} of cells){const want=ref.cell(m,s,t,next,0);for(let p=0;p<3;p++)for(let y=0;y<8;y++){
   const a=0x8000+p*0x2000+256*col+s.SCREEN_TOP-16-8*row-y;
   assert.equal(m.rd(a),want[p*8+y],`count ${count} ${old}->${next} tile ${t.toString(16)}, plane ${p}, row ${y}`);
  }}cases++;
 }
}
assert(compiled>0,'compiled animation path was exercised');
console.log(JSON.stringify({B,cases,compiledBuckets:compiled,phasePairs:'all 16',colourOnlyTransition:'left torch 2 -> 3',failures:0}));
