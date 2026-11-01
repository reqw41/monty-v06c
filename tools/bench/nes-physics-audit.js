// Compare complete input traces against unmodified 6502 execution.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-physics-final',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]=2;if(f===100)m.keyboard.matrix[2]=0;m.frame();}
const base=m.memory.bytes.slice(),reference=JSON.parse(fs.readFileSync(process.env.REF||'build/nes-physics-audit/reference.json')),cases=reference.cases||reference;
const tileMap={0:8,1:11,12:144,13:149,14:204,15:16,16:17,17:136,18:137,24:0xd2,28:56,53:232,60:4,63:0xb8};
Object.assign(tileMap,{2:0xd6,3:0xd7,25:0xd3,26:0xd4,27:0xd5,29:0x38,30:0x38,31:0x38,19:0xc8,20:0xc9,21:0xca,22:0xcb,57:0xc0,58:0xb0,59:0xbb});
for(const [start,ids] of [[0x56,[0xc1,0xc2,0xc3,0xc5]],[0x5a,[0xb1,0xb2,0xb3,0xb4]],[0x5e,[0xbc,0xbd,0xbe,0xbf]]])for(let i=0;i<4;i++)tileMap[start+i]=ids[i];
for(let t=0x2d;t<0x35;t++)tileMap[t]=0xe0;
for(let t=0x35;t<0x39;t++)tileMap[t]=0xe8;
for(let t=0x3c;t<0x48;t++)tileMap[t]=t<0x3f?4+(t-0x3c)%3:0xb8+(t-0x3f)%3;
let crossed=null;
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<700000,name+' hung');if(c.pc===s.L_8E0C){crossed={state:m.rd(0x7079),position:[m.rd(0x7305),m.rd(0x7304)-7],target:[m.rd(0x71a7),m.rd(0x71a8)]};c.pc=s.unit_trap;break;}if(c.pc===s.L_8C13)c.pc=s.L_A067;c.instruction();}}
const reports=[];let total=0;
for(const r of cases){m.memory.bytes.set(base);for(let i=192;i<960;i++)m.wr(s.VNT+i,0);
 for(const[row,col,t]of r.terrain){assert(tileMap[t]!==undefined,'unmapped '+t);m.wr(s.VNT+row*32+col,tileMap[t]);}
 for(const[a,v]of[[0x71a6,1],[0x71a7,4],[0x71a8,7],[0x705f,r.bonus?32:0],[0x70ac,178],[0x7049,6],[0x7300,r.y+4],[0x7304,r.y+7],[0x7301,r.x],[0x7305,r.x],[0x7079,{0:0,1:6,64:4,8:3}[r.state]],[0x7076,0],[0x7077,0],[0x7072,0],[0x7075,128],[0x7078,r.direction===1?2:254],[0x707c,r.y+4],[0x70b2,0],[0x7000,0]])m.wr(a,v);
 if(s.nphys_box_reset)call("nphys_box_reset");
 crossed=null;
 const trace=[],diffs=[];
 for(let n=0;n<r.keys.length;n++){
  const k=r.keys[n],key=128|((k&1)?2:0)|((k&2)?8:0)|((k&4)?4:0)|((k&8)?1:0)|((k&128)?64:0);
  m.wr(0x73ee,key);m.wr(0x70ab,n%4);call('L_92DC');call('L_9156');call('hero_state');call('L_8DE8');
  if(crossed)break;
  const state=m.rd(0x7079),q=[m.rd(0x7305),m.rd(0x7304)-7,state,m.rd(0x7049)],want=r.trace[n];if(want[2]&32)break; // NES waits for its room decoder; boundary behavior has a separate suite.
  trace.push(q);total++;
  const dead=state>=8,nesdead=!!(want[2]&20),climb=state===3||state===4||state===5,nesclimb=!!(want[2]&200);
  if((!dead&&!nesdead&&(q[0]!==want[0]||q[1]!==want[1]))||dead!==nesdead||climb!==nesclimb)diffs.push({step:n,want,got:q});
  if(dead||nesdead||q[0]<6||q[0]>234||q[1]>210)break;
 }
 reports.push({escaped:crossed,location:r.location,name:r.name,steps:trace.length,differences:diffs.length,first:diffs[0],trace});
}
const out={B,scenarios:reports.length,steps:total,mismatching:reports.filter(q=>q.differences).length,reports};
fs.writeFileSync(process.env.OUT||'build/nes-physics-audit/native.json',JSON.stringify(out,null,2)+'\n');console.log(JSON.stringify({...out,reports:reports.filter(q=>q.differences).map(({trace,...q})=>q)}));
if(process.env.VERIFY)assert.equal(out.mismatching,0,'NES physics mismatch');
