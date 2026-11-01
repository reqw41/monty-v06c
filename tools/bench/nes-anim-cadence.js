// Compare visible fire/belt phase cadence while Joe stands or walks.
// B=build/nes-native node tools/bench/nes-anim-cadence.js
'use strict';
const path=require('path'),assert=require('assert/strict');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-native',s=symbols(B);
const results=[];
for(const room of [[1,9],[7,2]])for(const moving of [false,true]){
 const m=E.mk(B+'/monty.bin');let steps=0,frame=0;
 const counts={joeMoves:0,preparations:0,fireTicks:0,fireShown:0,beltTicks:0,beltShown:0};
 const maxLag={fire:0,belt:0},lag={fire:0,belt:0};let old=null;
 m.onInstr=pc=>{
  if(pc===s.disp_prep&&frame>=220)counts.preparations++;
  if(pc===s.L_8DA2&&steps>60){const c=m.cpu;c.pc=m.rd(c.sp)|(m.rd(c.sp+1)<<8);c.sp+=2;return;}
  if(pc!==s.L_A5D1)return;
  steps++;m.wr(0x7049,6);m.wr(0x707C,m.rd(0x7300));
  if(steps===50){m.wr(0x705F,m.rd(0x705F)&~4);m.wr(0x71A7,room[0]);m.wr(0x71A8,room[1]);m.wr(0x7079,9);}
 };
 for(frame=0;frame<900;frame++){
  if(frame===10)m.keyboard.matrix[2]|=2;
  if(frame===100)m.keyboard.matrix[2]&=~2;
  m.keyboard.matrix[0]&=~0x50;
  if(frame>180&&moving)m.keyboard.matrix[0]|=(Math.floor(frame/32)%2?0x10:0x40);
  m.frame();
  if(frame<220)continue;
  const cur={x:m.rd(0x7301),fire:m.rd(s.fire_frame),fireShown:m.rd(s.fire_shown),belt:m.rd(s.belt_frame),beltShown:m.rd(s.belt_shown)};
  if(old){
   if(cur.x!==old.x)counts.joeMoves++;
   for(const kind of ['fire','belt']){
    if(cur[kind]!==old[kind])counts[kind+'Ticks']++;
    if(cur[kind+'Shown']!==old[kind+'Shown']){counts[kind+'Shown']++;lag[kind]=0;}
    else if(cur[kind]!==cur[kind+'Shown'])lag[kind]++;
    maxLag[kind]=Math.max(maxLag[kind],lag[kind]);
   }
  }
  old=cur;
 }
 results.push({room:room.join(','),moving,steps,counts,maxLag});
}
console.log(JSON.stringify({B,measuredFrames:680,results},null,2));
if(process.env.ASSERT==='1')for(const row of results.filter(r=>r.moving)){
 assert(row.counts.joeMoves>0,`Joe did not move in room ${row.room}`);
 assert(row.counts.fireShown>=80,`fire animation stalled in room ${row.room}`);
 assert(row.maxLag.fire<=12,`fire phase lagged in room ${row.room}`);
 assert(row.maxLag.belt<=12,`belt phase lagged in room ${row.room}`);
}
