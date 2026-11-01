// Сравнение состояния ОЗУ игры 7000..7FFF через 10 шагов после холодного старта и после GAME OVER + повторного старта (тот же уровень).
// B=build/nes-physics-checked node tools/bench/restart-diff.js [уровень 1..3]
'use strict';
const path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');
const lvl=+(process.argv[2]||1),bit=1<<lvl;
let steps=0,since=-1,restarts=0,snapA=null,snapB=null,forced=false,title=false;
const dump=()=>Array.from({length:0x1000},(_,i)=>m.rd(0x7000+i));
m.onInstr=pc=>{
 if(pc===s.go1&&forced)m.keyboard.matrix[7]|=128;
 if(pc===s.title_warm_menu&&!title){title=true;m.keyboard.matrix[7]&=~128;m.keyboard.matrix[2]|=bit;}
 if(pc===s.warm_restart){restarts++;}
 if(pc===s.L_A5D1){
  steps++;
  if(!forced&&steps===10)snapA=dump();
  if(!forced&&steps===300){forced=true;m.wr(0x70C0,255);m.wr(0x7017,0x45);m.cpu.sp=s.GSTACK;m.cpu.pc=s.game_over;}
  if(forced&&restarts){since++;m.keyboard.matrix[2]=0;if(since===10){snapB=dump();}}
 }
};
for(let f=0;!snapB&&f<8000;f++){if(f===10)m.keyboard.matrix[2]|=bit;if(f===100&&!forced)m.keyboard.matrix[2]&=~bit;m.frame();}
if(!snapB){console.log('нет второго снимка',{steps,restarts,forced,title});process.exit(1);}
const d=[];for(let i=0;i<0x1000;i++)if(snapA[i]!==snapB[i])d.push((0x7000+i).toString(16)+':'+snapA[i].toString(16)+'->'+snapB[i].toString(16));
console.log('различий',d.length);console.log(d.join(' '));
