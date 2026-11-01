// Клавиша M выключает/включает музыку (нажатие = переключение), эффекты не затрагиваются.
// B=build/quick node tools/bench/nes-mute-key.js
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/quick',s=symbols(B),m=E.mk(B+'/monty.bin');
m.outs=[];
const tones=()=>{const o=m.outs;let n=0;for(let i=0;i<o.length;i+=2)if(o[i]>=9&&o[i]<=11)n++;m.outs.length=0;return n;};
const run=(frames)=>{for(let f=0;f<frames;f++)m.frame();};
const tap=()=>{m.keyboard.matrix[5]|=0x20;run(6);m.keyboard.matrix[5]&=~0x20;run(2);};
// старт игры (уровень 1), даём заиграть теме пирамиды
let fr=0;for(;fr<700;fr++){if(fr===10)m.keyboard.matrix[2]|=2;if(fr===100)m.keyboard.matrix[2]&=~2;m.frame();}
run(150);tones();run(250);const on=tones();
assert(on>20,'музыка пишет в таймер: '+on);
tap();assert.equal(m.rd(s.nes_mute),0xFF,'M выключила музыку');run(30);tones();run(300);const off=tones();
assert(off<=on*0.05,`при выключенной музыке почти нет записей в таймер: ${off} против ${on}`);
tap();assert.equal(m.rd(s.nes_mute),0,'M включила музыку');run(30);tones();run(250);const back=tones();
assert(back>on*0.5,`после включения музыка снова пишет: ${back}`);
// удержание не переключает повторно
m.keyboard.matrix[5]|=0x20;run(40);m.keyboard.matrix[5]&=~0x20;run(2);assert.equal(m.rd(s.nes_mute),0xFF,'длинное удержание = одно переключение');
console.log(JSON.stringify({B,запись_музыка_вкл:on,запись_музыка_выкл:off,запись_после_включения:back}));
