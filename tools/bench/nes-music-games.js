// Музыка: в уровне тишина (пирамиды нет), сокровищница играет по кругу, заставка играет до выбора уровня.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/quick',s=symbols(B),m=E.mk(B+'/monty.bin');
const w2=a=>m.rd(a)|m.rd(a+1)<<8;
const ptrs=[];
for(let f=0;f<60;f++)m.frame();
const title0=w2(s.nes_m_ptr);for(let f=0;f<100;f++)m.frame();
assert.notEqual(w2(s.nes_m_ptr),title0,'заставка играет');
for(let f=0;f<300;f++){if(f===10)m.keyboard.matrix[2]=2;if(f===60)m.keyboard.matrix[2]=0;m.frame();}
for(let f=0;f<200;f++)m.frame();
const p=w2(s.nes_m_ptr);for(let f=0;f<100;f++)m.frame();
assert.equal(w2(s.nes_m_ptr),p,'в уровне музыка не движется');
assert.equal(m.rd(s.nes_loop),0,'пустой одноразовый порядок');
// сокровищница
const c=m.cpu;c.sp-=2;m.wr(c.sp,c.pc&255);m.wr(c.sp+1,c.pc>>8);c.pc=s.nes_treasure;m.frame();
const t0=w2(s.nes_m_ptr);assert.equal(m.rd(s.nes_loop),1,'сокровищница по кругу');
for(let f=0;f<150;f++)m.frame();
assert.notEqual(w2(s.nes_m_ptr),t0,'сокровищница играет');
console.log(JSON.stringify({B,title:'plays',level:'silent',treasure:'plays, loops'}));
