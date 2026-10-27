// Exclusive L=logic incl. frame handler, D=display preparation, I=IRQ, W=frame wait.
const fs=require('fs');process.chdir(require('path').resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols,profiler}=require('./logic-profile');
const B=process.env.B||'build/native',sym=symbols(B);
const labs=Object.entries(sym).filter(([k,v])=>v>=0x38&&v<0x7000&&!k.startsWith('C_')).sort((a,b)=>a[1]-b[1]);
const near=Array(0x10000).fill('?');let j=0;
for(let a=0x38;a<0x7000;a++){while(j+1<labs.length&&labs[j+1][1]<=a)j++;near[a]=labs[j]?.[0]||'?';}
const m=E.mk(B+'/monty.bin'),p=profiler(m,sym),T={L:{},D:{},I:{},W:{}};
let steps=0,last=0,ctx='L',start=null,end=null;
m.onInstr=pc=>{
  const next=p.instruction(pc);
  if(steps>=201&&steps<601)T[ctx][near[last]]=(T[ctx][near[last]]||0)+(m.cpu.vcycles||0);
  last=pc;ctx=next;
  if(pc===sym.L_8DA2&&steps>60){const c=m.cpu;c.pc=m.rd(c.sp)|m.rd(c.sp+1)<<8;c.sp+=2;return;}
  if(pc===sym.L_A5D1){
    steps++;if(steps===201)start={...p.totals};if(steps===601)end={...p.totals};
    m.wr(0x7049,6);m.wr(0x707C,m.rd(0x7300));
    if(steps===50){m.wr(0x705F,m.rd(0x705F)&~4);m.wr(0x71A7,(process.env.ROOM||"1,9").split(",").map(Number)[0]);m.wr(0x71A8,(process.env.ROOM||"1,9").split(",").map(Number)[1]);m.wr(0x7079,9);}
  }
};
for(let f=0;!end;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
for(const c of ['L','D','I','W'])console.log(c,Math.round((end[c]-start[c])/400),Object.entries(T[c]).sort((a,b)=>b[1]-a[1]).slice(0,22).map(([k,v])=>k+' '+Math.round(v/400)).join('  '));
