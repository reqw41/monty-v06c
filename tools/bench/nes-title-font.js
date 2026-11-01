// Added level selector uses the same CHR alphabet and ink as NES title credits.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');
const rom=fs.readFileSync('orig/nes/monty.nes');
const alphabet=Object.fromEntries(Array.from({length:26},(_,i)=>[String.fromCharCode(65+i),0x6c+i]));
for(let i=0;i<10;i++)alphabet[String(i)]=0x62+i;
const credits=['© UTOPIA SOFTWARE 1984','VECTOR 06C VERSION BY','BORIS LIKHACHEV 2026'];
const expected=new Uint8Array(256*38),scene=fs.readFileSync('build/nes_title/native.idx');
assert.equal(scene.length,256*240);
function decodeRle(address){
 const out=[];let literal=true;
 for(let p=16+address-0x8000;;){
  const n=rom[p++];if(n===255)return out;
  if(literal){out.push(...rom.subarray(p,p+n));p+=n;}
  else{const v=rom[p++];for(let i=0;i<(n||256);i++)out.push(v);}
  literal=!literal;
 }
}
const names=decodeRle(0xd9e9),attributes=decodeRle(0xdb12),colours=[15,32,6,39,16,28,23,22],textInk=s.NES_TITLE_TEXT_SLOT;
const titlePals=[0xd46b,0xd47f,0xd483].map(a=>Array.from({length:4},(_,i)=>rom[16+a-0x8000+i]));
titlePals.push([15,15,15,15]);
const chrPixel=(t,x,y)=>((rom[32784+16*t+y]>>(7-x))&1)|(((rom[32784+16*t+y+8]>>(7-x))&1)<<1);
function checkScene(){
 for(let y=160;y<240;y++)for(let x=0;x<256;x++){
  const tx=x>>3,ty=y>>3,pi=(attributes[(ty>>2)*8+(tx>>2)]>>(((ty&2)?4:0)+((tx&2)?2:0)))&3;
  const v=chrPixel(256+names[ty*32+tx],x&7,y&7);
  let want=colours.indexOf(v?titlePals[pi][v]:15);
  if(ty>=23&&(tx===15||tx===16))want=x>=124&&x<132&&chrPixel(ty===23?0x10c:0x10d,x-124,y&7)?1:0;
  const a=(x>>3)*256+s.SCREEN_TOP-y,bit=128>>(x&7);
  const got=(m.rd(0x8000+a)&bit?4:0)|(m.rd(0xa000+a)&bit?2:0)|(m.rd(0xc000+a)&bit?1:0);
  assert.equal(scene[y*256+x],want,`lower NES tile scene ${x},${y}`);
  assert.equal(got,want,`lower title VRAM ${x},${y}`);
 }
}
checkScene();
const markX=(256-(12+8*'UTOPIA SOFTWARE 1984'.length))/2;
const mark=['..#####..','.#.....#.','#..###..#','#..#....#','#..#....#','#..#....#','#..###..#','.#.....#.','..#####..'];
for(let yy=0;yy<mark.length;yy++)for(let xx=0;xx<9;xx++)if(mark[yy][xx]==='#')expected[(95+yy-90)*256+markX+xx]=textInk;
for(const [y,line] of [[96,'UTOPIA SOFTWARE 1984'],[107,credits[1]],[118,credits[2]]]){
 const x0=y===96?markX+12:(256-8*line.length)/2;
 for(let i=0;i<line.length;i++)for(let yy=0;yy<8;yy++)for(let xx=0;xx<8;xx++){
  const tile=alphabet[line[i]],bits=tile===undefined?0:rom[32784+16*(256+tile)+yy]|rom[32784+16*(256+tile)+8+yy];
  if(bits&(128>>xx))expected[(y+yy-90)*256+x0+8*i+xx]=textInk;
 }
}
for(let y=90;y<128;y++)for(let x=0;x<256;x++){
 const addr=(x>>3)*256+s.SCREEN_TOP-y,bit=128>>(x&7);
 const got=((m.rd(0x8000+addr)&bit)?4:0)|((m.rd(0xa000+addr)&bit)?2:0)|((m.rd(0xc000+addr)&bit)?1:0);
 assert.equal(scene[y*256+x],expected[(y-90)*256+x],`copyright artwork ${x},${y}`);
 assert.equal(got,expected[(y-90)*256+x],`title credit pixel ${x},${y}`);
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
checkScene();
assert.equal(m.rd(s.cmap+15),textInk,'selector shares NES title credit ink');
assert.equal(m.rd(s.pal+2*textInk),173,'same ink as NES title credits');
assert.equal(m.rd(s.pal+2),255,'rope stays white');
const line='SELECT LEVEL   1, 2, 3.';
for(let i=0;i<line.length;i++)for(let plane=0;plane<3;plane++)for(let y=0;y<8;y++){
 const addr=0x8000+0x2000*plane+256*(5+i)+s.SCREEN_TOP-8*18-y;
 assert.equal(m.rd(addr),textInk&(4>>plane)?glyphs.get(line[i])[y]:0,`menu glyph ${i} plane ${plane} row ${y}`);
}
console.log(JSON.stringify({B,source:'original NES title-credit CHR',credits,creditPixelsCompared:expected.length,glyphs:10,menuPixelsCompared:line.length*8*3,ink:173}));
