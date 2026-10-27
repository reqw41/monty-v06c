// Inclusive cycles in each routine entry context, with explicit stack-switch returns.
const fs=require('fs');process.chdir(require('path').resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols,profiler,calls}=require('./logic-profile');
const B=process.env.B||'build/native',s=symbols(B),names=(process.env.W||'disp_prep,crit,frame_handler,L_88D1,L_A7A1,L_9159').split(',');
const labs=Object.entries(s).filter(([n,a])=>a>=0x100&&a<0x7000&&!n.startsWith('C_')).sort((a,b)=>a[1]-b[1]);
const near=a=>{let n='?';for(const [k,v]of labs){if(v>a)break;n=k;}return n;};
const m=E.mk(B+'/monty.bin'),p=profiler(m,s),c=calls(m,s,p,names);let steps=0,done=false;
m.onInstr=pc=>{
  const ctx=p.instruction(pc);c.instruction(pc,ctx,steps>=201&&steps<601);
  if(pc===s.L_8DA2&&steps>60){const cpu=m.cpu;cpu.pc=m.rd(cpu.sp)|m.rd(cpu.sp+1)<<8;cpu.sp+=2;return;}
  if(pc===s.L_A5D1){steps++;if(steps===601)done=true;m.wr(0x7049,6);
    {m.wr(0x707C,m.rd(0x7300));if(steps===50){m.wr(0x705F,m.rd(0x705F)&~4);m.wr(0x71A7,(process.env.ROOM||"1,9").split(",").map(Number)[0]);m.wr(0x71A8,(process.env.ROOM||"1,9").split(",").map(Number)[1]);m.wr(0x7079,9);}}
  }
};
for(let f=0;!done;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
const totals={};for(const z of c.stats.values()){const q=totals[z.name]||(totals[z.name]={cycles:0,count:0,max:0});q.cycles+=z.cycles;q.count+=z.count;q.max=Math.max(q.max,z.max);}
for(const name of names){const q=totals[name];if(q)console.log(name,'вызовов',q.count,'тактов/вызов',Math.round(q.cycles/q.count),'тактов/шаг',Math.round(q.cycles/400),...(process.env.DETAIL?['максимум',q.max]:[]));}
