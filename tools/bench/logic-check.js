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
  return {a:R[7],bc:R[0]*256+R[1],de:R[2]*256+R[3],hl:R[4]*256+R[5],z:!!(m.cpu.store_flags()&64),cf:!!(m.cpu.store_flags()&1)};
}
for(const label of ['L_A894','it_is','L_913B'])for(let a=0;a<256;a++) {
  const results=machines.map(o=>call(o,label,a,0x12,0x34));
  for(const k of ['a','bc','hl','z'])if(results[0][k]!==results[1][k])throw Error(`${label} ${a} ${k}`);
}
for(let flags of [0,0x20,0x40,0x60,0xFF])for(let a=0;a<256;a++) {
  const results=machines.map(o=>{o.m.wr(0x7000,flags);return call(o,'L_9122',a,0x12,0x34);});
  for(const k of ['a','bc','hl','cf'])if(results[0][k]!==results[1][k])throw Error(`floor ${a} ${flags} ${k}`);
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

let seed=12345;const rnd=n=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed%n;};
for(let test=0;test<5000;test++) {
  const ram=Uint8Array.from({length:0x340},()=>rnd(256)),nt=Uint8Array.from({length:768},()=>rnd(256));
  const n=1+rnd(4);
  for(let i=0;i<n;i++){
    const kind=[8,16,64][rnd(3)];
    ram[0x86+2*i]=(i+2)|kind|(rnd(2)?0x80:0)|(kind===64&&rnd(3)===0?0x20:0);
    ram[0x87+2*i]=rnd(kind===8?4:kind===64?6:58)|(rnd(2)?0x80:0);
  }
  ram[0x86+2*n]=255;
  const out=machines.map(o=>{
    const {m,s}=o;ram.forEach((v,i)=>m.wr(0x7000+i,v));nt.forEach((v,i)=>m.wr(s.VNT+i,v));
    call(o,'L_A7A1',0);return Buffer.from(Array.from({length:0x340},(_,i)=>m.rd(0x7000+i)));
  });
  if(!out[0].equals(out[1]))throw Error(`enemy fixture ${test}: `+Array.from(out[0]).map((v,i)=>v===out[1][i]?'':(0x7000+i).toString(16)+':'+v+'/'+out[1][i]).filter(Boolean).join(' '));
}
console.log('5000 enemy fixtures: identical game RAM');
