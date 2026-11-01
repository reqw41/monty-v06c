// Щелчки шагов (BSR PC0 через out 00h значением 01) в разных ситуациях: стоит, идёт, упёрся в стену, на ленте.
// B=build/quick node tools/bench/footstep-clicks.js
'use strict';
const path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/quick',s=symbols(B);
function run(label,room,setup,keyFn,N=300){
 const m=E.mk(B+'/monty.bin');let steps=0,clicks=0,moved=0,lastX=-1,states={};
 m.outs=[];
 m.onInstr=pc=>{
  if(pc===s.L_8DA2&&steps>60){const c=m.cpu;c.pc=m.rd(c.sp)|m.rd(c.sp+1)<<8;c.sp+=2;return;}
  if(pc!==s.L_A5D1)return;steps++;m.wr(0x7049,6);if(s.nes_amulet_ticks){m.wr(s.nes_amulet_ticks,200);m.wr(s.nes_amulet_ticks+1,0);}
  if(steps===50){m.wr(0x71A7,room[0]);m.wr(0x71A8,room[1]);m.wr(0x7079,9);}
  if(steps===150){m.outs.length=0;}
  if(steps>150){keyFn(m,steps-150);const x=m.rd(0x7305);if(lastX>=0&&x!==lastX)moved++;lastX=x;states[m.rd(0x7079)]=(states[m.rd(0x7079)]||0)+1;}
  if(steps===150+N){const o=m.outs;for(let i=0;i<o.length;i+=2)if(o[i]===0&&o[i+1]===1)clicks++;done=true;}
 };
 let done=false;for(let f=0;!done&&f<5000;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
 console.log(label.padEnd(34),'щелчков',String(clicks).padStart(3),'за',N,'шагов; шагов со сдвигом x:',moved,'состояния',JSON.stringify(states));
}
const hold=(r,b)=>m=>{m.keyboard.matrix[r]|=b;};
run('стоит (комната 2,8)',[2,8],()=>{},()=>{});
run('идёт вправо (2,8)',[2,8],()=>{},m=>{m.keyboard.matrix[0]|=0x40;});
run('ходит влево-вправо (2,8)',[2,8],()=>{},(m,k)=>{const ph=Math.floor(k/30)%2;m.keyboard.matrix[0]=(m.keyboard.matrix[0]&~0x50)|(ph?0x10:0x40);});
// упёрся в стену: в комнате 2,8 идём вправо долго
run('вправо до упора (2,8) 300 шагов',[2,8],()=>{},m=>{m.keyboard.matrix[0]|=0x40;},300);
run('стоит на ленте (0,10)',[0,10],()=>{},()=>{});

// стена справа от Джо: клетки (ряды 10..13, столбец 18) — NES-стена (id 8) в карте VNT
run('упёрся в стену справа (2,8)',[2,8],null,(m,k)=>{m.keyboard.matrix[0]|=0x40;if(k<3||k%20===0)for(let r=10;r<=13;r++)m.wr(0x7B00+(r+2)*32+18,8);},300);
run('упёрся в стену слева (2,8)',[2,8],null,(m,k)=>{m.keyboard.matrix[0]|=0x10;if(k<3||k%20===0)for(let r=10;r<=13;r++)m.wr(0x7B00+(r+2)*32+12,8);},300);
