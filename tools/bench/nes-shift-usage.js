// Observed pose/X-phase pairs while enemies run in each level-1 room.
// Joe is pinned in place to isolate enemy movement; this is not exhaustive play.
'use strict';
const fs=require('node:fs'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
let steps=0,room=0,draws=0;const counts=new Map();
m.onInstr=pc=>{
 if(pc===s.ps_find&&m.rd(s.sp_k)>=2){
  const nm=m.rd(s.sp_name)&252,shift=m.rd(s.sp_x)&7;
  if(!counts.has(nm))counts.set(nm,Array(8).fill(0));counts.get(nm)[shift]++;draws++;
 }
 if(pc!==s.L_A5D1)return;steps++;
 if(steps<50)return;
 m.wr(0x7049,255);m.wr(0x705f,m.rd(0x705f)&~4);m.wr(0x7068,0xfe);
 m.wr(0x7303,0);m.wr(0x7307,0);
 if(steps>=50&&(steps-50)%128===0){
  room++;if(room>98)return;
  if(room%10===0)console.error('profile room',room,'steps',steps);
  m.wr(0x71a6,1);m.wr(0x71a7,0);m.wr(0x71a8,room+8);
  for(let a=0x70c0;a<0x7186;a++)m.wr(a,0);
  const c=m.cpu;c.sp-=2;m.wr(c.sp,pc&255);m.wr(c.sp+1,pc>>8);c.pc=s.L_A067;
 }else{
  // Enemy update normally runs inside the disabled hero procedure.
  m.wr(0x70ab,(m.rd(0x70ab)+3)&3);
  const c=m.cpu,ret=pc+3;c.sp-=2;m.wr(c.sp,ret&255);m.wr(c.sp+1,ret>>8);c.pc=s.L_A7A1;
 }
};
for(let frame=0;room<=98&&frame<40000;frame++){
 if(frame===10)m.keyboard.matrix[2]|=2;if(frame===100)m.keyboard.matrix[2]&=~2;m.frame();
}
const result={B,rooms:Math.min(room-1,98),steps,draws,poses:[...counts].sort((a,b)=>a[0]-b[0]).map(([nm,histogram])=>({name:nm.toString(16).toUpperCase().padStart(2,'0'),shifts:histogram.map((n,k)=>n?k:-1).filter(n=>n>=0),histogram}))};
console.log(JSON.stringify(result));if(process.env.OUT)fs.writeFileSync(process.env.OUT,JSON.stringify(result,null,2));
