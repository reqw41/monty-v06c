// Pickup sound (effect 2): on in the main game, off in the treasure room.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]=2;if(f===100)m.keyboard.matrix[2]=0;m.frame();}
const base=m.memory.bytes.slice();let effects=[];
function call(name,a){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;c.regs[7]=a;c.regs[0]=c.regs[1]=0;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');if(c.pc===s.L_AC1A)effects.push(c.regs[7]);c.instruction();}}
// Подбор: драгоценность и обычный предмет звучат в основной игре; в сокровищнице (705F бит 5) звук 2 глушится.
for(const [item,bonus] of [[0x44,0],[0x40,0],[0x44,32]]){
 m.memory.bytes.set(base);effects=[];m.wr(0x705f,bonus);
 for(let a=0x71b2;a<0x71b9;a++)m.wr(a,255);for(let a=0x7017;a<=0x7019;a++)m.wr(a,0);
 m.wr(0x71b0,0x80);m.wr(0x71b1,1);m.wr(s.nes_p_wait,0);m.wr(s.nes_q_idle,1);
 call('L_901B',item);
 const silent=!!bonus;
 assert.equal(m.rd(s.nes_p_wait),silent?0:1,`item ${item.toString(16)} bonus=${bonus}: pickup sound ${silent?'silent':'plays'}`);
 if(item===0x44)assert.equal(m.rd(0x7018),0x10,'jewel still gives 1000 points');
 else assert.equal(m.rd(0x71b2),item,'ordinary item still collected');
}
console.log(JSON.stringify({B,mainGame:'jewel and item sound on',treasureRoom:'pickup silent',jewelPoints:1000}));
