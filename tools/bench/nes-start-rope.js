// Real keyboard/frame introduction, plus advancement to each next level.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),out=process.env.OUT;
function capture(m,name){
 if(!out)return;fs.mkdirSync(out,{recursive:true});
 const pixels=Buffer.alloc(256*256);
 for(let y=0;y<256;y++)for(let x=0;x<256;x++){
  const a=(x>>3)*256+255-y,bit=128>>(x&7);
  pixels[y*256+x]=(m.rd(0x8000+a)&bit?4:0)|(m.rd(0xa000+a)&bit?2:0)|(m.rd(0xc000+a)&bit?1:0);
 }
 fs.writeFileSync(path.join(out,name+'.idx'),pixels);
 fs.writeFileSync(path.join(out,name+'.json'),JSON.stringify({palette:Array.from({length:8},(_,i)=>m.rd(s.pal+2*i))}));
}
if(out){const title=E.mk(B+'/monty.bin');for(let f=0;f<120;f++)title.frame();capture(title,'title');}
let baseline;const selected=[];
for(const level of [1,2,3]){
 const m=E.mk(B+'/monty.bin'),poses=new Set();let steps=0,landed=false,firstRows=0,settled=0,frames=0;
 m.onInstr=pc=>{
  if(pc!==s.L_A5D1)return;steps++;
  if(m.rd(0x705f)&4){
   assert.equal(m.rd(0x7305),116,'intro stays on the rope axis');
   assert(m.rd(0x7079)===4||m.rd(0x7079)===6||m.rd(0x7079)===0,'rope descent or short drop');
   if(m.rd(0x7079)===4)assert(m.rd(0x7077)<=1,'rope moves one pixel per step');
  }else{
   m.keyboard.matrix[0]=0;m.keyboard.matrix[7]=0;
   m.wr(s.kbmat,0);m.wr(s.kbmat+7,0);
   assert.deepEqual([m.rd(0x7300),m.rd(0x7304),m.rd(0x7305)],[91,94,116],'landed on starting platform');
   assert.deepEqual([m.rd(0x704b),m.rd(0x704f),m.rd(0x7050),m.rd(0x707f),m.rd(0x707d)],[91,94,116,0,0],'standing checkpoint');
   landed=true;settled++;
  }
 };
 for(let f=0;f<600&&settled<3;f++){
  if(f===10)m.keyboard.matrix[2]|=1<<level;if(f===100)m.keyboard.matrix[2]=0;
  if(!landed){m.keyboard.matrix[0]=0x40;m.keyboard.matrix[7]=0x80;}
  m.frame();
  if(steps){
   if(level===1)capture(m,'intro-'+String(frames++).padStart(3,'0'));
   if(m.rd(s.spr_rec)&&!firstRows)firstRows=m.rd(s.jn_rows_count);
   if(m.rd(0x7079)===4&&m.rd(s.spr_rec))poses.add(m.rd(s.jn_shown));
  }
 }
 assert(landed&&settled>=3,'intro completed for level '+level);
 assert.equal(m.rd(0x7049),6,'intro preserves lives');
 assert(firstRows>=15,'first Joe frame is visible');
 assert(poses.has(10)&&poses.has(19),'both rope poses were displayed: '+JSON.stringify([...poses]));
 assert([...poses].every(p=>p===10||p===19),'the initial rope never uses a ladder pose');
 for(let i=0;i<256;i++)assert.equal(m.rd(s.raw_base+i),m.img[s.raw_base_source+i],'tile index survived boot allocation');
 selected.push({level,steps,firstRows,ropePoses:[...poses]});
 if(level===1)baseline=m;
 m.onInstr=null;m.keyboard.matrix[0]=0x40;
 const x=m.rd(0x7305);for(let f=0;f<10;f++)m.frame();
 assert(m.rd(0x7305)>x,'normal controls resume after intro');
}
const m=baseline,boot=m.memory.bytes.slice();
function call(name){
 const c=m.cpu;c.iff=false;c.iff_pending=0;c.sp=0x73be;c.pc=s[name];
 m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){
  assert(n<1000000,name+' hung at '+c.pc.toString(16));
  if(c.pc===s.L_8C13)c.pc=s.L_A067;
  c.instruction();
 }
}
let advancements=0;
for(let level=1;level<9;level++){
 m.memory.bytes.set(boot);m.wr(0x71a6,level);m.wr(0x71a7,9);m.wr(0x71a8,8);
 m.wr(0x7079,5);m.wr(0x705f,0x20);m.wr(0x70ac,1);m.wr(0x7049,3);m.wr(s.nes_q_idle,1);
 call('L_8E0C');
 assert.deepEqual([m.rd(0x71a6),m.rd(0x71a7),m.rd(0x71a8)],[level+1,0,10],'next level starts in the opening room');
 assert.deepEqual([m.rd(0x7300),m.rd(0x7304),m.rd(0x7305),m.rd(0x7079)],[44,47,116,4],'next level starts on the rope');
 assert.equal(m.rd(0x7049),3,'advancement preserves remaining lives');
 for(let n=0;n<40;n++){m.wr(s.kbmat,0);call('L_88D1');}
 assert.deepEqual([m.rd(0x7304),m.rd(0x7305),m.rd(0x7079)],[94,116,0],'next-level intro lands safely');
 assert.equal(m.rd(0x7049),3);advancements++;
}
console.log(JSON.stringify({B,selected,advancements,landing:[91,94,116],livesPreserved:true}));
