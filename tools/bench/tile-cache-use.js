// Загрузка кэша тайлов (tile_count до TILE_CAP) по комнатам: максимум и число сбросов (tiles_reset). B=build/quick LV=1
'use strict';
const path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/quick',s=symbols(B),m=E.mk(B+'/monty.bin');
const ROOMS=[];for(let r=0;r<9;r++)for(let c=8-r;c<=10+r;c++)ROOMS.push([r,c]);
let steps=0,ri=0,resets=0,max=0,perRoom=[],cur=0,curR=0;
m.onInstr=pc=>{
 if(pc===s.tiles_reset){resets++;curR++;}
 if(pc!==s.L_A5D1)return;steps++;m.wr(0x7049,6);if(s.nes_amulet_ticks){m.wr(s.nes_amulet_ticks,200);m.wr(s.nes_amulet_ticks+1,0);}
 const tc=m.rd(s.tile_count);if(tc>cur)cur=tc;
 if(steps>=100&&(steps-100)%90===0){ if(ri>0)perRoom.push([ROOMS[ri-1].join(','),cur,curR]);cur=0;curR=0;
  if(ri<ROOMS.length){const [r,c]=ROOMS[ri++];m.wr(0x71A7,r);m.wr(0x71A8,c);m.wr(0x7079,9);}}
};
const N=100+90*ROOMS.length;
for(let f=0;steps<N&&f<N*4;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
perRoom.sort((a,b)=>b[1]-a[1]);
const hist={};for(const [,c] of perRoom){const k=Math.floor(c/10)*10;hist[k]=(hist[k]||0)+1;}
console.log('комнат',perRoom.length,'сбросов всего',resets,'максимум tile_count',perRoom[0][1],'; гистограмма по 10:',JSON.stringify(hist));
console.log('наибольшие:',perRoom.slice(0,8).map(x=>x.join(':')).join('  '));
