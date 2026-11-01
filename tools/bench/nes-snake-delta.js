// Pose deltas against independent NES pixels; direction changes remain full draws.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),ref=require('./nes-video-ref');
const results=[];
for(const B of process.argv.slice(2)){
 const s=symbols(B),m=E.mk(B+'/monty.bin');
 for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
 const boot=m.memory.bytes.slice();let watch=false,writes=[];
 m.onWrite=a=>{if(watch&&a>=0x8000&&a<0xe000)writes.push(a);};
 function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);let cycles=0;
  for(let n=0;c.pc!==s.unit_trap;n++){assert(n<2000000,name+' hung');c.instruction();cycles+=c.vcycles;}return cycles;}
 const address=(row,col,p,y)=>0x8000+p*0x2000+256*col+s.SCREEN_TOP-s.FIELD_YSHIFT-8*row-y;
 function check(row,col){for(let part=0;part<4;part++){
  const rr=row+(part>>1),cc=col+(part&1),t=m.rd(s.VNT+32*rr+cc),want=ref.cell(m,s,t,m.rd(s.snake_shown),m.rd(s.belt_shown));
  for(let p=0;p<3;p++)for(let y=0;y<8;y++)assert.equal(m.rd(address(rr,cc,p,y)),want[8*p+y],`snake ${B}/${t.toString(16)}/${p}/${y}`);
 }}
 const poses=[];
 for(const tiles of [[0xa0,0xa1,0xa2,0xa3],[0xa5,0xa4,0xa7,0xa6]])for(const old of [0,1]){
  m.memory.bytes.set(boot);for(let i=0;i<960;i++)m.wr(s.VNT+i,0);
  for(let k=0;k<6;k++){m.wr(0x7303+4*k,0);m.wr(s.spr_rec+16*k,0);m.wr(s.spr_new+16*k,0);}
  for(let part=0;part<4;part++)m.wr(s.VNT+32*(14+(part>>1))+12+(part&1),tiles[part]);
  if(s.NES_SNAKE_LOCAL){m.wr(s.nf_snake_count,1);m.wr(s.nf_snake_offsets,(14*32+12)&255);m.wr(s.nf_snake_offsets+1,(14*32+12)>>8);}
  m.wr(s.snake_frame,old);m.wr(s.video_dirty,0);call('room_redraw');check(14,12);
  m.wr(s.snake_frame,old^1);m.wr(s.video_dirty,s.DIRTY_SNAKE);m.wr(s.fire_ran,0);
  m.wr(s.dl_n,0);m.wr(s.dl_ovf,0);writes=[];watch=true;let cycles=call('nes_snake_render');if(s.NES_SNAKE_LOCAL)cycles+=call('draw_list');watch=false;check(14,12);
  if(s.NES_SNAKE_LOCAL)assert.equal(writes.length,48,'two changed tiles through the covered-cell queue');
  if(s.nes_snake_compilable)assert.equal(writes.length,s.NES_MONO_SNAKE?3:6,'three changing rows in the selected planes');
  poses.push({facing:tiles[0]===0xa0?'right':'left',from:old,to:old^1,cycles,screenBytes:writes.length});
 }
 // Real room and real facing update: use PND/draw_list, with a simultaneous pose change.
 m.memory.bytes.set(boot);m.wr(0x71a7,1);m.wr(0x71a8,9);m.wr(0x705f,0);m.wr(s.nes_q_idle,1);
 call('L_A067');assert.equal(m.rd(s.nf_snake_count),1);
 for(let k=0;k<6;k++){m.wr(0x7303+4*k,0);m.wr(s.spr_rec+16*k,0);m.wr(s.spr_new+16*k,0);}
 call('room_redraw');let turns=0;
 for(const phase of [0,1,0,1])for(const x of [248,40]){
  m.wr(0x7301,x);m.wr(0x7305,x);m.wr(s.lv_dirty,0);call('nes_snake_face_all');
  if(s.NES_SNAKE_LOCAL)assert.equal(m.rd(s.lv_dirty),0,'turning a fixed snake must not rebuild the live list');
  assert.equal(m.rd(s.VNT+26*32+29),x===248?0xa0:0xa5,'faces Joe');
  m.wr(s.snake_frame,phase);m.wr(s.fire_frame,m.rd(s.fire_shown));m.wr(s.belt_frame,m.rd(s.belt_shown));m.wr(s.video_dirty,m.rd(s.video_dirty)|s.DIRTY_SNAKE);
  for(let n=0;n<16;n++){call('disp_prep');if(m.rd(s.crit_pend))call('crit');}
  check(26,29);turns++;
 }
 results.push({B,poseCases:poses,turnCases:turns,meanCycles:Math.round(poses.reduce((n,p)=>n+p.cycles,0)/poses.length),screenBytesPerPose:poses[0].screenBytes});
}
console.log(JSON.stringify(results));if(process.env.OUT)fs.writeFileSync(process.env.OUT,JSON.stringify(results,null,2));
