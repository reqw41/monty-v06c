// Boot the complete game: sprite-cache setup must not overwrite rope code.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/native',s=symbols(B),rom=fs.readFileSync(B+'/monty.bin'),m=E.mk(B+'/monty.bin');
for(let f=0;f<320;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
assert.deepEqual([m.rd(0x71a8),m.rd(0x7304),m.rd(0x7305),m.rd(0x7079)],[10,95,120,0]);
for(let i=0;i<s.nes_chain_descent_end-s.nes_chain_enter;i++)
 assert.equal(m.rd(s.nes_chain_enter+i),rom[s.nes_chain_enter+i],`rope code overwritten at ${i}`);
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.sp=0x73be;c.pc=s[name];m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');c.instruction();}}
for(let i=0;i<20;i++){m.wr(s.kbmat,0x80);call('L_9156');call('L_88D1');}
assert.equal(m.rd(0x7079),3,'Down enters the central ladder');
assert(m.rd(0x7304)>=115,'Joe descends after taking the ladder');
const bottom=m.rd(0x7304);
for(let i=0;i<10;i++){m.wr(s.kbmat,0x20);call('L_9156');call('L_88D1');}
assert(m.rd(0x7304)<bottom,`Up climbs the ladder (down ${bottom}, up ${m.rd(0x7304)}, state ${m.rd(0x7079)})`);
console.log(JSON.stringify({B,room:'0,10',downY:bottom,upY:m.rd(0x7304),state:m.rd(0x7079),ropeCode:s.nes_chain_enter}));
