// Прыжок через боковую границу комнаты: в новой комнате прыжок продолжается и Джо приземляется (не проваливается сквозь пол,
// как при обнулении счётчика прыжка 7072 на входе в комнату — регрессия fix20). B=build/quick node tools/bench/nes-edge-jump.js
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/quick',s=symbols(B);const out=[];
for(const ex of [{R:0,C:9,col:31,r:6},{R:1,C:7,col:0,r:6},{R:1,C:8,col:0,r:6},{R:1,C:8,col:31,r:6}]){
 const m=E.mk(B+'/monty.bin');let st=0,trans=null,rooms=new Set(),minY=999,maxY=0,landed=null;const right=ex.col===31,key=right?0x40:0x10;
 m.onInstr=pc=>{if(pc===s.L_8DA2&&st>60){const c=m.cpu;c.pc=m.rd(c.sp)|m.rd(c.sp+1)<<8;c.sp+=2;return;}
  if(pc===s.L_A5D1){st++;m.wr(0x7049,6);if(st===50){m.wr(0x71A7,ex.R);m.wr(0x71A8,ex.C);m.wr(0x7079,9);}
   if(st===120){const x=right?ex.col*8-40:ex.col*8+30,y=(ex.r+8)*8-17;m.wr(0x7305,x);m.wr(0x7301,x);m.wr(0x7304,y);m.wr(0x7300,y-3);m.wr(0x7079,0);m.wr(0x7078,right?0:0x80);}
   if(st>125&&st<160){m.keyboard.matrix[0]=(m.keyboard.matrix[0]&~0x50)|key;if(st>=140&&st<=143)m.keyboard.matrix[7]|=0x80;else m.keyboard.matrix[7]&=~0x80;}
   else{m.keyboard.matrix[0]&=~0x50;m.keyboard.matrix[7]&=~0x80;}
   const room=m.rd(0x71A7)+','+m.rd(0x71A8);if(st>125&&room!==ex.R+','+ex.C){if(trans===null)trans=st;rooms.add(room);const y=m.rd(0x7304);if(y>maxY)maxY=y;if(landed===null&&m.rd(0x7079)===0)landed=y;}}};
 for(let f=0;f<700;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
 assert(trans!==null,`${ex.R},${ex.C}: переход прыжком состоялся`);
 assert.equal(rooms.size,1,`${ex.R},${ex.C}: одна новая комната, а не каскад (${[...rooms].join(' ')})`);
 assert(landed!==null&&landed<=100,`${ex.R},${ex.C}: Джо приземлился в новой комнате (landed=${landed}, maxY=${maxY})`);
 out.push({from:ex.R+','+ex.C,to:[...rooms][0],landedY:landed});
}
console.log(JSON.stringify({B,cases:out}));
