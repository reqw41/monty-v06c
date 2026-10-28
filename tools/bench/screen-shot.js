// Full 256x256 Vector raster, including the space above/below the old MSX window.
const fs=require('fs'),path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');const title=process.env.SCENE==='title',out=process.env.OUT||'build/nes_style/screen';
const room=process.env.ROOM?.split(',').map(Number);let steps=0;
m.onInstr=pc=>{if(pc===s.L_A5D1){steps++;m.wr(0x7049,6);if(room&&steps===50){m.wr(0x705F,m.rd(0x705F)&~4);m.wr(0x71A7,room[0]);m.wr(0x71A8,room[1]);m.wr(0x7079,9);}}};
for(let f=0;f<+(process.env.N||300);f++){if(!title){if(f===10)m.keyboard.matrix[2]|=1<<+(process.env.LV||1);if(f===100)m.keyboard.matrix[2]&=~(1<<+(process.env.LV||1));}m.frame();}
const pixels=new Uint8Array(65536);for(let y=0;y<256;y++)for(let x=0;x<256;x++){const a=(x>>3)*256+255-y,b=128>>(x&7);pixels[y*256+x]=((m.rd(0x8000+a)&b)?4:0)|((m.rd(0xa000+a)&b)?2:0)|((m.rd(0xc000+a)&b)?1:0);}
fs.mkdirSync(path.dirname(out),{recursive:true});fs.writeFileSync(out+'.idx',pixels);fs.writeFileSync(out+'.json',JSON.stringify({B,title,width:256,height:256,palette:[...Array(8)].map((_,i)=>m.rd(s.pal+2*i))}));
