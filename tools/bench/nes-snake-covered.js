// Local snake poses must preserve Joe, enemies and all other submitted cells.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/joe-deadline-final',s=symbols(B),results=[];
assert(s.NES_SNAKE_LOCAL,'requires fixed-position snake queues');
for(const enemy of [0x0c,0x2c]){
 const m=E.mk(B+'/monty.bin'),checker=require('./framecheck')(m,s,{manual:true});
 m.onInstr=checker.instruction;
 for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
 function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;
  m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
  for(let n=0;c.pc!==s.unit_trap;n++){assert(n<2000000,name+' hung');m.onInstr(c.pc);c.instruction();}
 }
 m.wr(0x71a7,1);m.wr(0x71a8,9);m.wr(0x705f,0);m.wr(s.nes_q_idle,1);call('L_A067');
 for(let i=192;i<960;i++)m.wr(s.VNT+i,0);
 const offsets=[10*32+4,14*32+12,20*32+24,26*32+20];
 m.wr(s.nf_snake_count,offsets.length);
 for(let k=0;k<offsets.length;k++){
  const offset=offsets[k];m.wr(s.nf_snake_offsets+2*k,offset&255);m.wr(s.nf_snake_offsets+2*k+1,offset>>8);
  for(const [part,delta]of [0,1,32,33].entries())m.wr(s.VNT+offset+delta,0xa0+part);
 }
 for(let k=0;k<6;k++)m.wr(0x7303+4*k,0);
 m.wr(s.video_dirty,0);call('room_redraw');
 // Joe straddles a changing top tile; the enemy straddles the bottom tile.
 for(const [a,v]of [[0x7300,100],[0x7304,103],[0x7301,92],[0x7305,92],
  [0x7303,6],[0x7307,11],[0x7079,0],[0x7308,121],[0x7309,98],[0x730a,enemy],[0x730b,15]])m.wr(a,v);
 function paint(){
  for(let n=0;n<4;n++){
   call('disp_prep');
   for(let j=0;m.rd(s.crit_pend);j++){assert(j<16,'atomic list stuck');m.wr(s.crit_pend,0);call('crit');}
  }
  checker.checkNow();
 }
 paint();assert(m.rd(s.spr_rec),'Joe is actually drawn');assert(m.rd(s.spr_rec+32),'overlapping enemy is actually drawn');
 let phases=0,turns=0;
 for(const x of [248,40,248,40]){
  m.wr(0x7301,x);m.wr(0x7305,x);m.wr(s.lv_dirty,0);call('nes_snake_face_all');
  assert.equal(m.rd(s.lv_dirty),0,'four snakes turning must not rebuild the live list');turns+=4;
  // Restore the overlapping position after choosing the facing.
  m.wr(0x7301,92);m.wr(0x7305,92);
  for(const phase of [0,1,0,1]){
   m.wr(s.snake_frame,phase);m.wr(s.video_dirty,m.rd(s.video_dirty)|s.DIRTY_SNAKE);paint();phases++;
  }
 }
 const pixels=checker.result();assert.equal(pixels.bad,0,JSON.stringify(pixels.examples));
 results.push({enemy:enemy.toString(16),snakes:4,phases,turns,pixels});
}
console.log(JSON.stringify({B,results}));
