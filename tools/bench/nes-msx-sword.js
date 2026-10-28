// Original MSX rule retained in NES presentation: sword defeats moving enemies,
// while a stationary snake is a hazardous map tile.
const assert=require('node:assert/strict'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.sp=0x73be;c.pc=s[name];m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');c.instruction();}}
function room(col){m.wr(0x71a6,1);m.wr(0x71a7,0);m.wr(0x71a8,col);m.wr(0x7049,6);m.wr(0x7079,0);m.wr(0x704a,0);m.wr(0x70b3,0);m.wr(s.nes_q_idle,1);
 for(let i=0;i<198;i++)m.wr(0x70c0+i,0);for(let i=0;i<7;i++)m.wr(0x71b2+i,255);
 for(let i=0;i<8;i++)m.wr(0x7300+i,[75,120,52,6,78,120,152,11][i]);
 for(let i=0x7308;i<0x7329;i++)m.wr(i,0);call('L_A067');m.wr(0x71b2,0x91);}
room(10);assert(m.rd(0x730b)>0,'moving enemy present');
m.wr(0x7300,m.rd(0x7308));m.wr(0x7301,m.rd(0x7309));call('L_91E5');
assert.equal(m.rd(0x730b),0,'sword defeats moving enemy');assert.equal(m.rd(0x7049),6);assert.equal(m.rd(0x71b2),255,'sword consumed');
room(9);for(const p of [0x7300,0x7304]){m.wr(p,90);m.wr(p+1,154);}call('L_8F5F');
assert.equal(m.rd(0x7079),8,'snake kills Joe');assert.equal(m.rd(0x7049),5);assert.equal(m.rd(0x71b2),0x91,'sword does not affect stationary snake');
console.log(JSON.stringify({B,movingEnemy:'defeated',snake:'hazard',swordAgainstSnake:'retained'}));
