// Compare unmodified NES boundary decisions, then jump above the HUD in real room 12.
'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-physics-audit-candidate',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]=2;if(f===100)m.keyboard.matrix[2]=0;m.frame();}
const base=m.memory.bytes.slice(),ref=JSON.parse(fs.readFileSync('build/nes-physics-audit/boundary-reference.json'));let exit=null,intercept=true;
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<700000,name+' hung');if(c.pc===s.L_8E0C){exit={row:m.rd(0x71a7),col:m.rd(0x71a8)};if(intercept){c.pc=s.unit_trap;break;}}
 if(c.pc===s.L_8C13)c.pc=s.L_A067;c.instruction();}}
function setup(x,y,state){m.memory.bytes.set(base);for(let i=192;i<960;i++)m.wr(s.VNT+i,0);
 for(const[a,v]of[[0x71a6,1],[0x71a7,4],[0x71a8,7],[0x71a5,27],[0x705f,0],[0x7300,y+4],[0x7304,y+7],[0x7301,x],[0x7305,x],[0x7079,state],[0x7076,0],[0x7077,0],[0x7072,0],[0x7075,128],[0x7078,2],[0x73ee,128],[s.nes_q_idle,1]])m.wr(a,v);call('nphys_box_reset');exit=null;}
let comparisons=0;
for(const r of ref.cases){setup(r.x,r.y,({0:0,1:6,2:2,8:3,64:4,128:5})[r.state]);call('L_8DE8');assert.equal(!!exit,r.exit,JSON.stringify(r));
 if(exit){const index=(exit.row*exit.row+3*exit.row+exit.col-8)&255;assert.deepEqual([index,exit.row+1],r.target,'NES target room/floor');}comparisons++;}
const entries=[];intercept=false;
for(const r of ref.entries){const x=r.side===1?239:r.side===2?1:116,y=r.side===3?214:r.side===4?36:100;setup(x,y,r.side===4?3:0);call('L_8DE8');const got=[m.rd(0x7305),m.rd(0x7304)-7];assert.deepEqual(got,r.position,'NES entry '+r.side);entries.push({side:r.side,position:got});}
intercept=true;let deadCases=0;
for(const state of [8,9,10])for(const[x,y]of[[0,20],[240,20],[116,215]]){setup(x,y,state);call('L_8DE8');assert.equal(exit,null,'death must not change rooms');deadCases++;}
const v=E.mk(B+'/monty.bin'),check=require('./framecheck')(v,s);let steps=0,active=false,jumped=false,done=null,minY=255;const trace=[];
v.onInstr=pc=>{check.instruction(pc);if(pc!==s.L_A5D1)return;steps++;
 if(steps===80){for(const[a,b]of[[0x71a6,1],[0x71a7,2],[0x71a8,10],[0x705f,0],[0x7300,51],[0x7304,54],[0x7301,80],[0x7305,80],[0x7079,0],[0x7076,0],[0x7077,0],[0x7072,0],[0x7075,128],[0x7078,2],[0x707c,51]])v.wr(a,b);for(let a=0x70c0;a<0x7186;a++)v.wr(a,255);const c=v.cpu;c.sp-=2;v.wr(c.sp,pc&255);v.wr(c.sp+1,pc>>8);c.pc=s.L_A067;active=true;return;}
 if(!active)return;assert.equal(v.rd(0x71a5),12,'a jump must stay in room 12');const y=v.rd(0x7304),state=v.rd(0x7079);minY=Math.min(minY,y);trace.push([v.frames,v.rd(0x7305),y,state]);
 if(!jumped){v.keyboard.matrix[0]=0;v.keyboard.matrix[7]=128;if(state===2){jumped=true;v.keyboard.matrix[7]=0;}}
 else if(done===null&&state<=1&&y===54){done=v.frames;v.keyboard.matrix[7]=0;}
};
for(let f=0;f<1200&&(done===null||v.frames-done<8);f++){if(f===10)v.keyboard.matrix[2]=2;if(f===100)v.keyboard.matrix[2]=0;v.frame();}
assert(jumped&&done!==null,'real keyboard jump returns to its original platform');assert(minY<44,'the tested jump really crosses the upper room threshold');const pixels=check.result();assert.equal(pixels.bad,0,'jump near HUD must not leave artifacts');
const result={B,decisions:comparisons,entries,deadCases,jumpRoom:12,minNativeY:minY,minNesY:minY-7,finishedFrame:done,pixels};
if(process.env.OUT)fs.writeFileSync(process.env.OUT,JSON.stringify({result,trace},null,2)+'\n');console.log(JSON.stringify(result));
