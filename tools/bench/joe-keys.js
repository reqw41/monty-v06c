// Сколько разных образов Джо (ключ кэша joe_prepare: кадр, направление, x&7, пропуск, строки) встречается при движении
// и какой процент перерисовок дал бы кэш на N образов (LRU). B=build/quick ROOM=2,8 SCENE=walk|jump|mix node tools/bench/joe-keys.js
const path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/quick',s=symbols(B),m=E.mk(B+'/monty.bin'),scene=process.env.SCENE||'walk';
const [R,C]=(process.env.ROOM||'2,8').split(',').map(Number);
let steps=0,cool=0,fr=0,x0=-1;const seq=[];let prev='';
m.onInstr=pc=>{
 if(pc===s.draw_all||pc===s.L_A067)cool=60;
 if(pc===s.L_A5D1){steps++;m.wr(0x7049,6);if(s.nes_amulet_ticks){m.wr(s.nes_amulet_ticks,200);m.wr(s.nes_amulet_ticks+1,0);}
  if(steps===50){m.wr(0x71A7,R);m.wr(0x71A8,C);m.wr(0x7079,9);}
  if(steps>150){const ph=Math.floor((steps-150)/30)%2;m.keyboard.matrix[0]=(m.keyboard.matrix[0]&~0x50)|(ph?0x10:0x40);
   if(scene!=='walk'){const j=scene==='jump'?(steps%40<2):(steps%97<2);m.keyboard.matrix[7]=j?(m.keyboard.matrix[7]|0x80):(m.keyboard.matrix[7]&~0x80);}}
  if(cool>0)cool--;
  if(steps>200){const k=Array.from({length:5},(_,i)=>m.rd(s.jn_key+i)).join(',');if(k!==prev&&cool===0){seq.push(k);}prev=k;}
 }
};
for(;steps<1500&&fr<30000;fr++){if(fr===10)m.keyboard.matrix[2]|=2;if(fr===100)m.keyboard.matrix[2]&=~2;m.frame();}
const distinct=new Set(seq);
const sim=n=>{const c=[];let hit=0;for(const k of seq){const i=c.indexOf(k);if(i>=0){hit++;c.splice(i,1);}else if(c.length>=n)c.shift();c.push(k);}return hit};
const poses=new Set(seq.map(k=>k.split(',')[0])),dirs=new Set(seq.map(k=>k.split(',')[1])),sh=new Set(seq.map(k=>k.split(',')[2]));
console.log(`${scene} комната ${R},${C}: перерисовок ${seq.length} за ~${steps-200} шагов, разных ключей ${distinct.size} (поз ${poses.size}, направлений ${dirs.size}, сдвигов ${sh.size})`);
console.log('доля попаданий LRU:',[1,2,4,8,16,24,32,48,64].map(n=>n+':'+(100*sim(n)/seq.length).toFixed(0)+'%').join('  '));
if(process.env.SHOW)console.log([...distinct].join(' | '));

{const cls={};let prevK=null;for(const k of seq){if(prevK){const a=prevK.split(',').map(Number),b=k.split(',').map(Number);
 let c;if(a[0]===b[0]&&a[1]===b[1]&&a[3]===b[3]&&a[4]===b[4]){const d=((b[2]-a[2])+8)%8;c=d===4?'тот же кадр, сдвиг ±4':'тот же кадр, другой сдвиг ('+d+')';}else if(a[0]===b[0]&&a[1]!==b[1])c='развернулся';else c='другой кадр';cls[c]=(cls[c]||0)+1;}prevK=k;}
 const tot=Object.values(cls).reduce((x,y)=>x+y,0);console.log('переходы между перерисовками:',Object.entries(cls).sort((a,b)=>b[1]-a[1]).map(([k,v])=>k+' '+(100*v/tot).toFixed(0)+'%').join(' | '));}
