// Assert the actual VRAM planes used by the new palette allocation.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<320;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
const boot=m.memory.bytes.slice(),results=[];let watch=false,writes=[];
m.onWrite=a=>{if(watch&&a>=0x8000&&a<0xe000)writes.push(a);};
function call(name,a=0){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;c.regs[7]=a;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);let cycles=0;for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');c.instruction();cycles+=c.vcycles;}return cycles;}
for(const [t,plane]of [[0xe0,0xc000],[0xd2,0xa000],[0xd3,0xa000],[0xd4,0xa000],[0xd5,0xa000],[0xa1,0x8000],[0xa2,0x8000]]){
 m.memory.bytes.set(boot);for(let i=0;i<960;i++)m.wr(s.VNT+i,0);for(let col=2;col<10;col++)m.wr(s.VNT+14*32+col,t);
 for(let k=0;k<6;k++){m.wr(0x7303+4*k,0);m.wr(s.spr_rec+16*k,0);m.wr(s.spr_new+16*k,0);}
 m.wr(s.room_colors+0x1c,0x40);m.wr(s.video_dirty,0);call('room_redraw');
 const samples=[];
 for(let phase=0;phase<4;phase++){
  for(let i=0;i<256;i++)m.wr(s.tile_changed+i,0);m.wr(s.tile_changed+t,1);m.wr(t===0xe0?s.belt_shown:t>=0xa0&&t<=0xa7?s.snake_shown:s.fire_shown,t>=0xa0&&t<=0xa7?phase&1:phase);m.wr(s.dc_pt,1);m.wr(s.fl_skm,0);
  writes=[];watch=true;const cycles=call('force_live_t',s.tile_changed>>8);watch=false;
  assert(writes.length>0);assert(writes.every(a=>(a&0xe000)===plane),'unexpected plane for '+t.toString(16));samples.push({cycles,writes:writes.length});
 }
 results.push({tile:t.toString(16),cells:8,plane:plane.toString(16),meanCycles:Math.round(samples.reduce((n,q)=>n+q.cycles,0)/4),writes:samples[0].writes});
}
console.log(JSON.stringify({B,results}));
