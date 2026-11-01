// Every phase/bank transition through the real preparation and live-cell writers.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),ref=require('./nes-video-ref');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
assert.equal(s.MSX_PLATFORM_ROWS,4,'only row 2 animates');
const boot=m.memory.bytes.slice(),colours=[0xa0,0,0x40];let cases=0;const failures=[];
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<3000000,name+' hung');c.instruction();}}
for(const tile of [0xe0,0xe8])for(const count of [2,8])for(let old=0;old<12;old++){
 m.memory.bytes.set(boot);for(let i=0;i<960;i++)m.wr(s.VNT+i,0);for(let col=2;col<2+count;col++)m.wr(s.VNT+14*32+col,tile);
 for(let k=0;k<6;k++){m.wr(0x7303+4*k,0);m.wr(s.spr_rec+16*k,0);m.wr(s.spr_new+16*k,0);}
 m.wr(s.room_colors+(tile>>3),colours[old>>2]);m.wr(s.belt_frame,old&3);m.wr(s.video_dirty,0);call('room_redraw');
 const scene=m.memory.bytes.slice();
 for(let next=0;next<12;next++){
  m.memory.bytes.set(scene);m.wr(s.room_colors+(tile>>3),colours[next>>2]);m.wr(s.belt_frame,next&3);m.wr(s.video_dirty,s.DIRTY_COLOR|s.DIRTY_BELT);
  for(let pass=0;pass<12;pass++){call('disp_prep');if(m.rd(s.crit_pend))call('crit');if(!(m.rd(s.video_dirty)&(s.DIRTY_COLOR|s.DIRTY_BELT)))break;}
  const want=ref.cell(m,s,tile,0,next&3),bad=[];
  for(let col=2;col<2+count;col++)for(let p=0;p<3;p++)for(let y=0;y<8;y++){
   const a=0x8000+p*0x2000+256*col+s.SCREEN_TOP-s.FIELD_YSHIFT-14*8-y;
   if(m.rd(a)!==want[p*8+y]&&bad.length<3)bad.push({col,p,y,actual:m.rd(a),expected:want[p*8+y]});
  }
  if(bad.length)failures.push({tile,count,old,next,bad,dirty:m.rd(s.video_dirty),shown:m.rd(s.belt_shown),colour:m.rd(s.room_colors+(tile>>3))});cases++;
 }
}
console.log(JSON.stringify({B,cases,failures:failures.length,examples:failures.slice(0,8)}));assert.equal(failures.length,0,'platform phase/bank transition');
