// Звуки шагов: ходьба (joe_footstep) и ступени лестницы (joe_clock, состояние 3/4) запускают тональный «тук» nes_step_stream (канал 1);
// упор в стену при ходьбе и стояние не звучат. B=build/quick node tools/bench/nes-step-sfx.js
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/quick',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<320;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.sp=0x73be;c.pc=s[name];m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');c.instruction();}}
const fired=()=>{const hit=m.rd(s.nes_p_ptr)|m.rd(s.nes_p_ptr+1)<<8;const f=hit===s.nes_step_stream&&m.rd(s.nes_p_wait)===1;m.wr(s.nes_p_wait,0);m.wr(s.nes_p_ptr,0);m.wr(s.nes_p_ptr+1,0);return f;};
function clock(state,dx,dy,n){let c=0;m.wr(0x7079,state);m.wr(0x7076,dx);m.wr(0x7077,dy);m.wr(s.jn_tick,0);m.wr(s.jn_walk,0);m.wr(s.nes_p_wait,0);for(let i=0;i<n;i++){call('joe_clock');if(fired())c++;}return c;}
const ladder=clock(3,0,1,32), ladderIdle=clock(3,0,0,32), walk=clock(1,2,0,48), stuck=clock(1,0,0,48), standing=clock(0,0,0,48);
assert.equal(ladder,0,'лестница: без звука');
assert.equal(ladderIdle,0,'на лестнице без движения тихо');
assert.equal(walk,4,'ходьба: щелчок на чётных фазах каждые 12 тиков');
assert.equal(stuck,0,'упор в стену (dX=0): тихо');
assert.equal(standing,0,'стоит: тихо');
// не перебивает идущий эффект канала 1 (прыжок, подбор, шест)
m.wr(s.nes_p_wait,5);m.wr(s.nes_p_ptr,0x34);m.wr(s.nes_p_ptr+1,0x12);call('nes_step_sfx');assert.equal(m.rd(s.nes_p_wait),5);assert.equal(m.rd(s.nes_p_ptr),0x34);
console.log(JSON.stringify({B,ladder,ladderIdle,walk,stuck,standing}));
