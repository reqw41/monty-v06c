// Шаги слышны: при ходьбе в уровне (без музыки, очередь звука простаивает) делители «тука» реально уходят в порты ВИ53.
// B=build/quick node tools/bench/nes-step-audible.js
'use strict';const assert=require('node:assert/strict');process.chdir(require('path').resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/quick',s=symbols(B);const m=E.mk(B+'/monty.bin');m.outs=[];
let steps=0;
m.onInstr=pc=>{
 if(pc===s.L_8DA2&&steps>60){const c=m.cpu;c.pc=m.rd(c.sp)|m.rd(c.sp+1)<<8;c.sp+=2;return;}
 if(pc!==s.L_A5D1)return;steps++;m.wr(0x7049,6);
 if(steps===50){m.wr(0x71A7,2);m.wr(0x71A8,8);m.wr(0x7079,9);}
 if(steps===150)m.outs.length=0;
 if(steps>150){const ph=Math.floor((steps-150)/30)%2;m.keyboard.matrix[0]=(m.keyboard.matrix[0]&~0x50)|(ph?0x10:0x40);}
};
let f=0;for(;steps<450;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
const o=m.outs;const ports={};let hi=0,lo=0;
for(let i=0;i+3<o.length;i+=2){ports[o[i].toString(16)]=(ports[o[i].toString(16)]||0)+1;if(o[i+1]===0x98&&o[i+3]===0x3A&&o[i]===o[i+2])hi++;if(o[i+1]===0x20&&o[i+3]===0x4E&&o[i]===o[i+2])lo++;}
assert(hi>=20&&lo>=20,'шаги слышны: '+hi+'/'+lo);console.log(JSON.stringify({B,steps:300,top100:hi,top75:lo}));
