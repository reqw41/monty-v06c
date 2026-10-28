#!/usr/bin/env node
// Execute the actual native IRQ in vec_emu; render its 8253 port writes offline.
'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../..');process.chdir(root);
const E=require('../../vec_emu'),{symbols}=require('../../bench/logic-profile'),{wav}=require('./apu');
const dir=process.env.B||'build/native',s=symbols(dir),out=process.argv[2]||'build/nes/music/vi53';
const conversion=JSON.parse(fs.readFileSync(out+'/conversion.json'));
fs.mkdirSync(out,{recursive:true});

function invoke(m,name,{a=0,b=0,hl=0}={}) {
  const c=m.cpu,old={pc:c.pc,sp:c.sp,iff:c.iff,pending:c.iff_pending,flags:c.store_flags(),regs:[...c.regs]};
  const hook=m.onInstr;m.onInstr=null;
  c.regs[7]=a;c.regs[0]=b;c.regs[4]=hl>>8;c.regs[5]=hl&255;c.iff=false;c.iff_pending=0;
  c.sp=0x73BE;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);c.pc=s[name];
  assert.notEqual(c.pc,undefined,name);
  let cycles=0;
  for(let n=0;c.pc!==s.unit_trap;n++) {assert(n<100000,'native call did not return: '+name);c.instruction();cycles+=c.vcycles;}
  c.pc=old.pc;c.sp=old.sp;c.iff=old.iff;c.iff_pending=old.pending;c.retrieve_flags(old.flags);c.regs.splice(0,8,...old.regs);m.onInstr=hook;
  return cycles;
}

class Timer {
  constructor(){this.channels=Array.from({length:3},()=>({mode:0,count:0,start:0,latch:null,running:false}));}
  write(port,value,time){
    if(port===8){const k=value>>6;if(k===3)return;const c=this.channels[k];c.mode=(value>>1)&7;c.latch=null;c.running=false;c.start=time;return;}
    const c=this.channels[11-port];
    if(c.latch===null)c.latch=value;
    else {c.count=(c.latch|(value<<8))||65536;c.latch=null;c.running=true;c.start=time;}
  }
  area(c,time){
    if(!c.running)return c.mode===3?time:0;
    const t=Math.max(0,time-c.start);
    if(c.mode===0)return Math.max(0,t-c.count/1500000);
    assert.equal(c.mode,3,'unsupported timer mode');
    const period=c.count/1500000,high=Math.ceil(c.count/2)/1500000,n=Math.floor(t/period);
    return n*high+Math.min(high,t-n*period);
  }
  integral(start,end){return this.channels.reduce((sum,c)=>sum+this.area(c,end)-this.area(c,start),0);}
}

function render(events,seconds){
  const rate=44100,samples=new Float32Array(Math.ceil(seconds*rate)),timer=new Timer();
  let event=0,dc=0,peak=0,squares=0;const highpass=Math.exp(-2*Math.PI*90/rate);
  for(let i=0;i<samples.length;i++) {
    const end=(i+1)/rate;let time=i/rate,area=0;
    while(event<events.length&&events[event][0]<=end){const [at,port,value]=events[event++];area+=timer.integral(time,Math.max(time,at));time=Math.max(time,at);timer.write(port,value,time);}
    area+=timer.integral(time,end);
    const raw=area*rate*.28;dc=highpass*dc+(1-highpass)*raw;const value=raw-dc;
    samples[i]=value;peak=Math.max(peak,Math.abs(value));squares+=value*value;
  }
  return {samples,rate,peak,rms:Math.sqrt(squares/samples.length)};
}

function prepare(id){
  const m=E.mk(dir+'/monty.bin');for(let f=0;f<200;f++)m.frame();
  assert(m.cpu.pc>=s.nm_wait&&m.cpu.pc<s.nes_begin,'not in native menu');
  if(id!=='title')invoke(m,'nes_begin');
  for(let a=s.nes_m_ptr;a<s.nes_m_ptr+32;a++)m.wr(a,0);
  m.wr(s.nes_m1,64);m.wr(s.nes_m2,64);m.wr(s.nes_pitch_page,0xE8);invoke(m,'vi_off');
  return m;
}

