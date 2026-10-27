#!/usr/bin/env node
// The same dependency-free synthesizer is used by the browser and WAV exporter.
'use strict';
const fs=require('node:fs'),path=require('node:path'),apu=require('./apu.js');
const out=process.argv[2];
if (!out) throw Error('Usage: node tools/nes/music/render_music.js build/nes/music');
const data=JSON.parse(fs.readFileSync(path.join(out,'music.json'),'utf8')),results=[];
for (const track of data.tracks) {
  const result=apu.render(track,44100,data.framePeriod);
  if (!(result.rms>0.0001 && result.peak<1)) throw Error(`Invalid audio: ${track.id} ${result.rms} / ${result.peak}`);
  fs.writeFileSync(path.join(out,track.id+'.wav'),Buffer.from(apu.wav(result.samples,result.rate)));
  results.push({track:track.id,seconds:result.samples.length/result.rate,peak:result.peak,rms:result.rms});
  console.log(results.at(-1));
}
fs.writeFileSync(path.join(out,'render_verification.json'),JSON.stringify(results,null,2)+'\n');
