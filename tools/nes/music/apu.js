/* Four-channel NES music renderer for monty-nes-apu-events-v1. No dependencies.
 * The game's driver supplies software envelopes; DMC and enabled sweep are unused.
 * Register timing is frame-granular. This is not a cycle-exact NES emulator.
 * References: https://www.nesdev.org/wiki/APU_Pulse
 * https://www.nesdev.org/wiki/APU_Noise https://www.nesdev.org/wiki/APU_Mixer
 */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else { root.MontyAPUFactory = factory; root.MontyAPU = factory(); }
})(globalThis, function createMontyAPU() {
  'use strict';
  const CPU_HZ = 1789772.7272727273;
  const LENGTH = [10,254,20,2,40,4,80,6,160,8,60,10,14,12,26,14,12,16,24,18,48,20,96,22,192,24,72,26,16,28,32,30];
  const NOISE = [4,8,16,32,64,96,128,160,202,254,380,508,762,1016,2034,4068];
  const DUTY = [[0,1,0,0,0,0,0,0],[0,1,1,0,0,0,0,0],[0,1,1,1,1,0,0,0],[1,0,0,1,1,1,1,1]];
  const TRIANGLE = Array.from({length:32}, (_,i) => i < 16 ? 15-i : i-16);
  const channel = () => ({control:0, period:0, timer:0, phase:0, length:0, envelopeStart:false, envelope:0, divider:0});
  class APU {
    constructor(rate, oversample=4) {
      this.rate=rate; this.oversample=oversample; this.dt=CPU_HZ/(rate*oversample);
      this.pulse=[channel(),channel()]; this.triangle=channel(); this.triangle.phase=15;
      this.triangle.linear=0; this.triangle.reload=false; this.noise=channel(); this.noise.period=4;
      this.noise.lfsr=1; this.noise.mode=false; this.enabled=0; this.frameCycle=0; this.frameStep=0; this.fiveStep=false;
      this.hp90=0; this.hp440=0; this.lp=0; this.previous=0; this.previous90=0;
      const sr=rate*oversample;
      this.a90=Math.exp(-2*Math.PI*90/sr); this.a440=Math.exp(-2*Math.PI*440/sr); this.b14=1-Math.exp(-2*Math.PI*14000/sr);
    }
    write(address,value) {
      value&=255;
      if (address>=0x4000 && address<=0x4007) {
        const index=(address>>2)&1, c=this.pulse[index];
        switch (address&3) {
          case 0: c.control=value; break;
          case 1: if (value&128) throw Error('Enabled sweep is not used by these tracks'); break;
          case 2: c.period=(c.period&0x700)|value; break;
          case 3:
            c.period=(c.period&255)|((value&7)<<8); c.phase=0; c.envelopeStart=true;
            if (this.enabled&(1<<index)) c.length=LENGTH[value>>3]; break;
        }
      } else if (address===0x4008) this.triangle.control=value;
      else if (address===0x400a) this.triangle.period=(this.triangle.period&0x700)|value;
      else if (address===0x400b) {
        const c=this.triangle; c.period=(c.period&255)|((value&7)<<8); c.reload=true;
        if (this.enabled&4) c.length=LENGTH[value>>3];
      } else if (address===0x400c) this.noise.control=value;
      else if (address===0x400e) { this.noise.period=NOISE[value&15]; this.noise.mode=!!(value&128); }
      else if (address===0x400f) { this.noise.envelopeStart=true; if (this.enabled&8) this.noise.length=LENGTH[value>>3]; }
      else if (address===0x4015) {
        if (value&16) throw Error('DMC is not used by these tracks'); this.enabled=value&15;
        [...this.pulse,this.triangle,this.noise].forEach((c,i) => { if (!(value&(1<<i))) c.length=0; });
      } else if (address===0x4017) {
        this.fiveStep=!!(value&128); this.frameCycle=0; this.frameStep=0;
        if (this.fiveStep) { this.quarterFrame(); this.halfFrame(); }
      } else if (address>=0x4010 && address<=0x4013 && value) throw Error('DMC is not used by these tracks');
    }
    quarterFrame() {
      for (const c of [...this.pulse,this.noise]) {
        if (c.envelopeStart) { c.envelopeStart=false; c.envelope=15; c.divider=c.control&15; }
        else if (c.divider) c.divider--;
        else { c.divider=c.control&15; if (c.envelope) c.envelope--; else if (c.control&32) c.envelope=15; }
      }
      const t=this.triangle;
      if (t.reload) t.linear=t.control&127; else if (t.linear) t.linear--;
      if (!(t.control&128)) t.reload=false;
    }
    halfFrame() {
      for (const c of [...this.pulse,this.noise]) if (!(c.control&32) && c.length) c.length--;
      if (!(this.triangle.control&128) && this.triangle.length) this.triangle.length--;
    }
    advance() {
      const dt=this.dt; this.frameCycle+=dt;
      const times=this.fiveStep ? [7457,14913,22371,29829,37281] : [7457,14913,22371,29829];
      while (this.frameCycle>=times[this.frameStep]) {
        if (!(this.fiveStep && this.frameStep===3)) this.quarterFrame();
        if (this.frameStep===1 || this.frameStep===(this.fiveStep?4:3)) this.halfFrame();
        if (++this.frameStep===times.length) { this.frameStep=0; this.frameCycle-=this.fiveStep?37282:29830; }
      }
      for (const c of this.pulse) {
        c.timer-=dt;
        if (c.timer<=0) { const period=2*(c.period+1), n=1+Math.floor(-c.timer/period); c.timer+=n*period; c.phase=(c.phase+n)&7; }
      }
      const t=this.triangle; t.timer-=dt;
      if (t.timer<=0) {
        const period=t.period+1, n=1+Math.floor(-t.timer/period); t.timer+=n*period;
        if (t.length && t.linear && t.period>=2) t.phase=(t.phase+n)&31;
      }
      const n=this.noise; n.timer-=dt;
      while (n.timer<=0) { n.timer+=n.period; const bit=(n.lfsr^(n.lfsr>>(n.mode?6:1)))&1; n.lfsr=(n.lfsr>>1)|(bit<<14); }
    }
    volume(c) { return c.control&16 ? c.control&15 : c.envelope; }
    sample(mask) {
      let sum=0;
      for (let k=0;k<this.oversample;k++) {
        this.advance();
        let p=0;
        for (let i=0;i<2;i++) {
          const c=this.pulse[i];
          if (mask[i] && c.length && c.period>=8 && DUTY[c.control>>6][c.phase]) p+=this.volume(c);
        }
        const tri=mask[2] ? TRIANGLE[this.triangle.phase] : 0;
        const noise=mask[3] && this.noise.length && !(this.noise.lfsr&1) ? this.volume(this.noise) : 0;
        const tnd=tri/8227+noise/12241;
        const raw=(p ? 95.88/(8128/p+100) : 0)+(tnd ? 159.79/(1/tnd+100) : 0);
        this.hp90=this.a90*(this.hp90+raw-this.previous); this.previous=raw;
        this.hp440=this.a440*(this.hp440+this.hp90-this.previous90); this.previous90=this.hp90;
        this.lp+=this.b14*(this.hp440-this.lp); sum+=this.lp;
      }
      return sum/this.oversample*1.8;
    }
  }
  class EventPlayer {
    constructor(track,rate,framePeriod,options={}) {
      this.track=track; this.rate=rate; this.framePeriod=framePeriod; this.apu=new APU(rate,options.oversample||4);
      this.mask=options.mask||[true,true,true,true]; this.loop=options.loop!==false;
      this.position=0; this.event=0; this.ended=false; this.totalSamples=0;
      this.increment=1/(rate*framePeriod);
      this.loopEvent=track.events.findIndex(e => e[0]>=track.loopStartFrame);
      for (const [address,value] of track.initialWrites) this.apu.write(address,value);
    }
    sample() {
      if (this.ended) return 0;
      if (this.position>=this.track.frames) {
        if (!this.loop) { this.ended=true; return 0; }
        this.position=this.track.loopStartFrame+(this.position-this.track.frames); this.event=this.loopEvent;
      }
      while (this.event<this.track.events.length && this.track.events[this.event][0]<=this.position) {
        const e=this.track.events[this.event++]; this.apu.write(e[1],e[2]);
      }
      const value=this.apu.sample(this.mask); this.position+=this.increment; this.totalSamples++; return value;
    }
  }
  function render(track,rate,framePeriod,options={}) {
    const player=new EventPlayer(track,rate,framePeriod,{...options,loop:false});
    const samples=new Float32Array(Math.ceil(track.frames*framePeriod*rate)); let peak=0,squares=0;
    const fade=Math.min(options.fadeSeconds===undefined?(track.kind==='sfx' ? 0.03 : 1.5):options.fadeSeconds,samples.length/rate);
    for (let i=0;i<samples.length;i++) {
      const gain=fade ? Math.min(1,(samples.length-1-i)/(fade*rate)) : 1;
      const value=player.sample()*Math.max(0,gain); samples[i]=value; peak=Math.max(peak,Math.abs(value)); squares+=value*value;
    }
    return {samples,rate,peak,rms:Math.sqrt(squares/samples.length)};
  }
  function wav(samples,rate) {
    const buffer=new ArrayBuffer(44+samples.length*2), view=new DataView(buffer);
    const str=(pos,text) => { for (let i=0;i<text.length;i++) view.setUint8(pos+i,text.charCodeAt(i)); };
    str(0,'RIFF');view.setUint32(4,36+samples.length*2,true);str(8,'WAVE');str(12,'fmt ');view.setUint32(16,16,true);
    view.setUint16(20,1,true);view.setUint16(22,1,true);view.setUint32(24,rate,true);view.setUint32(28,rate*2,true);
    view.setUint16(32,2,true);view.setUint16(34,16,true);str(36,'data');view.setUint32(40,samples.length*2,true);
    for (let i=0;i<samples.length;i++) view.setInt16(44+i*2,Math.round(Math.max(-1,Math.min(1,samples[i]))*32767),true);
    return buffer;
  }
  return {APU,EventPlayer,render,wav,CPU_HZ};
});
