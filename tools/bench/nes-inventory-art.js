// Inventory keeps logical MSX IDs; its pictures must match the NES world art.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),ref=require('./nes-video-ref');
const B=process.env.B||'build/nes-platform-momentum',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]=2;if(f===100)m.keyboard.matrix[2]=0;m.frame();}
function call(n){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[n];c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let i=0;c.pc!==s.unit_trap;i++){assert(i<1000000,n+' hung');c.instruction();}}
// Exercise actual collision/pickup in NES room 10, not a direct inventory write.
for(let a=0x70c0;a<0x7186;a++)m.wr(a,0);for(let a=0x71b2;a<=0x71b7;a++)m.wr(a,255);
for(const[a,v]of[[0x71a6,1],[0x71a7,2],[0x71a8,8],[0x705f,0],[s.nes_q_idle,1]])m.wr(a,v);
call('L_A067');for(const[a,v]of[[0x7300,68],[0x7304,71],[0x7301,140],[0x7305,140],[0x7079,0],[0x7078,2]])m.wr(a,v);
assert.equal(m.rd(s.VNT+10*32+18),0x96,'real sword present');call('proc_8F5F');
assert.equal(m.rd(0x71b2),0x91,'sword stored under its combat ID');
assert.equal(m.rd(s.VNT+10*32+18),0,'sword removed from field');call('L_A067');
assert.equal(m.rd(s.VNT+10*32+18),0,'sword stays taken after room reload');
let cases=0,bytes=0;
for(let floor=0;floor<9;floor++)for(const[id,tiles]of[[0x91,[0x96,0x97,0x9a,0x9b]],[0x8c,[0xa8,0xae,0xa9,0xaf]]])for(let slot=0;slot<5;slot++){
 m.wr(0x71a7,floor);m.wr(s.fire_frame,0);m.wr(s.fire_shown,0);call('style_palette');
 for(let a=0x71b2;a<=0x71b7;a++)m.wr(a,255);
 for(let i=0;i<slot;i++)m.wr(0x71b2+i,[0x62,0x58,0x5d][i%3]);m.wr(0x71b2+slot,id);call('L_A548');call('nf_draw_hud');
 let ink=0;
 for(let part=0;part<4;part++){
  const col=1+2*slot+part%2,row=2+(part>>1);assert.equal(m.rd(s.VNT+row*32+col),tiles[part],'HUD NES tile');
  const want=ref.cell(m,s,tiles[part],0,0);
  for(let plane=0;plane<3;plane++)for(let y=0;y<8;y++){
   const address=0x8000+8192*plane+256*col+s.SCREEN_TOP-s.HUD_YSHIFT-row*8-y;
   assert.equal(m.rd(address),want[plane*8+y],'HUD item matches independently referenced world art');ink|=want[plane*8+y];bytes++;
  }
 }
 assert(ink,'inventory icon cannot be blank');assert.equal(m.rd(0x71b2+slot),id,'drawing preserves logical item ID');cases++;
}
console.log(JSON.stringify({B,realSwordPickup:true,persistence:true,logicalSword:'91',hudSwordTiles:['96','97','9A','9B'],torchUpperHalf:true,cases,comparedBytes:bytes}));
