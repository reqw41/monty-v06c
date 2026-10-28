// Check the four patterned vase tiles on the real start screen against NES CHR.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');
const rom=fs.readFileSync('orig/nes/monty.nes'),chr=rom.subarray(32784);
for(let f=0;f<320;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
assert.deepEqual([m.rd(0x71a7),m.rd(0x71a8)],[0,10]);
const map=[0,3,2,6];let checked=0,colors=new Set();
for(let part=0;part<4;part++){
 const t=0xc8+part,nt=0x113+part,col=30+(part&1),row=15+(part>>1);
 assert.equal(m.rd(s.VNT+row*32+col),t,'vase map tile');
 for(let y=0;y<8;y++)for(let x=0;x<8;x++){
  const src=16*nt+y,bit=128>>x,nes=!!(chr[src]&bit)|((!!(chr[src+8]&bit))<<1),want=map[nes];
  const addr=256*col+s.SCREEN_TOP-8*row-y,b=bit;
  const got=[0x8000,0xa000,0xc000].reduce((v,base,p)=>v|((m.rd(base+addr)&b)?4>>p:0),0);
  assert.equal(got,want,`part ${part} pixel ${x},${y}`);checked++;colors.add(got);
 }
}
assert(colors.size>=3,'vase pattern must have multiple inks');
console.log(JSON.stringify({B,tiles:4,pixels:checked,colors:[...colors].sort()}));
