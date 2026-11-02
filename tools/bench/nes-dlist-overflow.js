// Переполнение списка изменённых клеток (dl_ovf): вывод по всем строкам даёт тот же экран, что и обычный путь.
// Переполнение принудительно каждые 5 шагов при ходьбе в 1,9 и 2,8; каждая завершённая crit сверяется framecheck.
// B=build/quick node tools/bench/nes-dlist-overflow.js
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/quick',s=symbols(B);
let total=0,bad=0,forced=0;
for(const [R,C] of [[1,9],[2,8],[0,10]]){
 const m=E.mk(B+'/monty.bin'),checker=require('./framecheck')(m,s);let steps=0;
 m.onInstr=pc=>{checker.instruction(pc);
  if(pc===s.L_8DA2&&steps>60){const c=m.cpu;c.pc=m.rd(c.sp)|m.rd(c.sp+1)<<8;c.sp+=2;return;}
  if(pc===s.L_A5D1){steps++;m.wr(0x7049,6);if(steps===50){m.wr(0x71A7,R);m.wr(0x71A8,C);m.wr(0x7079,9);}
   if(steps>120){const ph=Math.floor(steps/30)%2;m.keyboard.matrix[0]=(m.keyboard.matrix[0]&~0x50)|(ph?0x10:0x40);if(steps%5===0){m.wr(s.dl_ovf,1);forced++;}}}};
 for(let f=0;f<900;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
 const q=checker.result();total+=q.checks;bad+=q.bad;if(q.bad)console.log(R+','+C,JSON.stringify(q.examples.slice(0,2)).slice(0,300));
}
assert(total>100,'мало проверок');assert.equal(bad,0,'экран после переполнения списка расходится с эталоном');
console.log(JSON.stringify({B,checks:total,bad,forcedOverflows:forced}));
