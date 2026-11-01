// Стоимость элементов кадра при движении Джо: профиль по дереву вызовов.
// Такты относятся к самой вложенной вызванной процедуре (имя — ближайшая метка к точке входа), с учётом места вызова.
// B=build/quick ROOM=1,9 KEYS=walk|idle [TOP=45] node tools/bench/walk-cost.js
const fs=require('fs');process.chdir(require('path').resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols,profiler}=require('./logic-profile');
const B=process.env.B||'build/quick',sym=symbols(B),mode=process.env.KEYS||'walk';
const labs=Object.entries(sym).filter(([k,v])=>v>=0&&v<0x10000&&!k.startsWith('C_')).sort((a,b)=>a[1]-b[1]);
const near=Array(0x10000).fill('?');let j=0;
for(let a=0;a<0x10000;a++){while(j+1<labs.length&&labs[j+1][1]<=a)j++;near[a]=labs[j]?.[0]||'?';}
const m=E.mk(B+'/monty.bin'),p=profiler(m,sym);
const CALLS=new Set([0xCD,0xC4,0xCC,0xD4,0xDC,0xE4,0xEC,0xF4,0xFC]);
const [R,C]=(process.env.ROOM||'1,9').split(',').map(Number);
const st={L:[],D:[],I:[],W:[]};const cost={};   // ключ ctx|routine@callsite
let steps=0,last=0,lastSp=0,lastOp=0,ctx='L',on=false,start=null,end=null,f0=0,f1=0,fr=0;
const recent=[];const sh={};let movedSteps=0,lastX=-1,xs=new Set();let cur={},curTot={L:0,D:0,I:0,W:0},dirtyNow=false,cool=0,clean=0,cleanFrames=0,stepF=0;const agg={},aggTot={L:0,D:0,I:0,W:0};
const add=(c,k,v)=>{cur[c+'|'+k]=(cur[c+'|'+k]||0)+v;curTot[c]+=v;};
m.onInstr=pc=>{
  const next=p.instruction(pc);
  if(pc===sym.room_redraw||pc===sym.draw_all||pc===sym.L_A067)dirtyNow=true;
  const el=m.cpu.vcycles||0;
  if(on){const s=st[ctx];const top=s[s.length-1];add(ctx,top?top.name+'<'+top.site:'(корень '+near[last]+')',el);}
  // вызов: прошлая инструкция CALL, SP уменьшился на 2, на стеке адрес возврата last+3
  const sp=m.cpu.sp,s2=st[next];
  if(CALLS.has(lastOp)&&sp===lastSp-2&&((m.rd(sp)|m.rd(sp+1)<<8)===last+3)&&pc!==last+3)s2.push({name:near[pc],site:near[last],ra:last+3,sp});
  else while(s2.length&&pc===s2[s2.length-1].ra&&sp===s2[s2.length-1].sp+2)s2.pop();
  last=pc;lastSp=sp;lastOp=m.rd(pc);ctx=next;
  if(pc===sym.L_8DA2&&steps>60){const c=m.cpu;c.pc=m.rd(c.sp)|m.rd(c.sp+1)<<8;c.sp+=2;return;}
  if(pc===sym.L_A5D1){
    steps++;m.wr(0x7049,6);if(process.env.ZAP&&steps===3){const z=+process.env.ZAP,from=+(process.env.ZAPFROM||0);for(let i=from;i<from+z;i++){m.wr(sym.ps_tab+2*i,0);m.wr(sym.ps_tab+2*i+1,0);}}if(sym.nes_amulet_ticks){m.wr(sym.nes_amulet_ticks,200);m.wr(sym.nes_amulet_ticks+1,0);}if(on){sh[m.rd(0x7079)]=(sh[m.rd(0x7079)]||0)+1;const x=m.rd(0x7305);if(lastX>=0&&x!==lastX&&!dirtyNow)movedSteps++;lastX=x;xs.add(x);}
    if(steps===50){m.wr(0x71A7,R);m.wr(0x71A8,C);m.wr(0x7079,9);}
    if(mode==='walk'&&steps>150){const ph=Math.floor((steps-150)/30)%2;m.keyboard.matrix[0]=(m.keyboard.matrix[0]&~0x50)|(ph?0x10:0x40);}
    if(on){ // закрыть прошлый шаг; смену комнаты отсекаем с запасом (3 шага до и 45 после)
      if(dirtyNow){recent.length=0;cool=45;}
      else if(cool>0)cool--;
      else{recent.push({cur,curTot,fr:fr-stepF});
       while(recent.length>3){const r=recent.shift();clean++;cleanFrames+=r.fr;for(const k in r.cur)agg[k]=(agg[k]||0)+r.cur[k];for(const c in r.curTot)aggTot[c]+=r.curTot[c];}}
      cur={};curTot={L:0,D:0,I:0,W:0};dirtyNow=false;stepF=fr;}
    if(steps===201){on=true;stepF=fr;f0=fr;}
    if(steps===901){end={};f1=fr;on=false;}
  }
};
for(;!end&&fr<20000;fr++){if(fr===10)m.keyboard.matrix[2]|=2;if(fr===100)m.keyboard.matrix[2]&=~2;m.frame();}
const frames=cleanFrames,F=59904,N=clean;const tot=aggTot;
console.log(`Джо сдвинулся в ${movedSteps} шагах из 700, диапазон x ${Math.min(...xs)}..${Math.max(...xs)}, состояния ${JSON.stringify(sh)}, y ${m.rd(0x7304)}`);
console.log(`room ${R},${C} ${mode}: чистых шагов ${N} (из 700), ${frames} кадров = ${(50*N/frames).toFixed(1)} шагов/с;  на шаг: L ${Math.round(tot.L/N)}  D ${Math.round(tot.D/N)}  I ${Math.round(tot.I/N)}  W ${Math.round(tot.W/N)}  (кадр ${F}, на шаг ${Math.round(F*frames/N)})`);
const cost2=agg;const rows=Object.entries(cost2).sort((a,b)=>b[1]-a[1]).slice(0,+(process.env.TOP||45));
for(const [k,v] of rows)console.log(String(Math.round(v/N)).padStart(6),k);
if(process.env.JSON)fs.writeFileSync(process.env.JSON,JSON.stringify({frames,N,F,tot,cost:agg}));
