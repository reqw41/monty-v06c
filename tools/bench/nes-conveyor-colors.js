// Original NES hook/body separation, including the real compiled phase writer.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),ref=require('./nes-video-ref');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
assert.equal(s.CONVEYOR_TWO_INKS,1);
for(let a=s.nes_terrain_image;a<s.nes_conveyor_end;a++)
 assert.equal(m.rd(a),m.img[a],'conveyor helper survives boot allocation at '+a.toString(16));
const tiles=[4,5,6,0xb8,0xb9,0xba],images=[];
let compiled=0,cacheCases=0,liveCases=0,watch=false;const writes=new Set(),masks=new Set();
m.onWrite=a=>{if(watch&&a>=0x8000&&a<0xe000)writes.add(a&0xe000);};
function call(name,a=0){
 const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.regs[7]=a;c.sp=0x73be;
 m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){
  assert(n<3000000,name+' hung');
  if(c.pc===s.fc_rows){compiled++;if(watch)masks.add(m.rd(s.fl_pm));}
  c.instruction();
 }
}
for(const dark of [false,true])for(const t of tiles){
 m.wr(s.room_colors+1,dark?0:0x31);m.wr(s.rr_t,t);m.wr(s.tile_frames,4);call('tile_build');
 const frames=[];
 for(let phase=0;phase<4;phase++){
  const got=Array.from({length:24},(_,i)=>m.rd(s.TILE_IMAGES+24*phase+i));
  assert.deepEqual(got,ref.cell(m,s,t,phase,0),`CHR tile ${t.toString(16)} phase ${phase}, dark ${dark}`);
  assert(got.slice(0,8).every(v=>v===0),'conveyor never sets the retained Joe plane');
  if(phase)assert.deepEqual(got.slice(8,16),frames[0].slice(8,16),'belt body is stationary');
  frames.push(got);cacheCases++;
 }
 if(!dark)images.push({t,frames});
}
function clear(){for(let t=0;t<256;t++)m.wr(s.tile_changed+t,0);}
function paint(){m.wr(s.dc_pt,1);m.wr(s.fl_skm,0);call('force_live_t',s.tile_changed>>8);}
for(const count of [2,8]){
 for(let i=0;i<960;i++)m.wr(s.VNT+i,0);
 const cells=[];
 for(const [i,t]of tiles.entries())for(let col=2;col<2+count;col++){
  const row=10+i;m.wr(s.VNT+row*32+col,t);cells.push({t,row,col});
 }
 m.wr(s.room_colors+1,0x31);m.wr(s.fire_frame,0);call('room_redraw');
 for(let old=0;old<4;old++)for(let next=0;next<4;next++){
  clear();for(const t of tiles)m.wr(s.tile_changed+t,1);m.wr(s.fire_shown,old);paint();
  clear();m.wr(s.fire_next,next);call('fire_changes');m.wr(s.fire_shown,next);
  watch=true;paint();watch=false;
  for(const {t,row,col}of cells){
   const want=ref.cell(m,s,t,next,0);
   for(let p=0;p<3;p++)for(let y=0;y<8;y++){
    const a=0x8000+p*0x2000+256*col+s.SCREEN_TOP-s.FIELD_YSHIFT-8*row-y;
    assert.equal(m.rd(a),want[p*8+y],`count ${count} ${old}->${next} tile ${t.toString(16)}, plane ${p}, row ${y}`);
   }
  }
  liveCases++;
 }
}
assert(compiled>0,'compiled animation exercised');
assert.deepEqual([...writes],[0xc000],'live animation writes only C000');
assert.deepEqual([...masks],[8],'compiled animation selects only C000');
if(process.env.OUT)fs.writeFileSync(process.env.OUT,JSON.stringify({B,images,palette:Array.from({length:8},(_,i)=>m.rd(s.pal+2*i))}));
console.log(JSON.stringify({B,cacheCases,liveCases,compiledBuckets:compiled,animatedPlane:'C000',bodyInk:3,hookInk:1,retainedJoePlane:'zero'}));
