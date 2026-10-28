#!/usr/bin/env node
// Exhaustive native emitter paths, actual OUT writes and cycle bound, plus an
// independent frequency/one-shot integration check of the WAV renderer.
'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../../..'));
const E=require('../../vec_emu'),{symbols}=require('../../bench/logic-profile');
const {invoke,Timer,render}=require('./render_vi53');
const B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');for(let f=0;f<200;f++)m.frame();
assert.equal(m.rd(s.pal+14),255);assert.equal(m.rd(s.pal+15),255);
assert.equal(m.palette()[14],E.palColor(255));assert.equal(m.palette()[15],E.palColor(255));
for(const base of [0x8000,0xA000,0xC000])assert.equal(m.rd(base+(s.MENU_POS%32)*256+(s.SCREEN_TOP??0xDF)-Math.floor(s.MENU_POS/32)*8),0x70,'menu glyph S');
let max=0,cases=0;
for(const wrap of [false,true])for(const a of ['hold','mute','tone'])for(const b of ['hold','mute','tone'])for(const c of ['hold','mute','tone','click']){
  const start=s.nes_queue+(wrap?36:0),expected=[];
  m.wr(s.snd_busy,0);m.wr(s.nes_q_read,start&255);m.wr(s.nes_q_read+1,start>>8);m.wr(s.nes_q_count,1);
  [a,b,c].forEach((kind,k)=>{
    const divider=kind==='click'?256:kind==='tone'?1500+k*400:0;
    const control=kind==='hold'?0:0x30+64*k+(kind==='tone'?6:0);
    const flags=kind==='hold'?0x42:kind==='mute'?2:3;
    const p=start+4*k;m.wr(p,divider&255);m.wr(p+1,divider>>8);m.wr(p+2,flags);m.wr(p+3,control);
    if(kind!=='hold'){expected.push(8,control);if(kind!=='mute')expected.push(11-k,divider&255,11-k,divider>>8);}
  });
  m.taps.length=0;const cycles=invoke(m,'nes_tick');max=Math.max(max,cycles);cases++;
  assert.deepEqual([...m.taps],expected,[a,b,c,wrap].join('/'));
  assert.equal(m.rd(s.nes_q_count),0);
  assert.equal(m.rd(s.nes_q_read)|(m.rd(s.nes_q_read+1)<<8),wrap?s.nes_queue:start+12);
}
const probe=E.mk(B+'/monty.bin');let callAddress;
for(let a=s.isr;a<s.frame_wait;a++)if(probe.rd(a)===0xCD&&(probe.rd(a+1)|(probe.rd(a+2)<<8))===s.nes_tick){callAddress=a;break;}
assert.notEqual(callAddress,undefined,'IRQ CALL not found');probe.cpu.pc=callAddress;probe.cpu.sp=0x73C0;probe.cpu.instruction();const callCycles=probe.cpu.vcycles;
assert(max+callCycles<=600,'emitter plus CALL exceeds 600 Vector cycles: '+(max+callCycles));
const t=new Timer();t.write(8,0x30,0);assert.equal(t.integral(0,1),0);
t.write(9,0,0);t.write(9,1,0); // counter 2: deliberately not enabled
const click=new Timer();click.write(8,0xB0,0);click.write(9,0,0);click.write(9,1,0);
assert(Math.abs(click.integral(0,.001)-(.001-256/1500000))<1e-12);
const tone=render([[0,8,0x36],[0,11,220],[0,11,5]],1); // 1500 -> 1 kHz
let crossings=0;for(let i=4410;i<tone.samples.length;i++)if(tone.samples[i-1]<=0&&tone.samples[i]>0)crossings++;
assert(Math.abs(crossings/.9-1000)<2,'wrong fundamental frequency');
const decoder={};
for(const id of ['title','pyramid','treasure']){
  const v=E.mk(B+'/monty.bin');for(let f=0;f<200;f++)v.frame();
  if(id!=='title')invoke(v,'nes_begin');
  for(let a=s.nes_m_ptr;a<s.nes_m_ptr+32;a++)v.wr(a,0);
  v.wr(s.nes_pitch_page,id==='title'?0xEC:0xE8);
  const order=s['nes_'+id+'_order'],pointer=v.rd(order)|(v.rd(order+1)<<8);
  const word=(a,n)=>{v.wr(a,n&255);v.wr(a+1,n>>8);};
  word(s.nes_m_ptr,pointer);word(s.nes_m_order,order+2);word(s.nes_m_start,id==='title'?s.nes_title_loop_order:order);v.wr(s.nes_m_wait,1);v.wr(s.nes_loop,id==='title'?1:0);
  let peak=0,sum=0;const frames={title:4267,pyramid:856,treasure:536}[id];
  for(let f=0;f<frames;f++){const cycles=invoke(v,'nes_prepare_core');peak=Math.max(peak,cycles);sum+=cycles;}
  decoder[id]={max_cycles:peak,mean_cycles:sum/frames};
}
// A cue is called from hero transition logic with BC still holding movement.
// Test native register/flag preservation without the restoring invoke wrapper.
invoke(m,'nes_begin');
for(const name of ['nes_pyramid','nes_treasure']){
  const cpu=m.cpu;cpu.regs.splice(0,8,0x12,0x34,0x56,0x78,0x9A,0xBC,0,0xDE);cpu.retrieve_flags(0xD7);
  const expected=[...cpu.regs],flags=cpu.store_flags();cpu.iff=false;cpu.iff_pending=0;cpu.sp=0x73BE;
  m.wr(cpu.sp,s.unit_trap&255);m.wr(cpu.sp+1,s.unit_trap>>8);cpu.pc=s[name];
  for(let n=0;cpu.pc!==s.unit_trap;n++){assert(n<10000,name+' did not return');cpu.instruction();}
  assert.deepEqual([...cpu.regs],expected,name+' clobbered registers');assert.equal(cpu.store_flags(),flags,name+' clobbered flags');
}
let poleError=0,lastPole=0;
m.wr(s.nes_pole,1);m.wr(0x7079,5);
for(let y=0;y<256;y++){
  m.wr(0x7300,y);invoke(m,'nes_update_pole');
  const divider=m.rd(s.nes_pole_div)|(m.rd(s.nes_pole_div+1)<<8);
  const expected=Math.round(1500000*16*(257+y)/1789773);
  poleError=Math.max(poleError,Math.abs(divider-expected));
  assert(divider>lastPole,'pole pitch must decrease monotonically with Y');lastPole=divider;
}
assert(poleError<=2,'pole frequency error exceeds two timer counts');
m.wr(0x7079,4);invoke(m,'nes_update_pole');assert.equal(m.rd(s.nes_pole),0,'pole must stop when Joe catches a ladder');
assert.equal(m.rd(s.nes_p_wait),1,'pole release must start its ending');
const result={menu_palette_pairs:true,emitter_cases:cases,emitter_max_cycles:max,call_cycles:callCycles,with_call_cycles:max+callCycles,frequency_hz:crossings/.9,one_shot:true,cue_registers_preserved:true,pole_y_cases:256,pole_max_divider_error:poleError,decoder};
fs.writeFileSync((process.argv[2]||'build/nes/music/vi53')+'/emitter-verification.json',JSON.stringify(result,null,2)+'\n');
console.log(result);
