// Плавность врагов при ходьбе Джо: интервалы между выводами каждого видимого врага (в кадрах) и скачок по x за вывод.
// B=build/quick ROOM=1,9 N=700 node tools/bench/enemy-smooth.js
'use strict';
const path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/quick',s=symbols(B),m=E.mk(B+'/monty.bin');
const [R,C]=(process.env.ROOM||'1,9').split(',').map(Number),N=+(process.env.N||700);
const obj=k=>0x7300+4*m.rd(0x72E0+k);
let joePuts=0,steps=0,cool=0,fr=0,on=false,f0=0,moved=0,lastX=-1;const last={},gaps={},jumps={},puts={};
m.onInstr=pc=>{
 if(pc===s.draw_all||pc===s.L_A067)cool=60;
 if(pc===s.L_8DA2&&steps>60){const c=m.cpu;c.pc=m.rd(c.sp)|m.rd(c.sp+1)<<8;c.sp+=2;return;}
 if(on&&pc===s.joe_put&&cool===0)joePuts++;
 if(on&&pc===s.spr_put&&cool===0){const k=m.rd(s.sp_k);if(k>=2){const p=obj(k),vis=m.rd(p)<192&&(m.rd(p+3)&15)&&![6,11].includes(m.rd(p+3)&15);if(vis){const r=s.spr_rec+16*k,x=m.rd(r+2);
  if(last[k]){const g=m.frames-last[k].f;(gaps[k]=gaps[k]||{})[g]=((gaps[k]||{})[g]||0)+1;const dx=Math.abs(x-last[k].x);if(dx<40)(jumps[k]=jumps[k]||{})[dx]=((jumps[k]||{})[dx]||0)+1;}
  last[k]={f:m.frames,x};puts[k]=(puts[k]||0)+1;}}}
 if(pc!==s.L_A5D1)return;steps++;m.wr(0x7049,6);if(s.nes_amulet_ticks){m.wr(s.nes_amulet_ticks,200);m.wr(s.nes_amulet_ticks+1,0);}
 if(cool>0)cool--;
 if(steps===50){m.wr(0x71A7,R);m.wr(0x71A8,C);m.wr(0x7079,9);}
 if(steps===160){on=true;f0=m.frames;}
 if(on&&steps>160){const ph=Math.floor((steps-160)/30)%2;m.keyboard.matrix[0]=(m.keyboard.matrix[0]&~0x50)|(ph?0x10:0x40);const x=m.rd(0x7305);if(lastX>=0&&x!==lastX)moved++;lastX=x;}
 if(on&&steps===160+N){on=false;done=true;}
};
let done=false;for(;!done&&fr<30000;fr++){if(fr===10)m.keyboard.matrix[2]|=2;if(fr===100)m.keyboard.matrix[2]&=~2;m.frame();}
const frames=m.frames-f0;
const stat=h=>{const t=Object.values(h).reduce((a,b)=>a+b,0);let sum=0;for(const g in h)sum+=g*h[g];return {mean:+(sum/t).toFixed(2),max:Math.max(...Object.keys(h).map(Number)),share_ge4:+(100*Object.entries(h).filter(([g])=>g>=4).reduce((a,[,v])=>a+v,0)/t).toFixed(0)};};
const out={room:R+','+C,sps:+(50*N/frames).toFixed(1),moved,joe_кадров_на_вывод:+(frames/Math.max(1,joePuts)).toFixed(2)};
for(const k in gaps){out['враг'+k]={выводов:puts[k],интервал:stat(gaps[k]),скачок_x_макс:Math.max(...Object.keys(jumps[k]||{0:1}).map(Number))};}
console.log(JSON.stringify(out));
