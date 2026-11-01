// Verify all 16 colours/pixels, byte-exact unpacking, and entry to the real game.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',stage=B+'/splash';
const s=symbols(B),w=Object.fromEntries([...fs.readFileSync(stage+'/splash.sym','utf8').matchAll(/^(\w+): EQU 0x([0-9A-F]+)/gm)].map(q=>[q[1],parseInt(q[2],16)])),core=fs.readFileSync(B+'/monty.bin');
const m=E.mk(stage+'/splash.rom'),screen=fs.readFileSync(stage+'/screen.bin'),palette=fs.readFileSync(stage+'/palette.bin');
let restored=false,menu=false,steps=0,landed=false;
const scrollValues=[],readScroll=m.io.ScrollStart.bind(m.io);
m.io.ScrollStart=()=>{const v=readScroll();if(!restored&&m.frames>0)scrollValues.push(v);return v;};
m.onInstr=pc=>{
 if(pc===w.splash_jump_game&&!restored){
  for(let a=0;a<core.length;a++)assert.equal(m.rd(a),core[a],'unpacked game byte '+a.toString(16));
  restored=true;m.keyboard.matrix[7]=0;
 }
 if(restored&&pc===s.nm_wait)menu=true;
 if(restored&&pc===s.L_A5D1){steps++;if(steps>=40){
  assert.deepEqual([m.rd(0x7304),m.rd(0x7305),m.rd(0x7079)],[94,116,0],'rope intro after splash');landed=true;
 }}
};
let stableFrame;
for(let f=0;f<20;f++){
 m.frame();
 if(f===4)stableFrame=m.v06c.bmp.slice();
 if(f>4)assert.deepEqual(m.v06c.bmp,stableFrame,'splash raster must not flicker or scroll');
}
assert(scrollValues.length>0,'hardware scroll latch sampled');
assert(scrollValues.every(v=>v===255),'keyboard polling changed visible vertical scroll');
assert(!restored,'splash waits for Space');
for(let a=0;a<screen.length;a++)assert.equal(m.rd(0x8000+a),screen[a],'splash VRAM '+a.toString(16));
for(let i=0;i<16;i++)assert.equal(m.palette()[i],E.palColor(palette[i]),'splash palette '+i);
// Use the emulator's actual hardware pixel shifter, independently of packing.
const pixels=Buffer.alloc(256*256),source=fs.readFileSync(stage+'/source.idx'),filler=m.v06c.filler;
const saved=[filler.fb_column,filler.fb_row,filler.pixel32];
for(let y=0;y<256;y++)for(let col=0;col<32;col++){
 filler.fb_column=col;filler.fb_row=255-y;filler.fetchPixels();
 for(let x=0;x<8;x++){
  const i=y*256+col*8+x;pixels[i]=filler.shiftOutPixels();
  assert.equal(pixels[i],source[i],'actual 16-colour pixel '+i);
 }
}
[filler.fb_column,filler.fb_row,filler.pixel32]=saved;
if(process.env.OUT)fs.writeFileSync(process.env.OUT,pixels);
m.keyboard.matrix[7]=128;
for(let f=0;f<500&&!menu;f++)m.frame();
assert(restored&&menu,'restored game reaches the level menu');
for(let f=0;f<10;f++)m.frame();
m.keyboard.matrix[2]=2;
for(let f=0;f<500&&!landed;f++)m.frame();
assert(landed,'game started after splash');
let count=0;for(let i=0;i<s.PS_N*(s.PS_SHIFTS||8);i++)if(m.rd(s.ps_tab+2*i)||m.rd(s.ps_tab+2*i+1))count++;
assert(count>=(s.PS_SEED_POSES?4*s.PS_SEED_POSES:29),'splash preserves the recovered shift cache');
const joystickStarts=[];
if(s.NES_JOYSTICK_P)for(const port of[6,14]){
 const q=E.mk(stage+'/splash.rom');let unpacked=false,started=0,finished=false;
 q.onInstr=pc=>{
  if(pc===w.splash_jump_game&&!unpacked){for(let a=0;a<core.length;a++)assert.equal(q.rd(a),core[a],'joystick unpack byte '+a.toString(16));unpacked=true;}
  if(unpacked&&pc===s.L_A5D1){if(++started===1){q.io.PB2=255;q.JOY=255;}if(started>=40){assert.deepEqual([q.rd(0x7304),q.rd(0x7305),q.rd(0x7079)],[94,116,0]);finished=true;}}
 };
 for(let f=0;f<700&&!finished;f++){if(f===10){if(port===6)q.io.PB2=255^64;else q.JOY=255^128;}q.frame();}
 assert(unpacked&&finished,'joystick-only splash/menu/intro');assert(q.keyboard.matrix.every(v=>v===0));
 let shifts=0;for(let i=0;i<s.PS_N*(s.PS_SHIFTS||8);i++)if(q.rd(s.ps_tab+2*i)||q.rd(s.ps_tab+2*i+1))shifts++;
 assert.equal(shifts,s.PS_N*(s.PS_SHIFTS||8));joystickStarts.push({port,keyboard:false,level:q.rd(0x71a6),cachedShifts:shifts});
}
if(joystickStarts.length)console.log(JSON.stringify({B,joystickStarts}));
console.log(JSON.stringify({B,colours:16,pixels:65536,gameBytesCompared:core.length,waitsForSpace:true,stableRasterFrames:15,scroll:255,menu:true,ropeIntro:true,cachedShifts:count}));
