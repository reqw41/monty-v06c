// «Живая» игра: случайный ввод (зерно), Джо смертен (жизни держатся), каждые 300 шагов — следующая комната.
// node tools/bench/play.js ЗЕРНО ЧАСТЬ ЧАСТЕЙ  (OUT=префикс, H=корень проекта со сборкой build/native)
// Пишет по комнатам распределение кадров на шаг; исключаются шаги от -5 до +40 вокруг перерисовки комнаты и гибель (7079 >= 8).
// Исключаются 40 шагов после смены комнаты (draw_all) и шаги гибели/возрождения (7079 = 8, 9, A).
const fs=require('fs');const H=process.env.H||require('path').resolve(__dirname,'../..');process.chdir(H);
const B=process.env.B||'build/native';const E=require(H+'/tools/vec_emu');const sym={};for(const l of fs.readFileSync(B+'/monty.sym','latin1').split('\n')){const q=l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i);if(q)sym[q[1]]=parseInt(q[2],16);}
const seed=+(process.argv[2]||1), part=+(process.argv[3]||0), parts=+(process.argv[4]||1);
const ROOMS=[];for(let r=0;r<9;r++)for(let c=8-r;c<=10+r;c++)ROOMS.push([r,c]);
const my=ROOMS.filter((_,i)=>i%parts===part);
let x=seed*7919+part;const rnd=(n)=>{x=(x*1103515245+12345)&0x7fffffff;return x%n;};
const KEYS={left:[0,0x10],up:[0,0x20],right:[0,0x40],down:[0,0x80],space:[7,0x80]};
const m=E.mk(B+'/monty.bin');let steps=0,fc=0,sf=0,cool=0,ri=0;const stat={};let curRoom='';const REC=[];let da=0;const motion=require('./joe-motion')(m,sym);const framecheck=process.env.FRAMECHECK==='1'?require('./framecheck')(m,sym):null;
const irq=framecheck?require('./irq-watch')(m,sym):null;
m.onInstr=(pc)=>{if(irq)irq.instruction(pc);motion.instruction(pc);if(framecheck)framecheck.instruction(pc); if(pc===sym.draw_all){cool=40;da=1;}
 if(pc===sym.L_A5D1){steps++;m.wr(0x7049,6);if(process.env.ZAP&&steps===3){const z=+process.env.ZAP,from=+(process.env.ZAPFROM||0);for(let i=from;i<from+z;i++){m.wr(sym.ps_tab+2*i,0);m.wr(sym.ps_tab+2*i+1,0);}}
  const f=m.frames-sf;sf=m.frames;const st=m.rd(0x7079);
  REC.push([steps,f,st,m.rd(0x71A7)+','+m.rd(0x71A8),da]);da=0;
  if(steps>=300&&(steps-300)%300===0&&ri<my.length){const [r,c]=my[ri++];m.wr(0x71A7,r);m.wr(0x71A8,c);m.wr(0x7079,9);}
  if(steps>200&&steps%(4+rnd(10))===0){for(const k in KEYS){const e=KEYS[k];if(rnd(3)===0)m.keyboard.matrix[e[0]]|=e[1];else m.keyboard.matrix[e[0]]&=~e[1];}}}};
const N=300+300*my.length;
while(steps<N&&fc<N*4){if(fc===10)m.keyboard.matrix[2]|=2;if(fc===100)m.keyboard.matrix[2]&=~2;if(fc===150)m.keyboard.matrix[7]|=0x80;if(fc===160)m.keyboard.matrix[7]&=~0x80;fc++;m.frame();motion.frame();}
const bad=new Set();REC.forEach((r,i)=>{if(r[4])for(let j=i-5;j<=i+40;j++)bad.add(j);});
REC.forEach((r,i)=>{if(r[0]<=320||bad.has(i)||r[2]>=8)return;const s=(stat[r[3]]=stat[r[3]]||{h:{},n:0});s.h[r[1]]=(s.h[r[1]]||0)+1;s.n++;});
fs.writeFileSync(`${process.env.DIR||'build'}/${process.env.OUT||'play'}_${seed}_${part}.json`,JSON.stringify(stat));

fs.writeFileSync(`${process.env.DIR||'build'}/${process.env.OUT||'play'}_joe_${seed}_${part}.json`,JSON.stringify(motion.result()));

if(framecheck){const q=framecheck.result();fs.writeFileSync(`${process.env.DIR||'build'}/${process.env.OUT||'play'}_frames_${seed}_${part}.json`,JSON.stringify(q));if(q.bad||!q.checks)process.exitCode=1;}
if(irq)fs.writeFileSync(`${process.env.DIR||'build'}/${process.env.OUT||'play'}_irq_${seed}_${part}.json`,JSON.stringify(irq.result()));

if(steps<N){console.error('Сценарий не завершён:',steps,'из',N,'шагов');process.exitCode=1;}
