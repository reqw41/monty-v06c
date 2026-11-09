// Real title selection: exact masked NES Joe, exact background restoration,
// cold/warm entry, and intact enemy shifts after the cinematic.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
const frames=JSON.parse(fs.readFileSync('build/joe_nes/frames.json')).frames;
const out=process.env.OUT;if(out)fs.mkdirSync(out,{recursive:true});
let baseline,painted=false,cold=true,cinemas=0,checks=0,restores=0,steps=0,warm=false,done=false;
const walk=new Set(),rope=new Set(),jump=new Set(),tpath=[];
const walkX=[],jumpPath=[];let retainedColourPixels=0;
function pixels(){const p=Buffer.alloc(256*256);for(let y=0;y<256;y++)for(let x=0;x<256;x++){const a=(x>>3)*256+255-y,b=128>>(x&7);p[y*256+x]=[4,2,1].reduce((n,v,i)=>n+(m.rd(0x8000+0x2000*i+a)&b?v:0),0);}return p;}
m.onInstr=pc=>{
 if(pc===s.title_animate){baseline=m.dump().slice(0x8000,0xe000);cinemas++;}
 if(pc===s.title_scene_ready)baseline=m.dump().slice(0x8000,0xe000);
 if(pc===s.title_walk_shown){const st=m.rd(0x7079);
  painted=true;const f=m.rd(s.jn_frame),x0=m.rd(s.spr_new+2),y0=255-m.rd(s.spr_rec+9),skip=m.rd(s.jn_skip),rows=m.rd(s.jn_rows_count),want=new Uint8Array(baseline);
  if(cold){tpath.push([x0,m.rd(0x7304),st]);if(st<2)assert.equal(m.rd(s.jn_dir),128,'Joe walks left from the right edge');}
  for(let y=0;y<rows;y++)for(let x=0;x<16;x++){
   const source=frames[f].pixels[skip+y][m.rd(s.jn_dir)?7-(x>>1):x>>1];if(!source)continue;
   const ink=[0,3,2,1][source],xx=x0+x,yy=y0+y,bit=128>>(xx&7),a=(xx>>3)*256+255-yy;
   if(baseline[a]&bit)retainedColourPixels++;
   for(let p=1;p<3;p++)want[p*8192+a]=(want[p*8192+a]&~bit)|(ink&(4>>p)?bit:0);
  }
  for(let i=0;i<want.length;i++)assert.equal(m.rd(0x8000+i),want[i],`cinema ${cinemas} pose ${f} pixel byte ${i.toString(16)}`);
  (st<2?walk:st===4?rope:jump).add(f);checks++;
  if(out&&cold){const n=String(checks).padStart(3,'0');fs.writeFileSync(path.join(out,n+'.idx'),pixels());fs.writeFileSync(path.join(out,n+'.json'),JSON.stringify({palette:Array.from({length:8},(_,i)=>m.rd(s.pal+2*i)),stage:st<2?'walk':st===4?'rope':'step',x:x0,y:y0}));}
 }
 if(pc===s.title_blit&&painted){
  for(let i=0;i<baseline.length;i++)assert.equal(m.rd(0x8000+i),baseline[i],`background after pose ${restores}`);
  painted=false;restores++;
 }
 if(pc===s.L_A5D1){
  steps++;m.keyboard.matrix[2]=0;
  if(!warm&&steps===50){cold=false;warm=true;m.cpu.sp=s.GSTACK;m.cpu.pc=s.game_over;}
  if(warm&&cinemas===2&&!(m.rd(0x705f)&4))done=true;
 }
 if(pc===s.go1)m.keyboard.matrix[7]=128;
 if(pc===s.title_warm_menu){m.keyboard.matrix[7]=0;m.keyboard.matrix[2]=4;painted=false;}
};
for(let f=0;f<1500&&!done;f++){if(f===10)m.keyboard.matrix[2]=2;if(f===100)m.keyboard.matrix[2]=0;m.frame();}
assert(done&&cinemas===2,'cold and GAME OVER selections both play the cinematic');
// fix37: the hero's own physics walks Joe down the roof steps to the rope cap (X116), Down takes the rope.
const walkPath=tpath.filter(p=>p[2]<2).map(p=>p[0]),ropePath=tpath.filter(p=>p[2]===4);
assert.equal(walkPath[0],234,'walk starts at the right edge');assert.equal(Math.min(...walkPath),116,'walk ends on the rope cap at X116');
for(let i=1;i<walkPath.length;i++)assert(walkPath[i]===walkPath[i-1]-2||walkPath[i]===walkPath[i-1],'walks left 2 px a step');
assert(ropePath.length>40&&ropePath.every(p=>p[0]===116),'down the rope at X116');assert(ropePath[ropePath.length-1][1]>=206,'to the bottom of the scene');
assert.equal(retainedColourPixels,0,'static third-plane colour must not tint Joe');
assert.deepEqual([...walk].sort(),[1,2,3,4],'game walking poses');assert(rope.has(10)&&rope.has(19),'down the rope in the game rope poses');
assert.deepEqual([...jump],[7],'step-down falls in the game fall pose');
let cached=0;for(let i=0;i<s.PS_N*8;i++)if(m.rd(s.ps_tab+2*i)||m.rd(s.ps_tab+2*i+1))cached++;
assert(cached>=(s.PS_BLOCKS||29),'enemy shifts preserved');assert.equal(m.rd(s.jn_blend_select+1),1,'two-plane game put restored');
assert.equal(m.rd(s.jn_put_background+1)|m.rd(s.jn_put_background+2)<<8,s.JOE_BACKGROUND);
const ref=require('./video-ref');
for(let name=0x0c;name<=0x30;name+=4){
 const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s.sprite_source;c.sp=0x73be;c.regs[7]=name;
 m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000);c.instruction();}
 const source=c.hl();assert((source&255)<=224,'packed enemy mask must not cross a page');
 for(let i=0;i<32;i++)assert.equal(m.rd(source+i),ref.sprite(name,i>>4,i&15),'original enemy mask '+name+'/'+i);
}
console.log(JSON.stringify({B,cinemas,paintChecks:checks,restores,walkPoses:[...walk],stepPoses:[...jump],pathSteps:tpath.length,ropePoses:[...rope],entry:'right',retainedColourPixels,cachedShifts:cached,level:m.rd(0x71a6),landing:[m.rd(0x7304),m.rd(0x7305)],gameplayPut:'two planes'}));
