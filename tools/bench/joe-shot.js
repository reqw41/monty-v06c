// Headless room screenshot, native VRAM and actual Vector palette.
const fs=require('fs'),path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');let steps=0;const room=(process.env.ROOM||'1,9').split(',').map(Number),out=process.env.OUT||'build/joe_nes/room';
m.onInstr=pc=>{if(pc===s.L_8DA2&&steps>60){const c=m.cpu;c.pc=m.rd(c.sp)|(m.rd(c.sp+1)<<8);c.sp+=2;}if(pc===s.L_A5D1){steps++;m.wr(0x7049,6);m.wr(0x707C,m.rd(0x7300));if(steps===50){m.wr(0x705F,m.rd(0x705F)&~4);m.wr(0x71A7,room[0]);m.wr(0x71A8,room[1]);m.wr(0x7079,9);}}};
for(let f=0;steps<220;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
const pixels=new Uint8Array(256*192);for(let y=0;y<192;y++)for(let x=0;x<256;x++){const a=(x>>3)*256+0xDF-y,b=128>>(x&7);pixels[y*256+x]=((m.rd(0x8000+a)&b)?4:0)|((m.rd(0xA000+a)&b)?2:0)|((m.rd(0xC000+a)&b)?1:0);}
fs.mkdirSync(path.dirname(out),{recursive:true});fs.writeFileSync(out+'.idx',pixels);fs.writeFileSync(out+'.json',JSON.stringify({B,room,palette:[...Array(8)].map((_,i)=>m.rd(s.pal+2*i))}));
