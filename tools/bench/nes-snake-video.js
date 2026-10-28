// Original NES snake: faces Joe, has two poses and cycles colour with amulet.
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.sp=0x73be;c.pc=s[name];m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');c.instruction();}}
m.wr(0x71a6,1);m.wr(0x71a7,1);m.wr(0x71a8,9);m.wr(0x7049,6);m.wr(0x70b3,0);m.wr(s.nes_q_idle,1);
for(let i=0;i<198;i++)m.wr(0x70c0+i,0);for(let i=0;i<7;i++)m.wr(0x71b2+i,255);
for(let i=0;i<8;i++)m.wr(0x7300+i,[75,120,52,6,78,120,152,11][i]);for(let i=0x7308;i<0x7329;i++)m.wr(i,0);
call('L_A067');assert.equal(m.rd(s.nf_snake_count),1,'one visible snake');
const pos=s.VNT+26*32+29;assert.equal(m.rd(pos),0xA5,'snake initially faces Joe to the left');
m.wr(0x7301,240);m.wr(0x7305,240);call('nes_snake_face_all');assert.equal(m.rd(pos),0xA0,'snake turns right toward Joe');
call('nes_snake_palette');assert.equal(m.rd(s.pal+10),32,'ordinary green snake');
m.wr(s.nes_amulet_ticks,1);for(const [frame,color] of [[0,234],[4,159],[8,0],[12,114]]){m.wr(s.frames,frame);call('nes_snake_palette');assert.equal(m.rd(s.pal+10),color,`amulet colour at frame ${frame}`);}
const base=s.raw_anim+12*4;assert(Array.from({length:8},(_,i)=>m.rd(base+4*i)!==m.rd(base+4*i+1)).some(Boolean),'two source poses');
for(let i=0;i<5;i++)call('nes_snake_step');assert.equal(m.rd(s.snake_frame),1,'second animation pose');assert(m.rd(s.video_dirty)&s.DIRTY_SNAKE,'snake redraw requested');
console.log(JSON.stringify({B,room:'1,9',facings:['left','right'],poses:2,amuletColors:[234,159,0,114]}));
