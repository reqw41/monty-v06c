// Бюджет кадра при ходьбе Джо: L логика, D подготовка вывода, I прерывание, W ожидание; по меткам внутри каждого контекста.
// B=build/quick ROOM=1,9 [KEYS=walk|idle] node tools/bench/walk-budget.js
const fs=require('fs');process.chdir(require('path').resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols,profiler}=require('./logic-profile');
const B=process.env.B||'build/quick',sym=symbols(B),mode=process.env.KEYS||'walk';
const labs=Object.entries(sym).filter(([k,v])=>v>=0x38&&v<0xFF00&&!k.startsWith('C_')).sort((a,b)=>a[1]-b[1]);
const near=Array(0x10000).fill('?');let j=0;
for(let a=0x38;a<0xFF00;a++){while(j+1<labs.length&&labs[j+1][1]<=a)j++;near[a]=labs[j]?.[0]||'?';}
const m=E.mk(B+'/monty.bin'),p=profiler(m,sym),T={L:{},D:{},I:{},W:{}};
const [R,C]=(process.env.ROOM||'1,9').split(',').map(Number);
let steps=0,last=0,ctx='L',start=null,end=null,f0=0,f1=0,fr=0;
m.onInstr=pc=>{
  const next=p.instruction(pc);
  if(start&&!end)T[ctx][near[last]]=(T[ctx][near[last]]||0)+(m.cpu.vcycles||0);
  last=pc;ctx=next;
  if(pc===sym.L_8DA2&&steps>60){const c=m.cpu;c.pc=m.rd(c.sp)|m.rd(c.sp+1)<<8;c.sp+=2;return;}
  if(pc===sym.L_A5D1){
    steps++;m.wr(0x7049,6);
    if(steps===50){m.wr(0x71A7,R);m.wr(0x71A8,C);m.wr(0x7079,9);}
    if(mode==='walk'&&steps>150){const ph=Math.floor((steps-150)/45)%2;m.keyboard.matrix[0]=(m.keyboard.matrix[0]&~0x50)|(ph?0x10:0x40);}
    if(steps===201){start={...p.totals};f0=fr;}
    if(steps===601){end={...p.totals};f1=fr;}
  }
};
for(;!end&&fr<20000;fr++){if(fr===10)m.keyboard.matrix[2]|=2;if(fr===100)m.keyboard.matrix[2]&=~2;m.frame();}
const frames=f1-f0,F=59904;
console.log(`room ${R},${C} ${mode}: ${frames} кадров на 400 шагов = ${(50*400/frames).toFixed(1)} шагов/с`);
for(const c of ['L','D','I','W']){const tot=end[c]-start[c];console.log(c,Math.round(tot/frames),'тактов/кадр =',(100*tot/frames/F).toFixed(0)+'%   ',Object.entries(T[c]).sort((a,b)=>b[1]-a[1]).slice(0,14).map(([k,v])=>k+' '+Math.round(v/frames)).join('  '));}
