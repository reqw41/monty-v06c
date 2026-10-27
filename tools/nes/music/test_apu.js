#!/usr/bin/env node
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {APU,EventPlayer,render,wav,CPU_HZ}=require('./apu.js');

// Audible pitch must follow the NES pulse timer formula, irrespective of sample rate.
for(const rate of [44100,48000]) {
  const apu=new APU(rate),timer=253,mask=[true,false,false,false];
  for(const [a,v] of [[0x4015,1],[0x4000,0xbf],[0x4001,8],[0x4002,timer],[0x4003,0]])apu.write(a,v);
  let previous=0,crossings=0;
  for(let i=0;i<rate;i++) {
    const sample=apu.sample(mask);assert(Number.isFinite(sample));
    if(i>=rate/5 && previous<=0 && sample>0)crossings++;
    previous=sample;
  }
  assert(Math.abs(crossings/.8-CPU_HZ/(16*(timer+1)))<3,'Pulse pitch differs from hardware timer');
}

const folder=process.argv[2];
if(!folder)throw Error('Usage: node tools/nes/music/test_apu.js build/nes/music');
const data=JSON.parse(fs.readFileSync(path.join(folder,'music.json'),'utf8'));
assert.equal(data.tracks.length,12);
for(const track of data.tracks) {
  const muted=render(track,8000,data.framePeriod,{mask:[false,false,false,false]});
  assert.equal(muted.peak,0,'Muted channels produce sound');
  const player=new EventPlayer(track,8000,data.framePeriod,{loop:true}),hardware=player.apu;
  for(let i=0;i<Math.ceil((track.frames+3)*data.framePeriod*8000);i++)assert(Number.isFinite(player.sample()));
  assert.equal(player.apu,hardware,'Loop resets hardware state');
  assert(!player.ended && player.position<track.frames);
  const buffer=Buffer.from(wav(Float32Array.from([0,1,-1]),44100));
  assert.equal(buffer.toString('ascii',0,4),'RIFF');assert.equal(buffer.readUInt32LE(40),6);
  assert.equal(buffer.readInt16LE(46),32767);assert.equal(buffer.readInt16LE(48),-32767);
}
console.log('PASS: pitch at 44.1/48 kHz, 12 muted tracks and continuous loops, PCM WAV');
