// Original NES empty fall / automatic rope grab, including the stationary hold.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]=2;if(f===100)m.keyboard.matrix[2]=0;m.frame();}
const base=m.memory.bytes.slice();
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');c.instruction();}}
const cases=JSON.parse(fs.readFileSync('build/nes-treasure/motion-reference.json'));
for(const r of cases){
 m.memory.bytes.set(base);
 for(let i=192;i<960;i++)m.wr(s.VNT+i,0);
 if(r.rope)for(let row=12;row<18;row++)m.wr(s.VNT+row*32+r.column,0x95);
 for(const [a,v]of [[0x705f,32],[0x7079,6],[0x7076,0],[0x7077,0],[0x7072,0],[0x7300,41],[0x7304,44],[0x7301,r.column*8-4],[0x7305,r.column*8-4],[0x73ee,128],[0x73ef,0],[0x70ac,178]])m.wr(a,v);
 for(const want of r.trace){call('L_9156');call('hero_state');call('L_8DE8');
  // MSX layer-2 collision anchor is seven pixels below NES's top anchor.
  const state=m.rd(0x7079);assert([4,6].includes(state));
  assert.deepEqual([m.rd(0x7305),m.rd(0x7304)-7,state===4?64:1],want,JSON.stringify([r.column,r.rope]));}
 for(const name of ['nt_fall_speed','nes_chain_catch'])for(let i=0;i<8;i++)assert.equal(m.rd(s[name]+i),m.img[s[name]+i],'permanent motion code');
}
// All NES fields use its three-pixel fall; explicit ordinary rope catches stay.
for(const bonus of [0,32]){m.wr(0x705f,bonus);m.wr(0x7072,0);m.wr(0x7076,254);call('nt_fall_speed');assert.equal(m.cpu.regs[1],3);assert.equal(m.cpu.regs[0],bonus?254:0);
 m.wr(0x7076,0);m.wr(0x73ee,128);call('nes_chain_catch');assert.equal(m.cpu.store_flags()&1,1);}
console.log(JSON.stringify({B,originalNESCases:cases.length,comparedSteps:cases.length*35,bonusFall:3,verticalRopeCatch:true,noInputHold:true,ordinaryFall:3}));
const controls=JSON.parse(fs.readFileSync('build/nes-treasure/control-reference.json'));
const input={hold:128,up:129,down:132,left:136,right:130};let maxRopeError=0;
for(const r of controls){
 m.memory.bytes.set(base);for(let i=192;i<960;i++)m.wr(s.VNT+i,0);
 for(let row=12;row<18;row++)m.wr(s.VNT+row*32+15,0x95);
 for(const [a,v]of [[0x705f,32],[0x7079,4],[0x7076,0],[0x7077,0],[0x7072,0],[0x7300,104],[0x7304,107],[0x7301,116],[0x7305,116],[0x73ee,input[r.name]],[0x70ac,178],[0x7075,128]])m.wr(a,v);
 for(let n=0;n<r.trace.length;n++){
  m.wr(0x70ab,n%4);call('L_9156');call('hero_state');call('L_8DE8');
  assert.equal(m.rd(0x7079),4,'rope must hold: '+r.name);
  assert.equal(m.rd(0x7305),r.trace[n][0],'no sideways movement without jumping');
  const error=Math.abs(m.rd(0x7304)-7-r.trace[n][1]);maxRopeError=Math.max(maxRopeError,error);
  assert(error<=1,'rope endpoint differs by more than native collision rounding: '+r.name);
 }
}
console.log(JSON.stringify({B,ropeControls:controls.length,controlSteps:controls.length*80,upperEndHolds:true,lowerEndHolds:true,maxRopeEndpointError:maxRopeError}));
