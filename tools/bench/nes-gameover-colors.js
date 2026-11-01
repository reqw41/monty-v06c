// GAME OVER uses one fixed white ink on all nine room accents.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
const boot=m.memory.bytes.slice(),glyphs=new Map();
for(const base of [s.font_tab,s.font_extra])for(let a=base;m.rd(a)&&m.rd(a)!==255;a+=9)glyphs.set(String.fromCharCode(m.rd(a)),Array.from({length:8},(_,y)=>m.rd(a+1+y)));
function run(name,stop=s.unit_trap){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==stop;n++){assert(n<1000000,name+' hung');c.instruction();}}
let checks=0;
function check(row){for(const [i,ch]of [...'GAME OVER'].entries())for(let p=0;p<3;p++)for(let y=0;y<8;y++){
 const a=0x8000+0x2000*p+256*(11+i)+s.SCREEN_TOP-8*15-y,want=p===2?(glyphs.get(ch)||Array(8).fill(0))[y]:0;
 assert.equal(m.rd(a),want,`row ${row}, character ${i}, plane ${p}, scanline ${y}`);checks++;
}assert.equal(m.rd(s.cmap+15),1);assert.equal(m.rd(s.pal+2),255);}
for(let row=0;row<9;row++){
 m.memory.bytes.set(boot);m.wr(0x71a7,row);run('style_palette');run('game_over',s.go1);check(row);
 m.cpu.iff=true;m.cpu.iff_pending=0;m.keyboard.matrix[7]&=~128;
 for(let f=0;f<40;f++)m.frame();check(row);
}
console.log(JSON.stringify({B,roomRows:9,ink:1,paletteByte:255,pixelBytes:checks,heldFrames:40}));
