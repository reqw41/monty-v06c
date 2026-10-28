#!/usr/bin/env node
// Run an existing benchmark with extra sound memory/queue guards. No thresholds
// or reference pixels in the original benchmark are changed.
// POISON_TAIL=1 fills RAM above the loaded image to check initialisation.
'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../..');process.chdir(root);
const E=require('../../vec_emu'),{symbols}=require('../../bench/logic-profile');
const [script,...args]=process.argv.slice(2);if(!script)throw Error('Usage: check_native.js tools/bench/script.js [args]');
const dir=process.env.B||args.find(a=>fs.existsSync(a+'/monty.sym'))||'build/native',s=symbols(dir),mk=E.mk;
const measurements=[];
E.mk=(...params)=>{
  const m=mk(...params);if(process.env.POISON_TAIL==='1')for(let a=Math.max(0xF900,fs.statSync(params[0]).size);a<65536;a++)m.wr(a,(a*73+165)&255);let ready=false,active=false,instr=null,write=null,minStack=0xF900,underruns=0;
  const portOutput=m.io.output.bind(m.io);
  m.io.output=(port,value)=>{
    if(port===8&&value>=192)throw Error('Invalid PIT control '+JSON.stringify({frame:m.frames,pc:m.cpu.pc,value,read:m.rd(s.nes_q_read)|(m.rd(s.nes_q_read+1)<<8),write:m.rd(s.nes_q_write)|(m.rd(s.nes_q_write+1)<<8),count:m.rd(s.nes_q_count),queue:[...Array(48)].map((_,i)=>m.rd(s.nes_queue+i))}));
    return portOutput(port,value);
  };
  const ro=[[s.nes_player_end?0xF600:0,s.nes_player_end||0],[0xE840,s.nes_high_end],[0xE828,s.nes_q_idle],
    [0xEF00,0xF000],[0x100,0x1E0],[8,0x38],[0xFBB7,0xFBD0],[0xFCB1,0xFCD0],[0xFDC8,0xFDD0],[0xFEC8,0xFED0]];
  Object.defineProperty(m,'onInstr',{get:()=>pc=>{
    if(pc===s.L_A5D1)ready=true;
    if(pc===s.nes_tick&&m.rd(s.nes_q_count)>0)active=true;
    if(pc===s.nq_empty&&m.rd(s.nes_q_count)===0&&active&&(m.rd(s.nes_m_wait)||m.rd(s.nes_p_wait)||m.rd(s.nes_n_wait))){underruns++;const isp=m.rd(s.isr_sp)|(m.rd(s.isr_sp+1)<<8),ra=m.rd(isp+4)|(m.rd(isp+5)<<8),near=Object.entries(s).filter(([name,a])=>!name.startsWith('C_')&&a<=ra).sort((a,b)=>b[1]-a[1])[0];if(process.env.MEMORY_ONLY!=='1')throw Error('VI53 queue underrun, physical frame '+m.frames+' interrupted '+ra.toString(16)+' '+JSON.stringify(near));}
    if(ready&&m.cpu.sp>=0xF800&&m.cpu.sp<0xF900)minStack=Math.min(minStack,m.cpu.sp);
    if(instr)instr(pc);
  },set:fn=>{instr=fn;}});
  Object.defineProperty(m,'onWrite',{get:()=>(address,value)=>{
    if(ready&&address>=s.nes_q_read&&address<s.nes_q_read+5&&!(m.cpu.pc>=s.nes_tick&&m.cpu.pc<=s.nes_service)&&!(m.cpu.pc>=s.nes_poll&&m.cpu.pc<=s.nes_player_end))throw Error('Queue pointer overwritten '+JSON.stringify({address,value,pc:m.cpu.pc,frame:m.frames,room:[m.rd(0x71A7),m.rd(0x71A8)],index:m.rd(0x71A5)}));
    if((address>=0xF600&&address<s.nes_player_end)||(address>=0xE828&&address<s.nes_q_idle)||(address>=0xE840&&address<s.nes_high_end)||(ready&&ro.some(([lo,hi])=>address>=lo&&address<hi)))throw Error('Sound memory overwritten at '+address.toString(16)+' PC='+m.cpu.pc.toString(16));
    if(write)write(address,value);
  },set:fn=>{write=fn;}});
  measurements.push(()=>({underruns,min_display_stack:minStack.toString(16)}));return m;
};
process.on('exit',()=>console.log('VI53 guards',JSON.stringify(measurements.map(read=>read()))));
process.argv=[process.argv[0],path.resolve(script),...args];require(path.resolve(script));
