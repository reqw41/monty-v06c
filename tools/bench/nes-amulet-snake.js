// NES object 09 in the room left of the entrance grants timed enemy protection.
const assert=require('node:assert/strict'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');
// код столкновений NES переносится при загрузке (nes_hit.asm) — стенд без загрузки делает это сам
if(s.nes_hit_source!==undefined){const cp=(src,dst,n)=>{for(let i=0;i<n;i++)m.wr(dst+i,m.rd(src+i));};
 cp(s.nes_hit_source,s.NES_HIT_CODE,s.nes_hit_source_mid-s.nes_hit_source);cp(s.nes_hit_source_mid,s.NES_SNAKE_CODE,s.nes_hit_source_end-s.nes_hit_source_mid);}
const joeBox=()=>{if(s.nphys_box_left!==undefined){m.wr(s.nphys_box_left,0);m.wr(s.nphys_box_top,2);m.wr(s.nphys_box_right,14);}};
function call(name,a=0){const c=m.cpu;c.iff=false;c.iff_pending=0;c.sp=0x73be;c.pc=s[name];c.regs[7]=a;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');c.instruction();}}
function room(){m.wr(0x71a6,1);m.wr(0x71a7,0);m.wr(0x71a8,9);m.wr(0x7049,6);m.wr(0x7079,0);m.wr(0x704a,0);m.wr(0x70b3,0);m.wr(s.nes_q_idle,1);
 for(let i=0;i<198;i++)m.wr(0x70c0+i,0);for(let i=0;i<7;i++)m.wr(0x71b2+i,255);
 for(let i=0;i<8;i++)m.wr(0x7300+i,[75,120,52,6,78,120,152,11][i]);
 for(let i=0x7308;i<0x7329;i++)m.wr(i,0);call('L_A067');}
const ticks=()=>m.rd(s.nes_amulet_ticks)|(m.rd(s.nes_amulet_ticks+1)<<8);
room();m.wr(0x71b0,0x58);m.wr(0x71b1,0x01);call('L_901B',0x53);
assert.equal(m.rd(0x71b2),0x53);assert.equal(ticks(),427);
for(const p of [0x7300,0x7304]){m.wr(p,90);m.wr(p+1,154);}joeBox();
call('L_8F5F');assert.equal(m.rd(0x7049),6,'amulet protects from snake');assert.equal(m.rd(0x7079),0);
// Protection survives the doorway and also covers the moving skull in 0,10.
m.wr(0x71a8,10);call('L_A067');
const enemyColor=m.rd(0x730b);assert(enemyColor,'moving enemy present');
m.wr(0x7300,m.rd(0x7308));m.wr(0x7301,m.rd(0x7309));m.wr(0x7304,m.rd(0x7308));m.wr(0x7305,m.rd(0x7309));joeBox();
for(const name of [m.rd(0x730a),0x2c]){m.wr(0x730a,name);call('L_91E5');assert.equal(m.rd(0x7049),6,'amulet protects from moving skull/spider');assert.equal(m.rd(0x730b),enemyColor);}
call('nes_amulet_step');
assert.equal(ticks(),426);
// The ordinary game process advances the timer, then the item disappears.
m.wr(0x7300,40);m.wr(0x7301,40);m.wr(0x7304,43);m.wr(0x7305,40);
for(let i=0;i<4;i++)m.wr(0x730b+4*i,0);
for(let i=0;i<426;i++)call('nes_amulet_step');
assert.equal(ticks(),0);assert.equal(m.rd(0x71b2),255,'expired amulet leaves inventory');
m.wr(0x71a8,9);call('L_A067');
for(const p of [0x7300,0x7304]){m.wr(p,90);m.wr(p+1,154);}joeBox();
call('L_8F5F');assert.equal(m.rd(0x7049),5,'snake is hazardous after expiry');assert.equal(m.rd(0x7079),8);
console.log(JSON.stringify({B,room:'0,9',object:'NES amulet 09',protectionSteps:427,snakeDuring:'safe',enemyDuring:'safe',snakeAfter:'fatal'}));
