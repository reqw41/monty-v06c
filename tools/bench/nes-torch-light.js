// Темноту снимает факел (инвентарь 8C), а не амулет (53): NES $AD7E проверяет предмет 0C.
// Комната (8,9) на уровне 1 тёмная (ряд 8 >= 9-1): группы 0..2 чёрные (00). С факелом — обычные цвета.
// B=build/quick node tools/bench/nes-torch-light.js
'use strict';
const assert=require('assert/strict'),path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/quick',s=symbols(B);
function probe(item){
 const m=E.mk(B+'/monty.bin');let steps=0;
 m.onInstr=pc=>{if(pc!==s.L_A5D1)return;steps++;m.wr(0x7049,6);
  if(steps===40){m.wr(0x71A6,1);if(item)m.wr(0x71B2,item);}
  if(steps===50){m.wr(0x71A7,8);m.wr(0x71A8,9);m.wr(0x7079,9);m.wr(0x70B1,m.rd(0x70B1)|0x10);}};
 for(let f=0;f<900&&steps<250;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
 assert.equal(m.rd(0x71a7),8);assert.equal(m.rd(0x71a8),9);
 return [0,1,2].map(i=>m.rd(s.room_colors+i));
}
const dark=probe(0),torch=probe(0x8C),amulet=probe(0x53);
assert.deepEqual(dark,[0,0,0],'dark room without the torch');
assert(torch.every(c=>c!==0),'torch lights the room: '+torch);
assert.deepEqual(amulet,[0,0,0],'amulet does not light the room');
console.log(JSON.stringify({B,dark,torch,amulet}));
