// Measure the real live-cell phase writer, including short platform buckets.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const results=[];
for(const B of process.argv.slice(2)){
 const s=symbols(B),m=E.mk(B+'/monty.bin');
 for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
 const boot=m.memory.bytes.slice();let watch=false,writes=[];
 m.onWrite=a=>{if(watch&&a>=0x8000&&a<0xe000)writes.push(a);};
 function call(name,a=0){const c=m.cpu;c.iff=false;c.iff_pending=0;c.sp=0x73be;c.pc=s[name];c.regs[7]=a;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);let cycles=0;
  for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');c.instruction();cycles+=c.vcycles;}return cycles;}
 for(const count of [2,8,26]){
  m.memory.bytes.set(boot);for(let i=0;i<960;i++)m.wr(s.VNT+i,0);
  for(let col=2;col<2+count;col++)m.wr(s.VNT+14*32+col,0xe8);
  for(let k=0;k<6;k++){m.wr(0x7303+4*k,0);m.wr(s.spr_rec+16*k,0);m.wr(s.spr_new+16*k,0);}
  m.wr(s.room_colors+0x1d,0xa0);m.wr(s.belt_frame,0);m.wr(s.video_dirty,0);call('room_redraw');
  const times=[];let bytes=0;
  for(let phase=0;phase<8;phase++){
   for(let i=0;i<256;i++)m.wr(s.tile_changed+i,0);
   m.wr(s.tile_changed+0xe8,1);m.wr(s.belt_shown,phase&1);m.wr(s.dc_pt,1);m.wr(s.fl_skm,0);
   writes=[];watch=true;times.push(call('force_live_t',s.tile_changed>>8));watch=false;bytes+=writes.length;
   if(s.MSX_PLATFORM_ROWS){
    const ink=s.MSX_PLATFORM_INK||1,planes=[4,2,1].flatMap((bit,p)=>ink&bit?[0x8000+p*0x2000]:[]);
    assert.equal(writes.length,planes.length*count,'one row per active plane per platform tile');
    for(const a of writes){assert(planes.includes(a&0xe000),'only the selected ink planes');assert.equal(a&255,s.SCREEN_TOP-s.FIELD_YSHIFT-14*8-2,'only row 2');}
   }
  }
  if(s.MSX_PLATFORM_INK===2||s.MSX_PLATFORM_INK===3){
   // Orange spiders share A000. Queue covered tiles before touching that plane.
   for(let col=2;col<2+count;col++)m.wr(s.PND+14*32+col,8);
   m.wr(s.sprite_dirty,0);m.wr(s.tile_changed+0xe8,1);
   writes=[];watch=true;call('force_live_t',s.tile_changed>>8);watch=false;
   assert.equal(writes.length,0,'covered platform cannot overwrite an enemy');
   assert(m.rd(s.sprite_dirty)&8,'enemy sharing the animated plane must be repainted');
   for(let col=2;col<2+count;col++)assert(m.rd(s.PND+14*32+col)&1,'covered tile is queued');
  }
  results.push({B,cells:count,meanCycles:Math.round(times.reduce((a,b)=>a+b)/times.length),screenBytesPerPhase:bytes/times.length,msx:!!s.MSX_PLATFORM_ROWS});
 }
}
console.log(JSON.stringify(results));if(process.env.OUT)fs.writeFileSync(process.env.OUT,JSON.stringify(results,null,2));
