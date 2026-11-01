// Cost-only colour proposals, patched in emulator RAM; no ROM is changed.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/snake-delta-check',s=symbols(B),results=[];
for(const t of [0xe0,0xd2])for(const proposed of [false,true]){
 const m=E.mk(B+'/monty.bin');for(let f=0;f<320;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
 if(proposed&&t===0xd2){let found=0;for(let p=s.nes_color_modes;p<s.nes_color_modes_end-1;p++)if(m.rd(p)===0x0e&&m.rd(p+1)===5){m.wr(p+1,4);found++;}assert.equal(found,1,'red fire mode patched only in RAM');}
 let watch=false,writes=0,planes=new Set();
 m.onInstr=pc=>{if(proposed&&t===0xe0&&pc===s.fsm_other_belt&&m.rd(s.rr_t)===0xe0&&m.cpu.regs[1])m.cpu.regs[1]=1;};
 m.onWrite=a=>{if(watch&&a>=0x8000&&a<0xe000){writes++;planes.add(a&0xe000);}};
 function call(name,a=0){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;c.regs[7]=a;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);let cycles=0;
  for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');if(m.onInstr)m.onInstr(c.pc);c.instruction();cycles+=c.vcycles;}return cycles;}
 for(let i=0;i<960;i++)m.wr(s.VNT+i,0);for(let x=2;x<10;x++)m.wr(s.VNT+14*32+x,t);
 for(let k=0;k<6;k++){m.wr(0x7303+4*k,0);m.wr(s.spr_rec+16*k,0);m.wr(s.spr_new+16*k,0);}
 m.wr(s.room_colors+0x1c,0x40);m.wr(s.video_dirty,0);call('room_redraw');const times=[];
 for(let phase=0;phase<4;phase++){
  for(let i=0;i<256;i++)m.wr(s.tile_changed+i,0);m.wr(s.tile_changed+t,1);m.wr(t===0xe0?s.belt_shown:s.fire_shown,phase);
  m.wr(s.dc_pt,1);m.wr(s.fl_skm,0);watch=true;times.push(call('force_live_t',s.tile_changed>>8));watch=false;
 }
 results.push({tile:t.toString(16),colour:t===0xe0?(proposed?'white 1':'cyan 6'):(proposed?'skin 2':'red 3'),cells:8,meanCycles:Math.round(times.reduce((a,b)=>a+b)/times.length),screenBytesPerPhase:writes/4,planes:[...planes].map(a=>a.toString(16))});
}
console.log(JSON.stringify({B,proposalsOnly:true,results}));
