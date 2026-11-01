// Прыжок с нижнего пола стартовой комнаты (0,10): в оригинале NES (tools/nes) подъём 19 точек, на ленту (над полом на 24) приземлиться нельзя.
// B=build/quick node tools/bench/nes-start-jump.js   — печатает минимальную высоту и конечную позицию для сетки x и клавиш.
'use strict';
const path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/quick',s=symbols(B);
const KEYS={none:[],up:[[7,0x80]],right:[[7,0x80],[0,0x40]],left:[[7,0x80],[0,0x10]]};
function run(x,name,floorY){
 const m=E.mk(B+'/monty.bin');let steps=0,phase=0,n=0,trace=[],done=false;
 m.onInstr=pc=>{
  if(pc!==s.L_A5D1)return;steps++;m.wr(0x7049,6);
  if(phase===0&&steps===60){m.wr(0x7304,floorY+7);m.wr(0x7305,x);m.wr(0x7079,0);for(const k of [0x7076,0x7077])m.wr(k,0);phase=1;n=0;return;}
  if(phase===1){n++;
   if(n===8){for(const [r,b] of KEYS[name])m.keyboard.matrix[r]|=b;phase=2;n=0;}}
  else if(phase===2){n++;if(n===2)for(const [r,b] of KEYS[name])m.keyboard.matrix[r]&=~b;trace.push([m.rd(0x7305),m.rd(0x7304)-7,m.rd(0x7079)]);if(n>=70)done=true;}
 };
 for(let f=0;!done&&f<4000;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
 return trace;
}
const floorY=+(process.env.FLOOR||175);let climbed=0,total=0,minApex=999;
for(let x=84;x<=172;x+=4)for(const name of ['up','right','left']){
 const t=run(x,name,floorY);total++;const ys=t.map(q=>q[1]),mn=Math.min(...ys),end=t[t.length-1];minApex=Math.min(minApex,mn);
 if(end[1]<floorY-8){climbed++;console.log('ВЫШЕ ПОЛА',x,name,'minY',mn,'конец',end.join(','));}
}
console.log(JSON.stringify({B,total,climbed,minApexY:minApex,nesApex:156}));
if(climbed||minApex!==156)process.exitCode=1;
if(process.env.TRACE){const [x,name]=process.env.TRACE.split(',');console.log(run(+x,name,floorY).slice(0,40).map(q=>q.join(',')).join(' '));}
