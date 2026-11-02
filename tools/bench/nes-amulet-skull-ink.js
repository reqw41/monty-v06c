// Череп при амулете рисуется в плоскости 8000 (зелёный слот 4, мигает вместе со змеями и пауками),
// без амулета — в C000 (белый); восстановление фона берёт плоскость из записи спрайта (+14).
// Комната 0,10 с катящимся черепом; амулет выдаётся на кадре 500 на 150 шагов. Каждая завершённая crit
// сверяется framecheck (фон под черепом должен быть цел до, во время и после амулета).
// B=build/quick node tools/bench/nes-amulet-skull-ink.js
'use strict';
const assert=require('assert/strict'),path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/quick',s=symbols(B);
const m=E.mk(B+'/monty.bin'),checker=require('./framecheck')(m,s);
m.onInstr=pc=>checker.instruction(pc);
const ticks=()=>m.rd(s.nes_amulet_ticks)|m.rd(s.nes_amulet_ticks+1)<<8;
const skull=()=>{for(let k=1;k<6;k++){const r=s.spr_rec+16*k;const nm=m.rd(r+3)-0x2C;if(m.rd(r)&&!(nm>=0&&nm<8))return {k,v:m.rd(r+14),top:(m.rd(r+1)+1)&255,x:m.rd(r+2)};}return null;};
// есть ли точки спрайта в плоскости: столбцы x>>3 .. +2, строки top..top+15 (экранные, поле 240 строк)
const ink=(plane,sk)=>{let n=0;for(let c=sk.x>>3;c<=(sk.x>>3)+2&&c<32;c++)for(let y=sk.top;y<sk.top+16;y++){const raw=0xDF-y-(y<48?8:16);if(m.rd(plane+c*256+(raw&255)))n++;}return n;};
let during=0,after=0,expiredAt=-1;
for(let f=0;f<1100;f++){
 if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;
 if(f===500){m.wr(0x71b2,0x53);m.wr(s.nes_amulet_ticks,150);m.wr(s.nes_amulet_ticks+1,0);}
 m.frame();
 if(f>500&&expiredAt<0&&ticks()===0)expiredAt=f;
 if(f>=540&&f<=620&&f%20===0){
  assert(ticks()>0,'amulet still active');
  const sk=skull();assert(sk,'skull drawn');
  assert.equal(sk.v,0x82,'skull marked for plane 8000 under the amulet');
  assert(ink(0x8000,sk)>0,'skull pixels present in 8000');
  during++;
 }
 if(f>=440&&f<500&&f%20===0){const sk=skull();assert(sk,'skull drawn before');assert.equal(sk.v,2,'skull in C000 before the amulet');assert(ink(0xC000,sk)>0,'skull pixels present in C000');}
 if(expiredAt>0&&f>=expiredAt+60&&f%25===0){const sk=skull();assert(sk,'skull drawn after');assert.equal(sk.v,2,'skull back in C000');assert.equal(m.rd(0x71b2),255,'amulet left the inventory');after++;}
}
const r=checker.result();
assert(during>=4&&after>=4,`during ${during} after ${after}`);
assert.equal(r.bad,0,'framecheck: '+JSON.stringify(r.examples.slice(0,3)));
console.log(JSON.stringify({B,during,after,expiredAt,frameChecks:r.checks}));
