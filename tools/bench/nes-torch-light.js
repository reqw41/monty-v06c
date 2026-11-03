// Темноту снимает факел (инвентарь 8C), а не амулет (53): NES $AD7E проверяет предмет 0C.
// Комната (8,9) на уровне 1 тёмная (ряд 8 >= 9-1): группа 1 = 00 и на экране гаснут кирпичи, лестницы и закрытая
// дверь (палитры NES 0 и 3), а цепь, лента, огонь (палитры 1–2) остаются. С факелом видно всё (fix24: раньше рендер
// ждал признак 0x11 и темнота не рисовалась вовсе).
// B=build/quick node tools/bench/nes-torch-light.js
'use strict';
const assert=require('assert/strict'),path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/quick',s=symbols(B);
// клетки карты (8,9): [строка поля, столбец, имя, виден ли в темноте]
const CELLS=[[0,0,'кирпич 08',false],[9,21,'лестница 88',false],[4,28,'дверь C0',false],
 [14,16,'цепь E0',true],[18,16,'лента E8',true],[20,16,'огонь D2',true],[21,16,'тело огня 38',true]];
function probe(item){
 const m=E.mk(B+'/monty.bin');let steps=0;
 m.onInstr=pc=>{if(pc!==s.L_A5D1)return;steps++;m.wr(0x7049,6);
  if(steps===40){m.wr(0x71A6,1);if(item)m.wr(0x71B2,item);}
  if(steps===50){m.wr(0x71A7,8);m.wr(0x71A8,9);m.wr(0x7079,9);m.wr(0x70B1,m.rd(0x70B1)|0x10);}};
 for(let f=0;f<900&&steps<250;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
 assert.equal(m.rd(0x71a7),8);assert.equal(m.rd(0x71a8),9);
 const seen={};
 for(const [row,col,name] of CELLS){assert.ok([0x08,0x88,0xC0,0xE0,0xE8,0xD2,0x38].includes(m.rd(0x7C00+row*32+col)),name+': код клетки '+m.rd(0x7C00+row*32+col).toString(16));
  let n=0;for(let k=0;k<8;k++)for(const pl of [0x8000,0xA000,0xC000])if(m.rd(pl+col*256+(0xBF-row*8-k)))n++;seen[name]=n;} // строка 0 поля — растр BF
 return {groups:[0,1,2].map(i=>m.rd(s.room_colors+i)),seen};
}
const dark=probe(0),torch=probe(0x8C),amulet=probe(0x53);
assert.deepEqual(dark.groups,[0,0,0],'dark room without the torch');
assert(torch.groups.every(c=>c!==0),'torch lights the room: '+torch.groups);
assert.deepEqual(amulet.groups,[0,0,0],'amulet does not light the room');
for(const [,,name,visibleInDark] of CELLS){
 assert(torch.seen[name]>0,'с факелом видно: '+name);
 for(const [who,r] of [['без предметов',dark],['с амулетом',amulet]])
  assert.equal(r.seen[name]>0,visibleInDark,`${who}: ${name} ${visibleInDark?'должен быть виден':'должен погаснуть'} (${r.seen[name]})`);
}
console.log(JSON.stringify({B,dark,torch:torch.seen}));
