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
const names=decodeRle(0xd9e9),attributes=decodeRle(0xdb12),colours=[15,32,6,39,16,22,28,23],textInk=s.NES_TITLE_TEXT_SLOT;
const titlePals=[0xd46b,0xd47f,0xd483].map(a=>Array.from({length:4},(_,i)=>rom[16+a-0x8000+i]));
titlePals.push([15,15,15,15]);
const chrPixel=(t,x,y)=>((rom[32784+16*t+y]>>(7-x))&1)|(((rom[32784+16*t+y+8]>>(7-x))&1)<<1);
// Lower scene = native field tiles drawn by the game's builder: every cell
// must equal the independent NES CHR reference of that game tile (fire D2 in
// any of its four phases), in the game's palette.
const sceneRef=require('./nes-video-ref');let fire=0;
function checkScene(){
 for(let ty=s.TITLE_SCENE_ROW0;ty<30;ty++)for(let tx=0;tx<32;tx++){
  const t=m.rd(s.TT_MAP+32*(ty-s.TITLE_SCENE_ROW0)+tx);
  const got=[0,1,2].flatMap(p=>[...Array(8)].map((_,y)=>m.rd(0x8000+0x2000*p+256*tx+255-8*ty-y)));
  if(!t){assert(got.every(v=>v===0),`blank scene cell ${tx},${ty}`);continue;}
  const ok=[0,1,2,3].slice(0,t===0xd2?4:1).some(ph=>{const want=sceneRef.cell(m,s,t,ph,0,{dark:false});return want.every((v,i)=>v===got[i]);});
  assert(ok,`game tile ${t.toString(16)} at ${tx},${ty}`);if(t===0xd2)fire++;
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
const DY=8; // credits moved down under the static HUD (tools/nes/title_native.py)
for(let y=90+DY;y<128+DY;y++)for(let x=0;x<256;x++){
 const addr=(x>>3)*256+s.SCREEN_TOP-y,bit=128>>(x&7);
 const got=((m.rd(0x8000+addr)&bit)?4:0)|((m.rd(0xa000+addr)&bit)?2:0)|((m.rd(0xc000+addr)&bit)?1:0);
 assert.equal(scene[y*256+x],expected[(y-90-DY)*256+x],`copyright artwork ${x},${y}`);
 assert.equal(got,expected[(y-90-DY)*256+x],`title credit pixel ${x},${y}`);
}
// The level menu is the title HUD now (nes-title-menu.js); the font keeps E and V for GAME OVER.
for(const [i,ch,tile] of [[0,'E',0x70],[1,'V',0x81]]){
 const got=Array.from({length:8},(_,y)=>m.rd(s.font_tab+9*i+1+y));
 const want=Array.from({length:8},(_,y)=>rom[32784+16*(256+tile)+y]|rom[32784+16*(256+tile)+8+y]);
 assert.equal(m.rd(s.font_tab+9*i),ch.charCodeAt(0));assert.deepEqual(got,want,`NES glyph ${ch}`);
}
for(let frame=0;frame<120;frame++)m.frame();
checkScene();
assert.equal(m.rd(s.cmap+15),textInk,'selector shares NES title credit ink');
assert.equal(m.rd(s.pal+2*textInk),173,'same ink as NES title credits');
assert.equal(m.rd(s.pal+2),255,'rope stays white');
console.log(JSON.stringify({B,source:'original NES title-credit CHR',credits,creditPixelsCompared:expected.length,glyphs:2,ink:173}));
