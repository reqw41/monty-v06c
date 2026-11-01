// Joe base inks remain constant while the room accent preserves all nine RGB bytes.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<320;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.sp=0x73be;c.pc=s[name];m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<400000,name+' hung');c.instruction();}}
const accents=[5,103,186,5,159,234,96,196,173];
for(let row=0;row<9;row++){
 m.wr(0x71a7,row);call('style_palette');
 for(const [ink,rgb]of [[1,255],[2,4],[3,103],[4,32]])for(let pair=0;pair<2;pair++)assert.equal(m.rd(s.pal+2*ink+pair),rgb,`Joe ink ${ink}, row ${row}`);
 for(let pair=0;pair<2;pair++)assert.equal(m.rd(s.pal+14+pair),accents[(row+1)%9],`unchanged room hue, row ${row}`);
}
console.log(JSON.stringify({B,roomRows:9,joeBaseInks:{white:255,skin:103,red:4},roomAccentSlot:7,originalRoomHuesPreserved:true}));
