// Boot, cross from the right room, walk to the rope cap, then descend.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
const baseline=m.memory.bytes.slice();
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.sp=0x73be;c.pc=s[name];m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');if(c.pc===s.L_8C13)c.pc=s.L_A067;c.instruction();}}
let cases=0;
for(const target of [198,199,200,201,202,203,204,205,206,207]){
 m.memory.bytes.set(baseline);
 m.wr(0x71a7,1);m.wr(0x71a8,10);m.wr(0x705f,0);m.wr(s.nes_q_idle,1);
 for(let a=0x70c0;a<0x7186;a++)m.wr(a,255);
 call('L_A067');
 m.wr(0x7300,92);m.wr(0x7304,95);
 m.wr(0x7301,18+(target&1));m.wr(0x7305,18+(target&1));
 m.wr(0x7079,0);m.wr(0x7076,0);m.wr(0x7077,0);m.wr(0x707c,92);
 for(let n=0;n<60;n++){
  if(m.rd(0x71a8)===9&&m.rd(0x7305)===target)break;
  m.wr(s.kbmat,0x10);call('L_88D1');
 }
 assert.equal(m.rd(0x71a8),9,'crossed from right room');
 assert.equal(m.rd(0x7305),target,'reached cap from the right');
 assert.equal(m.rd(0x7304),95,'still on upper ledge');
 for(let n=0;n<45;n++){
  m.wr(s.kbmat,0x80);call('L_88D1');
  assert.equal(m.rd(0x7079),4,`rope lost at X=${target}, step=${n}`);
  assert.equal(m.rd(0x7305),196,`not centred on rope at X=${target}, step=${n}`);
 }
 assert.equal(m.rd(0x7304),140,'descended at rope speed');cases++;
}
// Standing farther along the brick ledge must not engage a nearby rope.
let ledgeControls=0;
for(let x=208;x<216;x++){
 m.wr(0x7300,92);m.wr(0x7304,95);m.wr(0x7301,x);m.wr(0x7305,x);
 m.wr(0x7079,0);m.wr(0x7076,0);m.wr(0x7077,0);
 for(let n=0;n<16;n++){
  m.wr(s.kbmat,0x80);call('L_88D1');
  assert.deepEqual([m.rd(0x7305),m.rd(0x7304),m.rd(0x7079)],[x,95,0],'Down through solid ledge at '+x);
 }
 ledgeControls++;
}
console.log(JSON.stringify({B,cases,ledgeControls,route:'1,10 -> 1,9 -> right rope',approachX:'198..207',ropeX:196,fall:false}));
