// Враги после GAME OVER: холодный старт и повторный старт в той же комнате должны давать одинаковые видимые объекты (слоты 2..5).
// B=build/quick node tools/bench/restart-enemies.js [МОД=cold|warm] [ряд] [столбец]
'use strict';
const path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');
const mode=process.argv[2]||'cold',R=+(process.argv[3]||1),C=+(process.argv[4]||9);
let steps=0,forced=mode==='cold',title=false,restarts=0,since=-1,result=null,tele=false;
const snap=()=>{const o=[];for(let k=0;k<6;k++){const p=0x7300+4*m.rd(0x72E0+k);o.push([m.rd(p),m.rd(p+1),m.rd(p+2),m.rd(p+3)].join('.'));}return o;};
m.onInstr=pc=>{
 if(pc===s.go1&&forced&&mode==='warm'&&!title)m.keyboard.matrix[7]|=128;
 if(pc===s.title_warm_menu&&!title&&mode==='warm'){title=true;m.keyboard.matrix[7]&=~128;m.keyboard.matrix[2]|=2;}
 if(pc===s.warm_restart)restarts++;
 if(pc===s.L_A5D1){
  steps++;m.wr(0x7049,6);
  if(mode==='warm'&&!forced&&steps===300){forced=true;m.wr(0x70C0,255);m.wr(0x7017,0x45);m.cpu.sp=s.GSTACK;m.cpu.pc=s.game_over;}
  if(forced&&(mode==='cold'||restarts)){since++;m.keyboard.matrix[2]=0;
   if(since===20&&!tele){tele=true;m.wr(0x71A7,R);m.wr(0x71A8,C);m.wr(0x7079,9);}
   if(since===120){result={idx:Array.from({length:6},(_,k)=>m.rd(0x72E0+k)),objs:snap(),sizes:[m.rd(0x7302),m.rd(0x7306)]};}}
 }
};
for(let f=0;!result&&f<9000;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100&&(mode==='cold'||!forced))m.keyboard.matrix[2]&=~2;m.frame();}
console.log(JSON.stringify({B,mode,room:[R,C],result}));
if(process.env.ASSERT){const a=JSON.stringify(result);const cold=require('child_process').execFileSync('node',[__filename,'cold',String(R),String(C)],{env:{...process.env,ASSERT:''}}).toString();
 if(JSON.parse(cold).result&&JSON.stringify(JSON.parse(cold).result)!==a){console.error('ПОСЛЕ GAME OVER враги/размеры отличаются от холодного старта');process.exitCode=1;}}
