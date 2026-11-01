// Гистограмма тактов по меткам внутри диапазона адресов (от метки A до метки B), на шаг. ROOM, KEYS как у walk-cost.
// B=build/qd2 QDBASE=build/quick FROM=spr_plan TO=spl_done node tools/bench/pc-hist.js
const path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols,profiler}=require('./logic-profile');
const B=process.env.B||'build/quick',sym=symbols(B),mode=process.env.KEYS||'idle';
const lo=sym[process.env.FROM],hi=sym[process.env.TO];
const labs=Object.entries(sym).filter(([k,v])=>v>=lo&&v<=hi&&!k.startsWith('C_')).sort((a,b)=>a[1]-b[1]);
const near=a=>{let n=labs[0][0];for(const [k,v] of labs){if(v>a)break;n=k;}return n;};
const m=E.mk(B+'/monty.bin');if(process.env.QDBASE)require('./qd-fill').fill(m,process.env.QDBASE);
const [R,C]=(process.env.ROOM||'2,8').split(',').map(Number);
let steps=0,last=0,on=false,n=0;const h={};let total=0;
m.onInstr=pc=>{
 if(on&&last>=lo&&last<=hi){const k=near(last);const e=m.cpu.vcycles||0;h[k]=(h[k]||0)+e;total+=e;}
 last=pc;
 if(pc===sym.L_8DA2&&steps>60){const c=m.cpu;c.pc=m.rd(c.sp)|m.rd(c.sp+1)<<8;c.sp+=2;return;}
 if(pc===sym.L_A5D1){steps++;m.wr(0x7049,6);if(sym.nes_amulet_ticks){m.wr(sym.nes_amulet_ticks,200);m.wr(sym.nes_amulet_ticks+1,0);}
  if(steps===50){m.wr(0x71A7,R);m.wr(0x71A8,C);m.wr(0x7079,9);}
  if(mode==='walk'&&steps>150){const ph=Math.floor((steps-150)/30)%2;m.keyboard.matrix[0]=(m.keyboard.matrix[0]&~0x50)|(ph?0x10:0x40);}
  if(steps===201){on=true;}if(steps===601){on=false;n=400;}}
};
for(let f=0;!n&&f<9000;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
console.log(`${process.env.FROM}..${process.env.TO}: ${Math.round(total/n)} тактов/шаг (включая всё, что исполнено внутри диапазона адресов)`);
for(const [k,v] of Object.entries(h).sort((a,b)=>b[1]-a[1]).slice(0,+(process.env.TOP||20)))console.log(String(Math.round(v/n)).padStart(6),k);
