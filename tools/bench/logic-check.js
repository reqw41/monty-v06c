#!/usr/bin/env node
// Differential machine-code checks, including coordinates absent from game tours.
'use strict';
const path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const dirs=[process.argv[2]||'build/logic-before',process.argv[3]||'build/native'];
const machines=dirs.map(d=>({m:E.mk(d+'/monty.bin'),s:symbols(d)}));
function call(o,label,a,b=0,c=0) {
  const {m,s}=o,R=m.cpu.regs;R.fill(0);R[7]=a;R[0]=b;R[1]=c;R[4]=0x70;R[5]=0x57;
  m.cpu.iff=false;m.cpu.sp=0x73be;m.wr(0x73be,s.unit_trap&255);m.wr(0x73bf,s.unit_trap>>8);m.cpu.pc=s[label];
  for(let n=0;m.cpu.pc!==s.unit_trap;n++){if(n>20000)throw Error('no return '+label);m.cpu.instruction();}
  return {a:R[7],bc:R[0]*256+R[1],de:R[2]*256+R[3],hl:R[4]*256+R[5],z:!!(m.cpu.store_flags()&64)};
}
for(const label of ['L_A894','it_is'])for(let a=0;a<256;a++) {
  const results=machines.map(o=>call(o,label,a,0x12,0x34));
  for(const k of ['a','bc','hl','z'])if(results[0][k]!==results[1][k])throw Error(`${label} ${a} ${k}`);
}
for(const {m,s} of machines)for(let a=0;a<768;a++)m.wr(s.VNT+a,(a*13+(a>>8))&255);
let count=0;
for(let y=0;y<256;y++)for(let x=0;x<256;x++) {
  const nested=(x+y)%3===0?0:(x+y)%3===1?1:255,flags=(x^y)&255;
  const out=machines.map(o=>{
    const {m}=o;m.wr(0x7084,y);m.wr(0x7085,x);m.wr(0x70AF,nested);m.wr(0x705F,flags);
    const regs=call(o,'L_916C',0,0x12,2);
    return JSON.stringify([regs.bc,regs.de,regs.hl,...[0x71B0,0x71B1,0x70AF,0x705F,0x7057,0x7058,0x7059,0x705A,0x705B,0x705C].map(a=>m.rd(a))]);
  });
  if(out[0]!==out[1])throw Error(`tiles Y=${y} X=${x}: ${out}`);count++;
}
console.log('256 tiles/class; '+count+' coordinate pairs, including nested read flags: identical');