function capture(id,options={}) {
  const m=prepare(id),track=conversion.tracks[id],n=options.frames||((id==='title'||options.loop)?2*track.frames:track.frames);
  if(!['title','pyramid','treasure'].includes(id)){invoke(m,'nes_queue_reset');invoke(m,'nes_poll');}
  if(['title','pyramid','treasure'].includes(id)){
    m.wr(s.nes_pitch_page,id==='title'?0xEC:0xE8);
    if(options.loop&&id!=='title'){invoke(m,'nes_'+id);assert.equal(m.rd(s.nes_loop),1,'game cue must loop');}
    else invoke(m,'nes_select',{hl:s['nes_'+id+'_order'],a:id==='title'?1:0});
    if(id==='title'){m.wr(s.nes_m_start,s.nes_title_loop_order&255);m.wr(s.nes_m_start+1,s.nes_title_loop_order>>8);}
  } else if(id!=='sfx_pole'){
    const noise=id==='sfx_land'||id==='sfx_death',p=s['nes_'+id];
    const pointer=noise?s.nes_n_ptr:s.nes_p_ptr;m.wr(pointer,p&255);m.wr(pointer+1,p>>8);m.wr(noise?s.nes_n_wait:s.nes_p_wait,1);m.wr(s.nes_q_idle,0);
  }
  const events=[],histogram={},writes=m.io.output.bind(m.io),snapshots=[];
  const pit=new Timer();let frame=0,total=0,entry=null,max=0,peakFrame=0,underruns=0;
  m.io.output=(port,value)=>{
    if(port>=8&&port<=11){const time=(frame+(m.v06c.between||0)/59904)/50;events.push([time,port,value]);pit.write(port,value,time);}
    return writes(port,value);
  };
  m.onInstr=pc=>{
    total+=m.cpu.vcycles||0;
    if(pc===s.nq_empty&&m.rd(s.nes_q_count)===0&&(m.rd(s.nes_m_wait)||m.rd(s.nes_p_wait)||m.rd(s.nes_n_wait)))underruns++;
    if(entry&&pc===entry.ra&&m.cpu.sp===entry.sp+2){const cycles=total-entry.time;histogram[cycles]=(histogram[cycles]||0)+1;if(cycles>max){max=cycles;peakFrame=frame;}entry=null;}
    if(pc===s.nes_tick){const sp=m.cpu.sp;entry={time:total,sp,ra:m.rd(sp)|(m.rd(sp+1)<<8)};}
  };
  for(frame=0;frame<n;frame++){
    if(id==='sfx_pole'){
      if(frame===0){m.wr(0x7079,5);invoke(m,'nes_event',{b:6});}
      m.wr(0x7300,64+Math.min(63,Math.floor(frame/50/0.016639267340))*2);
      if(s.nes_update_pole)invoke(m,'nes_update_pole');
      if(frame===Math.round(64*0.016639267340*50))invoke(m,'nes_event',{b:4});
    }
    if(options.stress){
      if(frame%37===0){const p=s[['nes_sfx_pickup','nes_sfx_jump','nes_sfx_life','nes_sfx_door'][Math.floor(frame/37)%4]];m.wr(s.nes_p_ptr,p&255);m.wr(s.nes_p_ptr+1,p>>8);m.wr(s.nes_p_wait,1);}
      if(frame%53===0){const q=s.nes_sfx_death;m.wr(s.nes_n_ptr,q&255);m.wr(s.nes_n_ptr+1,q>>8);m.wr(s.nes_n_wait,1);}
    }
    m.frame();snapshots.push(pit.channels.map(c=>c.running&&c.mode===3?c.count:0));
  }
  const audio=render(events,n/50);
  const name=options.stress?'mixed':options.loop?id+'_loop':id;
  fs.writeFileSync(path.join(out,name+'.wav'),Buffer.from(wav(audio.samples,audio.rate)));
  fs.writeFileSync(path.join(out,name+'.ports.json'),JSON.stringify(events)+'\n');
  const result={id:name,frames:n,seconds:n/50,writes:events.length,irq_max_cycles:max,irq_with_call_cycles:max+24,irq_peak_frame:peakFrame,irq_histogram:histogram,queue_underruns:underruns,peak:audio.peak,rms:audio.rms};
  if(['title','pyramid','treasure'].includes(id)&&!options.stress){
    let differences=0;for(let f=0;f<n;f++){const expected=id==='title'&&f>=track.intro_frames?track.loop_states[(f-track.intro_frames)%track.frames]:track.states[options.loop?f%track.frames:f];if(snapshots[f].some((v,c)=>v!==expected[c]))differences++;}
    result.register_frame_differences=differences;

    assert.equal(differences,0,id+' actual IRQ output differs from converter');
  }
  assert.equal(result.queue_underruns,0,name+' queue underrun');
  assert(max+24<=600,name+' IRQ budget exceeded');
  assert(audio.rms>1e-5&&audio.peak<1,name+' invalid WAV');
  console.log(JSON.stringify(result));return result;
}

if(require.main===module){
  const selected=process.argv.slice(3),ids=selected.length?selected:Object.keys(conversion.tracks);
  const results=ids.map(id=>capture(id,{loop:process.env.LOOP==='1'}));
  if(!selected.length)results.push(capture('pyramid',{stress:true,frames:conversion.tracks.pyramid.frames}));
  fs.writeFileSync(path.join(out,'verification.json'),JSON.stringify(results,null,2)+'\n');
}
module.exports={invoke,Timer,render,capture};
