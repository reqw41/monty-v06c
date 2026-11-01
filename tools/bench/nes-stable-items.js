// Compare actual cached pickup/door pixels and palette bytes on all nine room rows.
'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),ref=require('./nes-video-ref');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
const objects=[
 ['White key',2,[0x70,0x71,0x72,0x73],'standard'],['Blue key',2,[0x78,0x79,0x7a,0x7b],'standard'],['Red key',2,[0x68,0x69,0x6a,0x6b],'standard'],
 ['Sword',2,[0x96,0x97,0x9a,0x9b],'standard'],['Amulet',2,[0xd0,0xd1,0x62,0x63],'accent'],
 ...[0,1,2,3].map(p=>['Torch '+p,2,[0xa8,0xae,0xa9,0xaf],'accent',p]),['Jewel',2,[0x98,0xd8,0x99,0xd9],'standard'],
 ['White door',1,[0xc0,0xc0,0xc0,0xc7],'standard'],['Blue door',1,[0xb0,0xb0,0xb0,0xb7],'standard'],['Red door',1,[0xbb,0xbb,0xbb,0x9c],'standard'],
 ['White arch',3,[0xc1,0xc2,0xc3,...Array(9).fill(0xc5)],'standard'],['Blue arch',3,[0xb1,0xb2,0xb3,...Array(9).fill(0xb4)],'standard'],['Red arch',3,[0xbc,0xbd,0xbe,...Array(9).fill(0xbf)],'standard']
];
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.sp=0x73be;c.pc=s[name];m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<400000,name+' hung');c.instruction();}}
if(s.STABLE_OBJECT_COLORS)for(const [first,last] of [[0xfb30,0xfb90],[0xfd30,0xfd90],[s.object_color_records,s.object_image_copy_end],[s.object_mask_address,s.JOE_BACKGROUND+9*s.joe_nes_rows]])for(let a=first;a<last;a++)assert.equal(m.rd(a),m.img[a],'permanent art/code survives boot');
const images=[],baseline=new Map();let cases=0;
for(let row=0;row<9;row++){
 m.wr(0x71a7,row);call('style_palette');const pal=Array.from({length:8},(_,i)=>m.rd(s.pal+2*i));
 for(const [name,cols,tiles,context,phase=0] of objects){
  const w=cols*8,h=tiles.length/cols*8,pixels=Array.from({length:h},()=>Array(w).fill(0));
  for(const [i,t] of tiles.entries()){
   m.wr(s.rr_t,t);m.wr(s.tile_frames,ref.animated.has(t)?4:1);m.cpu.regs[7]=0;call('tile_build');
   const want=ref.cell(m,s,t,ref.animated.has(t)?phase:0,0),base=s.TILE_IMAGES+(ref.animated.has(t)?phase:0)*24;
   for(let k=0;k<24;k++)assert.equal(m.rd(base+k),want[k],name+' tile '+t.toString(16)+' row '+row);
   for(let y=0;y<8;y++)for(let x=0;x<8;x++)pixels[8*Math.floor(i/cols)+y][8*(i%cols)+x]=[4,2,1].reduce((a,bit,p)=>a+((m.rd(base+8*p+y)&(128>>x))?bit:0),0);
  }
  const rgbBytes=pixels.flat().map(ci=>pal[ci]);
  if(s.STABLE_OBJECT_COLORS){assert(!pixels.flat().some(ci=>ci===7||ci===5),name+' depends on room/snake ink');if(baseline.has(name))assert.deepEqual(rgbBytes,baseline.get(name),name+' colour varies between room rows');else baseline.set(name,rgbBytes);}
  if(row===0)images.push({name,cols,tiles,context,phase,pixels,palette:pal});cases++;
 }
}
const summary={B,stable:!!s.STABLE_OBJECT_COLORS,roomRows:9,objects:objects.length,cases,roomDependent:s.STABLE_OBJECT_COLORS?false:undefined};
if(process.env.OUT){fs.mkdirSync(path.dirname(process.env.OUT),{recursive:true});fs.writeFileSync(process.env.OUT,JSON.stringify({summary,images},null,2));}
console.log(JSON.stringify(summary));
