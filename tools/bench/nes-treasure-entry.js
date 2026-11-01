// First bonus transition preserves the player's manual jump and original NES field.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]=2;if(f===100)m.keyboard.matrix[2]=0;m.frame();}
const base=m.memory.bytes.slice(),reference=JSON.parse(fs.readFileSync('build/nes-treasure/reference.json'));let cases=0;
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');c.instruction();}}
for(const r of reference.filter(q=>q.seed&1))for(const direction of [-2,2]){
 m.memory.bytes.set(base);for(let i=192;i<960;i++)m.wr(s.VNT+i,0);
 for(let a=0x7057;a<=0x705c;a++)m.wr(a,0);m.wr(s.nes_q_idle,1);
 for(const [a,v]of[[0x71a6,r.level],[0x71a7,8],[0x71a8,10],[0x705f,0],[0x7079,2],[0x7072,0],[0x7300,219],[0x7304,222],[0x7301,116-direction],[0x7305,116-direction],[0x7076,direction&255],[0x7077,4],[0x7078,direction&255],[0x7047,r.seed&255],[0x7048,r.seed>>8]])m.wr(a,v);
 call('L_8DE8');assert.equal(m.rd(0x71a7),9);assert(m.rd(0x705f)&32,'real bonus entry');
 const hero=Array.from({length:8},(_,i)=>m.rd(0x7300+i)),motion=Array.from({length:4},(_,i)=>m.rd(0x7076+i));
 assert.deepEqual([m.rd(0x7305),m.rd(0x7304)],[116,44]);
 call('L_A60B');
 assert.deepEqual(Array.from({length:768},(_,i)=>m.rd(s.FIELD_VNT+i)),r.cells,'first bonus field must remain original NES');
 assert.deepEqual(Array.from({length:8},(_,i)=>m.rd(0x7300+i)),hero,'no platform teleport');
 assert.deepEqual(Array.from({length:4},(_,i)=>m.rd(0x7076+i)),motion,'manual jump direction survives entry');
 m.keyboard.matrix[0]=m.keyboard.matrix[7]=0;call('L_8C1F');assert.equal(m.rd(0x73ee),128,'no injected direction or jump');cases++;
}
console.log(JSON.stringify({B,cases,levels:9,firstBonusField:'original NES',entry:'manual jump',hero:'no teleport',automaticInput:false}));
