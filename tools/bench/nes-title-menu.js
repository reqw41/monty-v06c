// Title HUD menu: arrows choose the level (centre digit), Fire starts it;
// the record (score box) is updated at GAME OVER and drawn on the title.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');
const frames=n=>{for(let i=0;i<n;i++)m.frame();};
const tap=(row,bit)=>{m.keyboard.matrix[row]|=bit;frames(4);m.keyboard.matrix[row]&=~bit;frames(4);};
// Centre digit cell (HUD row 2, column 14): compare against title_digit's own rendering.
const cell=(col,row)=>[0,1,2].map(p=>[...Array(8)].map((_,y)=>m.rd(0x8000+0x2000*p+256*col+0xFF-8-8*row-y)).join(','));
let entered=null;
m.onInstr=pc=>{if(pc===s.L_A59D&&entered===null)entered=m.cpu.regs[0];};
frames(120);
assert.equal(m.rd(s.menu_level),1,'level 1 by default');
const one=cell(14,2).join('|');
tap(0,0x40);assert.equal(m.rd(s.menu_level),2,'right arrow -> 2');
assert.notEqual(cell(14,2).join('|'),one,'centre digit redrawn');
tap(0,0x20);assert.equal(m.rd(s.menu_level),3,'up arrow -> 3');
tap(0,0x40);assert.equal(m.rd(s.menu_level),1,'wraps 3 -> 1');
tap(0,0x10);assert.equal(m.rd(s.menu_level),3,'left arrow wraps 1 -> 3');
assert.equal(entered,null,'arrows never start the game');
tap(7,0x80);frames(200);
assert.equal(m.rd(0x71A6),3,'Fire starts the chosen level');
// GAME OVER with a score: the record reaches the title score box.
m.wr(0x7017,0x01);m.wr(0x7018,0x23);m.wr(0x7019,0x45);
let title=false;m.onInstr=pc=>{if(pc===s.title_warm_menu)title=true;if(pc===s.go1)m.keyboard.matrix[7]|=0x80;};
m.cpu.sp=s.GSTACK;m.cpu.pc=s.game_over;
for(let f=0;f<1500&&!title;f++)m.frame();
m.keyboard.matrix[7]&=~0x80;frames(10);
assert(title,'GAME OVER returns to the title');
assert.deepEqual([...Array(3)].map((_,i)=>m.rd(s.hi_score+i)),[0x01,0x23,0x45],'record kept');
assert.equal(m.rd(s.menu_level),3,'title keeps the last level');
// Score box digits: compare 0 (column 18) with 1 (20) and 5 (28) — all distinct glyphs.
const d=[18,20,22,24,26,28].map(c=>cell(c,2).join('|'));
assert.equal(new Set(d).size,6,'six different record digits drawn');
console.log(JSON.stringify({B,levels:'1->2->3->1->3',started:3,record:'012345'}));
