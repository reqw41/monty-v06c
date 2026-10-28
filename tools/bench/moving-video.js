// Fairness under continuous Joe motion. Pixel correctness alone allows frozen NPCs.
// SCENE=ladder|walk|jump B=build/native N=1100 OUT=... node tools/bench/moving-video.js
'use strict';
const fs=require('fs'),path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/native',scene=process.env.SCENE||'ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
const checker=require('./framecheck')(m,s),motion=require('./joe-motion')(m,s);
const irq=require('./irq-watch')(m,s);
const start=400,end=+(process.env.N||1100),enemies={},states={},background={fire:{writes:0,changes:0,maxGap:0,last:start},belt:{writes:0,changes:0,maxGap:0,last:start}};
let steps=0,down=true,right=true,measuredSteps=0,firstStep=null,lastStepFrame=null;const intervals={};
const object=k=>0x7300+4*m.rd(0x72E0+k),key=r=>[m.rd(r+1),m.rd(r+2)].join(',');
const visible=p=>m.rd(p)<192&&!!(m.rd(p+3)&15)&&![6,11].includes(m.rd(p+3)&15);
function enemy(k){return enemies[k]||(enemies[k]={puts:0,gameDistance:0,drawnDistance:0,jump:0,maxLag:0,maxPendingFrames:0,pending:0,source:null,shown:null});}
m.onWrite=(a,v)=>{if(m.frames<start)return;for(const name of ['fire','belt'])if(a===s[name+'_shown']&&v!==m.rd(a)){const q=background[name];q.changes++;q.maxGap=Math.max(q.maxGap,m.frames-q.last);q.last=m.frames;}};
m.onInstr=pc=>{
 irq.instruction(pc);
 motion.instruction(pc);checker.instruction(pc);
 if(pc===s.L_8DA2&&steps>60){const c=m.cpu;c.pc=m.rd(c.sp)|(m.rd(c.sp+1)<<8);c.sp+=2;return;}
 if(pc===s.L_A5D1){steps++;m.wr(0x7049,6);m.wr(0x707C,m.rd(0x7300));
  if(scene==='jump'&&steps===50){m.wr(0x705F,m.rd(0x705F)&~4);m.wr(0x71A7,1);m.wr(0x71A8,9);m.wr(0x7079,9);}
  if(m.frames>=start){if(firstStep===null)firstStep=steps;measuredSteps++;if(lastStepFrame!==null){const d=m.frames-lastStepFrame;intervals[d]=(intervals[d]||0)+1;}lastStepFrame=m.frames;}
 }
 if(m.frames<start)return;
 if(pc===s.spr_put){const k=m.rd(s.sp_k);if(k>=2&&visible(object(k))){const q=enemy(k),r=s.spr_rec+16*k,x=m.rd(r+2);q.puts++;if(q.lastPut!==undefined){const dx=Math.abs(x-q.lastPut);q.jump=Math.max(q.jump,dx);q.drawnDistance+=dx;}q.lastPut=x;}}
 if(pc===s.da_blit||pc===s.fl_write){const t=m.rd(s.rr_t);if(t>=0xD0&&t<=0xD5)background.fire.writes++;if([4,5,6,0xA0,0xA3,0xA4,0xA7,0xB8,0xB9,0xBA,0xE0,0xE8].includes(t))background.belt.writes++;}
};
const out=process.env.OUT;if(out)fs.mkdirSync(out,{recursive:true});
for(let f=0;f<end;f++){
 if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;
 if(f>=start){
  m.keyboard.matrix[0]&=~0xF0;m.keyboard.matrix[7]&=~0x80;
  if(scene==='ladder'){const y=Math.max(m.rd(0x7300),m.rd(0x7304));if(y>=106)down=false;if(y<=64)down=true;m.keyboard.matrix[0]|=down?0x80:0x20;}
  if(scene==='walk'){const x=m.rd(0x7301);if(x>=126)right=false;if(x<=120)right=true;m.keyboard.matrix[0]|=right?0x40:0x10;}
  if(scene==='jump'&&(f-start)%60<3)m.keyboard.matrix[7]|=0x80;
 }
 m.frame();motion.frame();
 if(f<start)continue;
 const st=m.rd(0x7079);states[st]=(states[st]||0)+1;
 for(let k=2;k<6;k++){
  const p=object(k),r=s.spr_rec+16*k;if(!visible(p))continue;const q=enemy(k),source=[m.rd(p),m.rd(p+1)].join(','),shown=key(r),x=m.rd(p+1);
  if(q.sourceX!==undefined)q.gameDistance+=Math.abs(x-q.sourceX);q.sourceX=x;
  q.maxLag=Math.max(q.maxLag,Math.abs(x-m.rd(r+2)));
  q.pending=source!==shown&&shown===q.shown?q.pending+1:0;q.maxPendingFrames=Math.max(q.maxPendingFrames,q.pending);q.source=source;q.shown=shown;
 }
 if(out&&f<start+300){const pixels=new Uint8Array(256*192);for(let y=0;y<192;y++)for(let x=0;x<256;x++){const a=(x>>3)*256+0xDF-y,b=128>>(x&7);pixels[y*256+x]=((m.rd(0x8000+a)&b)?4:0)|((m.rd(0xA000+a)&b)?2:0)|((m.rd(0xC000+a)&b)?1:0);}fs.writeFileSync(`${out}/${scene}_${f}.idx`,pixels);fs.writeFileSync(`${out}/${scene}_${f}.json`,JSON.stringify({palette:[...Array(8)].map((_,i)=>m.rd(s.pal+2*i))}));}
}
for(const q of Object.values(background))q.maxGap=Math.max(q.maxGap,end-q.last);
const check=checker.result(),joe=motion.result(),irqTiming=irq.result(),failures=[];
for(const [k,q] of Object.entries(enemies)){if(q.jump>3||q.maxLag>12||q.maxPendingFrames>8||q.puts<20||q.drawnDistance<.85*q.gameDistance)failures.push('NPC '+k+' starved or skipped motion');}
if(!Object.keys(enemies).length)failures.push('No NPC coverage');
if(!background.fire.writes||background.fire.changes<5||background.fire.maxGap>64)failures.push('Fire animation starved');
if(!background.belt.writes||background.belt.changes<10||background.belt.maxGap>32)failures.push('Belt animation starved');
for(const z of Object.values(joe.states))for(const lag of Object.keys(z.lagSteps))if(!/^\d+$/.test(lag)||+lag>2)failures.push('Joe deadline '+lag);
if(check.bad||!check.checks)failures.push('Pixels');
if(irqTiming.overFrame)failures.push('IRQ exceeds a frame');
if((scene==='ladder'?(states[3]||0):(scene==='walk'?(states[1]||0):(states[2]||0)))<(scene==='jump'?150:500))failures.push('Insufficient Joe motion');
console.log(JSON.stringify({B,scene,steps:measuredSteps,frames:end-start,sps:50*measuredSteps/(end-start),intervals,states,enemies,background,irq:irqTiming,joe,check,failures}));
if(failures.length)process.exitCode=1;
