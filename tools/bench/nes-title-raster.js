// Compare actual beam-rendered frames with complete painted poses, not VRAM
// snapshots alone: a torn or missing Joe frame must fail this check.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
let active=false,shown=false,entry,paint,baseline,started=false,done=false,irqCycles=0,eraseStart,eraseMax=0;
const poses=new Set(),observed=[];let cycles=0;
function memoryHash(){let h=2166136261;const pal=m.palette();for(let y=0;y<256;y++)for(let col=0;col<32;col++){
 const a=col*256+255-y,b0=m.rd(0x8000+a),b1=m.rd(0xa000+a),b2=m.rd(0xc000+a);
 for(let x=7;x>=0;x--){const ink=((b0>>x)&1)*4+((b1>>x)&1)*2+((b2>>x)&1);h=Math.imul(h^pal[2*ink],16777619);}
}return h>>>0;}
function rasterHash(){let h=2166136261;for(let y=0;y<256;y++)for(let x=0;x<256;x++)h=Math.imul(h^m.v06c.bmp[(16+y)*576+32+2*x],16777619);return h>>>0;}
m.onInstr=pc=>{
 cycles+=m.cpu.vcycles||0;
 if(pc===s.title_animate){active=started=true;entry={sp:m.cpu.sp,ra:m.rd(m.cpu.sp)|m.rd(m.cpu.sp+1)<<8};baseline=memoryHash();}
 if(!active)return;
 if(pc===s.title_scene_ready)baseline=memoryHash();
 if(pc===0x38)irqCycles=cycles;
 if(pc===s.title_unpaint)eraseStart=cycles;
 if(pc===s.joe_put){paint={sp:m.cpu.sp,ra:m.rd(m.cpu.sp)|m.rd(m.cpu.sp+1)<<8};}
 if(paint&&pc===paint.ra&&m.cpu.sp===paint.sp+2){poses.add(memoryHash());shown=true;paint=null;if(eraseStart)eraseMax=Math.max(eraseMax,cycles-eraseStart);}
 if(pc===entry.ra&&m.cpu.sp===entry.sp+2){active=false;done=true;}
};
for(let f=0;f<800&&!done;f++){if(f===10)m.keyboard.matrix[2]=2;if(f===100)m.keyboard.matrix[2]=0;m.frame();if(active&&shown)observed.push(rasterHash());}
assert(started&&done&&poses.size>30,'complete title animation reached');
const missing=observed.filter(h=>h===baseline).length,torn=observed.filter(h=>!poses.has(h)).length;
const result={B,rasterFrames:observed.length,completePoses:poses.size,missingJoeFrames:missing,tornFrames:torn,maxEraseThroughPutCycles:eraseMax};
console.log(JSON.stringify(result));if(!process.env.ALLOW_TEAR){assert.equal(missing,0,'Joe vanished in a visible raster frame');assert.equal(torn,0,'raster contains an incomplete pose');}
