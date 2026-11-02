// NES $A50B: при гибели от змеи (враг типа 1) на уровнях 1–4 ($0799 < 4, нумерация с 0) объект снимается и не возвращается
// при повторном входе; на уровне 5+ остаётся. Гибель — настоящая (с анимацией и возрождением в комнате 1,7).
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/quick',s=symbols(B);const out={};
for(const [lv,removed] of [[1,true],[4,true],[5,false]]){
 const m=E.mk(B+'/monty.bin');let steps=0,deaths=0,before=-1,after=-1,again=-1;
 const snakes=()=>{let n=0;for(let r=0;r<30;r++)for(let c=0;c<32;c++){const t=m.rd(s.VNT+r*32+c);if(t>=0xA0&&t<0xA8)n++;}return n;};
 m.onInstr=pc=>{if(pc===s.L_8DA2&&steps>60)deaths++;
  if(pc===s.L_A5D1){steps++;if(steps<130)m.wr(0x7049,6);if(steps===50){m.wr(0x71A6,lv);m.wr(0x71A7,1);m.wr(0x71A8,7);m.wr(0x7079,9);}
   if(steps===120){before=snakes();let sx=-1,sy=-1;for(let r=0;r<30&&sx<0;r++)for(let c=0;c<32;c++){const t=m.rd(s.VNT+r*32+c);if(t===0xA0||t===0xA5){sx=c*8;sy=r*8;break;}}
    m.wr(0x7305,sx);m.wr(0x7301,sx);m.wr(0x7304,sy-1);m.wr(0x7300,sy-4);m.wr(0x7079,0);}
   if(steps===300){after=snakes();m.wr(0x71A7,1);m.wr(0x71A8,8);m.wr(0x7079,9);}      // уйти в соседнюю комнату
   if(steps===360){m.wr(0x71A7,1);m.wr(0x71A8,7);m.wr(0x7079,9);}                     // и вернуться
   if(steps===420)again=snakes();}};
 for(let f=0;f<1200;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
 assert(before>0,'в 1,7 есть змея');assert(deaths>0,'Джо погиб на змее');
 assert.equal(after===0,removed,`уровень ${lv}: после гибели змея ${removed?'снята':'остаётся'} (клеток ${after})`);
 assert.equal(again===0,removed,`уровень ${lv}: после повторного входа (клеток ${again})`);
 out['level'+lv]={before,after,again};
}
console.log(JSON.stringify({B,rule:'NES $A50B: removed on levels 1-4',...out}));
