// Какая доля вызовов joe_put приходится на «чёрный» фон под прямоугольником Джо (плоскости A000/C000 нулевые после восстановления)?
// Это условие быстрой записи «замещением на месте» (как в Atic Atac). B=build/quick node tools/bench/joe-black.js [зерно] [часть из 9]
'use strict';
const path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/quick',s=symbols(B),m=E.mk(B+'/monty.bin');
const seed=+(process.argv[2]||1),part=+(process.argv[3]||0),parts=9;
const ROOMS=[];for(let r=0;r<9;r++)for(let c=8-r;c<=10+r;c++)ROOMS.push([r,c]);
const my=ROOMS.filter((_,i)=>i%parts===part);
let x=seed*7919+part;const rnd=n=>{x=(x*1103515245+12345)&0x7fffffff;return x%n;};
const KEYS={left:[0,0x10],up:[0,0x20],right:[0,0x40],down:[0,0x80],space:[7,0x80]};
let steps=0,ri=0,puts=0,black=0,blackC=0,cool=0;const st={};
m.onInstr=pc=>{
 if(pc===s.draw_all||pc===s.L_A067)cool=60;
 if(pc===s.L_8DA2&&steps>60){const c=m.cpu;c.pc=m.rd(c.sp)|m.rd(c.sp+1)<<8;c.sp+=2;return;}
 if(pc===s.joe_put&&cool===0&&m.rd(0x7079)<8){
  const c0=m.rd(s.spr_rec+7),c1=m.rd(s.spr_rec+8),top=m.rd(s.spr_rec+9),rows=m.rd(s.jn_rows_count)||23;
  let a=0,c=0;
  for(let col=c0;col<=c1&&col<32;col++)for(let r=0;r<rows;r++){const row=(top-r)&0xFF;a|=m.rd(0xA000+col*256+row);c|=m.rd(0xC000+col*256+row);}
  puts++;if(!a&&!c)black++;if(!a&&!c){const k=m.rd(0x71A7)+','+m.rd(0x71A8);st[k]=(st[k]||0)+1;}
 }
 if(pc!==s.L_A5D1)return;steps++;if(cool>0)cool--;m.wr(0x7049,6);
 if(s.nes_amulet_ticks){m.wr(s.nes_amulet_ticks,200);m.wr(s.nes_amulet_ticks+1,0);}
 if(steps>=300&&(steps-300)%300===0&&ri<my.length){const [r,c]=my[ri++];m.wr(0x71A7,r);m.wr(0x71A8,c);m.wr(0x7079,9);}
 if(steps>200&&steps%(4+rnd(10))===0){for(const k in KEYS){const e=KEYS[k];if(rnd(3)===0)m.keyboard.matrix[e[0]]|=e[1];else m.keyboard.matrix[e[0]]&=~e[1];}}
};
const N=300+300*my.length;
for(let f=0;steps<N&&f<N*4;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
console.log(JSON.stringify({seed,part,rooms:my.length,puts,black,share:+(black/puts).toFixed(3)}));
