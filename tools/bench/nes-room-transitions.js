// Exercise ordinary room edges through the native hero process and decoder.
// Collected-object flags remove enemies and open doors; structural walls stay.
// This isolates boundary placement from keys, combat, and bonus-room logic.
// Index 0 is the NES introductory map; ordinary movement fixtures cover 1..98.
'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require(process.cwd()+'/tools/vec_emu'),{symbols}=require(process.cwd()+'/tools/bench/logic-profile');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<320;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
const baseline=m.memory.bytes.slice();let redraws=0,special=false,restoreOnly=false,checkpointCases=0;
function call(name){let c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){
  if(n>400000)throw Error(name+' hangs at '+c.pc.toString(16));
  // Replace only the scheduling wait with its actual room decoder.
  if(c.pc===s.L_8C13){if(restoreOnly){c.pc=s.unit_trap;break;}redraws++;c.pc=s.L_A067;}
  if(c.pc===s.L_8E0C&&m.rd(0x71a7)===9){special=true;c.pc=s.unit_trap;break;}
  c.instruction();
 }
}
const results=[];let done=0;
for(const level of [1,2,3,4,5,6,7,8,9])for(let i=1;i<99;i++)for(const dir of ['left','right','up','down']){
 m.memory.bytes.set(baseline);redraws=0;special=false;
 const r=Math.floor(Math.sqrt(i))-1,col=i-r*r-3*r+8;
 m.wr(0x71a6,level);m.wr(0x71a7,r);m.wr(0x71a8,col);m.wr(0x705f,0);m.wr(s.nes_q_idle,1);
 for(let a=0x70c0;a<0x7186;a++)m.wr(a,255);call('L_A067');m.wr(0x705f,0);
 const vertical=dir==='up'||dir==='down';
 if(vertical && ![0x88,0x89,0x95].includes(m.rd(s.FIELD_VNT+(dir==='up'?0:23)*32+15)))continue;
 const edge=vertical?m.rd(s.FIELD_VNT+(dir==='up'?0:23)*32+15):0;
 const x=vertical?(edge===0x89?111:edge===0x95?116:119):dir==='right'?224:16,y=vertical?(dir==='down'?207:47):95;
 m.wr(0x7300,y-3);m.wr(0x7304,y);m.wr(0x7301,x);m.wr(0x7305,x);m.wr(0x7079,vertical?(edge===0x95?4:3):0);m.wr(0x70b2,0);m.wr(0x7076,0);m.wr(0x7077,0);m.wr(0x707c,y-3);m.wr(0x7078,dir==='left'?254:2);
 m.wr(s.kbmat,{left:16,right:64,up:32,down:128}[dir]);
 let entry=null,trace=[];
 for(let n=0;n<80;n++){
  m.wr(s.kbmat,{left:16,right:64,up:32,down:128}[dir]);m.wr(0x705f,m.rd(0x705f)&~4);call('L_88D1');if(special)break;
  const pos=[m.rd(0x7305),m.rd(0x7304),m.rd(0x7079)];
  if(m.rd(0x71a5)!==i&&!entry){
   entry={index:m.rd(0x71a5),row:m.rd(0x71a7),col:m.rd(0x71a8),pos,step:n};
   const attrs=Array.from({length:8},(_,j)=>m.rd(0x7300+j)),saved=Array.from({length:8},(_,j)=>m.rd(0x704b+j));
   assert.deepEqual(saved,attrs,`checkpoint recorded before wrapped movement: ${level}/${i}/${dir}`);
   const scene=m.memory.bytes.slice(),motion=[m.rd(0x707d),m.rd(0x707e),m.rd(0x707f),m.rd(0x7080),m.rd(0x7081)];
   m.wr(0x7079,8);m.wr(0x70a9,0);m.wr(0x7049,6);restoreOnly=true;call('hs_8B8E');restoreOnly=false;
   assert.deepEqual(Array.from({length:8},(_,j)=>m.rd(0x7300+j)),saved,`respawn displaced: ${level}/${i}/${dir}`);
   assert.deepEqual([m.rd(0x7077),m.rd(0x7076),m.rd(0x7079),m.rd(0x7078),m.rd(0x7075)],motion,'checkpoint motion/state round trip');
   checkpointCases++;m.memory.bytes.set(scene);
  }
  if(entry){trace.push(pos);if(trace.length===25)break;}
  if(pos[2]>=8)break;
 }
 const end=[m.rd(0x7305),m.rd(0x7304),m.rd(0x7079)];
 const progress=entry?Math.max(...trace.map(p=>Math.abs(p[vertical?1:0]-entry.pos[vertical?1:0]))):0;
 let canReturn=null;
 if(entry&&progress<4){
  const reverse={left:64,right:16,up:128,down:32}[dir];
  for(let n=0;n<40&&m.rd(0x71a5)!==i;n++){m.wr(s.kbmat,reverse);call('L_88D1');}
  canReturn=m.rd(0x71a5)===i;
 }
 results.push({level,i,r,col,dir,entry,end,special,redraws,progress,canReturn});
 done++;
}
const transitioned=results.filter(q=>q.entry);
fs.mkdirSync('build/respawn-audit',{recursive:true});fs.writeFileSync('build/respawn-audit/transitions.json',JSON.stringify({cases:done,checkpointCases,results},null,2));
for(const q of transitioned){
 const row=q.r+({up:-1,down:1}[q.dir]||0);
 const col=(q.col+({left:-1,right:1}[q.dir]||0))&255;
 const index=(row*row+3*row+col-8)&255;
 const label=`level ${q.level}, room ${q.i}, ${q.dir}`;
 assert.deepEqual([q.entry.row,q.entry.col,q.entry.index],[row,col,index],label);
 assert(q.progress>=4||q.canReturn,`trapped after entry: ${label}`);
}
assert(transitioned.length>2300,'expected broad coverage of the nine levels');
console.log(JSON.stringify({B,cases:done,roomIndices:[1,98],checkpointCases,transitions:transitioned.length,
 structuralWallWithReturn:transitioned.filter(q=>q.progress<4).map(q=>({level:q.level,from:q.i,to:q.entry.index})),
 scope:'ordinary exits with doors open; enemies removed; bonus sequence excluded'}));
