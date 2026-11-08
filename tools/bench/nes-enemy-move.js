// Замещение врагов (en_move): покадровая сверка экрана (framecheck) при ходьбе Джо в комнатах, где катящиеся
// черепа и пауки переходят через границу байта; и что en_move вообще срабатывает.
// B=build/<каталог> node tools/bench/nes-enemy-move.js
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/quick',s=symbols(B);
let moves=0,checks=0;
for(const [R,C] of [[3,6],[8,6],[1,8],[6,4],[0,10],[8,1]]){
 const m=E.mk(B+'/monty.bin'),checker=require('./framecheck')(m,s);let steps=0,on=false;
 m.onInstr=pc=>{checker.instruction(pc);if(on&&pc===s.en_move)moves++;
  if(pc!==s.L_A5D1)return;steps++;m.wr(0x7049,6);
  if(steps===50){m.wr(0x71A7,R);m.wr(0x71A8,C);m.wr(0x7079,9);m.wr(0x70B1,m.rd(0x70B1)|16);}
  if(steps===160)on=true;
  if(on){const ph=Math.floor((steps-160)/30)%2;m.keyboard.matrix[0]=(m.keyboard.matrix[0]&~0x50)|(ph?0x10:0x40);}};
 for(let f=0;f<900;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
 const r=checker.result();checks+=r.checks||0;
 assert.equal(r.bad,0,`framecheck ${R},${C}: `+JSON.stringify(r.examples.slice(0,2)));
}
assert(moves>50,'en_move срабатывает: '+moves);
console.log(JSON.stringify({moves,checks}));
