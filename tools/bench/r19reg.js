// Inclusive region cost. REG="name:begin:end,..."; IRQ and frame_wait stack switches are explicit.
process.chdir(require('path').resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols,profiler}=require('./logic-profile');
const B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin'),p=profiler(m,s);
const ranges=(process.env.REG||'enemy:L_A7A1:cpir').split(',').map(x=>{const[n,a,b]=x.split(':');if(s[a]===undefined||s[b]===undefined)throw Error(x);return{n,a:s[a],b:s[b],c:0};});
let steps=0,cur=null,previous=null,previousContext='L',fw=null,done=false,draws=0;
m.onInstr=pc=>{
  const ctx=p.instruction(pc);
  if(previous&&previousContext===previous.ctx&&steps>=201&&steps<601)previous.c+=(m.cpu.vcycles||0);
  if(fw&&pc===fw.ra&&m.cpu.sp===fw.sp+2)fw=null;
  if(cur&&ctx===cur.ctx&&!fw&&(m.cpu.sp>cur.sp||(m.cpu.sp===cur.sp&&(pc<cur.a||pc>=cur.b))))cur=null;
  if(!cur)for(const r of ranges)if(pc>=r.a&&pc<r.b){cur=r;r.sp=m.cpu.sp;r.ctx=ctx;break;}
  if(cur&&pc===s.frame_wait&&!fw){const sp=m.cpu.sp;fw={sp,ra:m.rd(sp)|m.rd(sp+1)<<8};}
  previous=cur;previousContext=ctx;
  if(pc===s.disp_prep&&steps>=201&&steps<601)draws++;
  if(pc===s.L_8DA2&&steps>60){const c=m.cpu;c.pc=m.rd(c.sp)|m.rd(c.sp+1)<<8;c.sp+=2;return;}
  if(pc===s.L_A5D1){steps++;if(steps===601)done=true;m.wr(0x7049,6);m.wr(0x707C,m.rd(0x7300));if(steps===50){m.wr(0x705F,m.rd(0x705F)&~4);m.wr(0x71A7,(process.env.ROOM||"1,9").split(",").map(Number)[0]);m.wr(0x71A8,(process.env.ROOM||"1,9").split(",").map(Number)[1]);m.wr(0x7079,9);}}
};
for(let f=0;!done;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
for(const r of ranges)console.log(r.n,'тактов/шаг',Math.round(r.c/400),'тактов/подготовку',draws?Math.round(r.c/draws):0);
