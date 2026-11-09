// Execute the real coverage code over clipped rectangles, including page edges.
// B=build/<dir> node tools/bench/nes-cover-rect.js
'use strict';
const assert=require('assert/strict'),path=require('path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/quick',s=symbols(B),m=E.mk(B+'/monty.bin');
const cpu=m.cpu,trap=s.unit_trap;
function call(name,k){
 cpu.iff=false;cpu.iff_pending=0;cpu.pc=s[name];cpu.sp=0x73be;
 const regs=[k,0x53,0xa4,0x95,0x7f,0x61,0,0xd2];
 for(const i of [0,1,2,3,4,5,7])cpu.regs[i]=regs[i];
 const flags=cpu.store_flags();
 m.wr(cpu.sp,trap&255);m.wr(cpu.sp+1,trap>>8);
 for(let n=0;cpu.pc!==trap;n++){assert(n<10000,name+' did not return');cpu.instruction();}
 for(const i of [0,1,2,3,4,5,7])assert.equal(cpu.regs[i],regs[i],name+' preserves register '+i);
 assert.equal(cpu.store_flags(),flags,name+' preserves flags');
 assert.equal(cpu.sp,0x73c0);
}
let cases=0;
for(let row=0;row<s.SCREEN_ROWS;row++)for(let col=0;col<32;col++)
 for(const width of [1,2,3,4,32])for(const height of [1,2,3,4]){
  if(col+width>32||row+height>s.SCREEN_ROWS)continue;
  const k=cases%6,bit=2<<k,r=s.spr_rec+16*k,n=s.spr_new+16*k;
  for(const [a,v] of [[r+5,row],[r+6,row+height-1],[r+7,col],[r+8,col+width-1],[n,0],[s.cover_moves+k,1]])m.wr(a,v);
  const seed=cases&255;
  for(let i=-1;i<=s.NT_CELLS;i++)m.wr(s.PND+i,(i*37+seed)&255);
  for(const op of ['cover_set','cover_clear']){
   call(op,k);
   for(let i=-1;i<=s.NT_CELLS;i++){
    const y=Math.floor(i/32),x=i&31,inside=y>=row&&y<row+height&&x>=col&&x<col+width;
    const original=(i*37+seed)&255,want=inside?(op==='cover_set'?original|bit:original&~bit):original;
    assert.equal(m.rd(s.PND+i),want,`${op}: ${row},${col} ${width}x${height}, offset ${i}`);
   }
  }
  cases++;
 }
// An unchanged rectangle keeps its coverage; the following set is a no-op.
for(let k=0;k<6;k++){
 const r=s.spr_rec+16*k,n=s.spr_new+16*k;
 m.wr(n,1);for(let i=5;i<=8;i++){m.wr(r+i,i);m.wr(n+i,i);}
 m.wr(s.cover_moves+k,1);
 const before=Array.from({length:s.NT_CELLS},(_,i)=>m.rd(s.PND+i));
 call('cover_clear',k);assert.equal(m.rd(s.cover_moves+k),0);call('cover_set',k);
 assert.deepEqual(Array.from({length:s.NT_CELLS},(_,i)=>m.rd(s.PND+i)),before);
}
console.log(JSON.stringify({B,rectangles:cases,unchanged:6,registers:'preserved',coverage:'exact'}));
