// Столкновения как в NES ($A47D): змея (тайл) и движущийся враг — пересечение прямоугольников метаспрайтов.
// Сплошная сверка смерти в игре с формулой по сдвигам Джо относительно врага. B=build/quick node tools/bench/nes-hit-boxes.js
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/quick',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<330;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}   // загрузка: код столкновений перенесён
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.sp=0x73be;c.pc=s[name];m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<2000000,name+' hung');c.instruction();}}
function room(col){m.wr(0x71a6,1);m.wr(0x71a7,0);m.wr(0x71a8,col);m.wr(0x7049,6);m.wr(0x7079,0);m.wr(0x704a,0);m.wr(0x70b3,0);m.wr(s.nes_q_idle,1);
 m.wr(s.nes_amulet_ticks,0);m.wr(s.nes_amulet_ticks+1,0);
 for(let i=0;i<198;i++)m.wr(0x70c0+i,0);for(let i=0;i<7;i++)m.wr(0x71b2+i,255);
 for(let i=0;i<8;i++)m.wr(0x7300+i,[75,120,52,6,78,120,152,11][i]);for(let i=0x7308;i<0x7329;i++)m.wr(i,0);call('L_A067');}
const box=[0,2,14];  // стоящий Джо (NES idle)
const hit=(L,R,T,Bt,jx,jy)=>{const JL=jx+box[0],JR=jx+box[2],JT=jy-7+box[1],JB=jy+17;return L<JR&&R>=JL&&T<JB&&Bt>=JT;};
// змея
room(9);let sx=-1,sy=-1;for(let r=6;r<32&&sx<0;r++)for(let c=0;c<32;c++){const t=m.rd(s.VNT+r*32+c);if(t===0xA0||t===0xA5){sx=c*8;sy=r*8;break;}}
assert(sx>=0,'snake in 0,9');const base=m.memory.bytes.slice();let snakeCases=0,snakeHits=0;
for(let dy=-30;dy<=12;dy++)for(let dx=-16;dx<=16;dx++){
 m.memory.bytes.set(base);const jx=sx+dx,jy=sy+16-17+dy;
 for(const p of [0x7300,0x7304]){m.wr(p+1,jx);}m.wr(0x7304,jy);m.wr(0x7300,jy-3);m.wr(s.nphys_box_left,box[0]);m.wr(s.nphys_box_top,box[1]);m.wr(s.nphys_box_right,box[2]);
 call('L_8F5F');const dead=m.rd(0x7079)===8,want=hit(sx+3,sx+13,sy+9,sy+16,jx,jy);
 assert.equal(dead,want,`snake dx=${dx} dy=${dy}`);snakeCases++;if(dead)snakeHits++;}
// движущийся враг (череп/паук, [1,7,15,16])
room(10);const eb=m.memory.bytes.slice();let enemyCases=0,enemyHits=0;
for(let dy=-26;dy<=12;dy+=2)for(let dx=-18;dx<=18;dx++){
 m.memory.bytes.set(eb);m.wr(0x71b2,255);const jx=120,jy=94;m.wr(0x7305,jx);m.wr(0x7304,jy);m.wr(0x7301,jx);m.wr(0x7300,jy-3);
 m.wr(s.nphys_box_left,box[0]);m.wr(s.nphys_box_top,box[1]);m.wr(s.nphys_box_right,box[2]);
 const ex=jx+dx,ey=jy+dy;m.wr(0x7308,ey);m.wr(0x7309,ex);
 call('L_91E5');const dead=m.rd(0x7049)===5,want=hit(ex+1,ex+15,ey+8,ey+17,jx,jy);
 assert.equal(dead,want,`enemy dx=${dx} dy=${dy}`);enemyCases++;if(dead)enemyHits++;}
console.log(JSON.stringify({B,snakeCases,snakeHits,enemyCases,enemyHits,rule:'NES $A47D boxes'}));
