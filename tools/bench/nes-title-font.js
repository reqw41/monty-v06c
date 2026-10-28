// Added level selector uses the same CHR alphabet and ink as NES title credits.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');
const rom=fs.readFileSync('orig/nes/monty.nes');
const alphabet=Object.fromEntries(Array.from({length:26},(_,i)=>[String.fromCharCode(65+i),0x6c+i]));
for(let i=0;i<10;i++)alphabet[String(i)]=0x62+i;
const brackets={'(':[0x18,0x30,0x60,0x60,0x60,0x30,0x18,0],')':[0x30,0x18,0x0c,0x0c,0x0c,0x18,0x30,0]};
const credits=[[96,'(C) PARKER BROTHER 1984'],[107,'VECTOR 06C VERSION BY'],[118,'BORIS LIKHACHEV']];
const expected=new Uint8Array(256*36);
for(const [y,line] of credits){const x0=(256-8*line.length)/2;for(let i=0;i<line.length;i++)for(let yy=0;yy<8;yy++)for(let xx=0;xx<8;xx++){
 const ch=line[i],tile=alphabet[ch],bits=brackets[ch]?.[yy]??(tile===undefined?0:rom[32784+16*(256+tile)+yy]|rom[32784+16*(256+tile)+8+yy]);
 if(bits&(128>>xx))expected[(y+yy-92)*256+x0+8*i+xx]=6;
}}
for(let y=92;y<128;y++)for(let x=0;x<256;x++){
 const addr=(x>>3)*256+s.SCREEN_TOP-y,bit=128>>(x&7);
 const got=((m.rd(0x8000+addr)&bit)?4:0)|((m.rd(0xa000+addr)&bit)?2:0)|((m.rd(0xc000+addr)&bit)?1:0);
 assert.equal(got,expected[(y-92)*256+x],`title credit pixel ${x},${y}`);
}
const tiles=[['S',0x7e],['E',0x70],['L',0x77],['C',0x6e],['T',0x7f],['V',0x81],['1',0x63],['2',0x64],['3',0x65],['.',0x86]];
const glyphs=new Map([[' ',Array(8).fill(0)]]);
for(let i=0;i<tiles.length;i++){
 const [ch,tile]=tiles[i],got=Array.from({length:8},(_,y)=>m.rd(s.font_tab+9*i+1+y));
 const want=Array.from({length:8},(_,y)=>rom[32784+16*(256+tile)+y]|rom[32784+16*(256+tile)+8+y]);
 assert.equal(m.rd(s.font_tab+9*i),ch.charCodeAt(0));assert.deepEqual(got,want,`NES glyph ${ch}`);glyphs.set(ch,got);
}
const comma=glyphs.get('.').slice();comma[7]=0x80;glyphs.set(',',comma);
assert.deepEqual(Array.from({length:8},(_,y)=>m.rd(s.font_tab+10*9+1+y)),comma,'comma follows NES period style');
for(let frame=0;frame<120;frame++)m.frame();
assert.equal(m.rd(s.pal+14),173,'same ink as NES title credits');
const line='SELECT LEVEL   1, 2, 3.';
for(let i=0;i<line.length;i++)for(let plane=0;plane<3;plane++)for(let y=0;y<8;y++){
 const addr=0x8000+0x2000*plane+256*(5+i)+s.SCREEN_TOP-8*18-y;
 assert.equal(m.rd(addr),glyphs.get(line[i])[y],`menu glyph ${i} plane ${plane} row ${y}`);
}
console.log(JSON.stringify({B,source:'original NES title-credit CHR',credits:credits.map(x=>x[1]),creditPixelsCompared:expected.length,glyphs:10,menuPixelsCompared:line.length*8*3,ink:173}));
