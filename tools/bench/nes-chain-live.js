// Run actual frames and keyboard polling: walk off the ledge, catch the cap,
// then press Down immediately or after releasing Left for two game steps.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));const root=process.cwd();const E=require(root+'/tools/vec_emu'),{symbols}=require(root+'/tools/bench/logic-profile');const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B);let cases=0;
for(const target of [206,202,198,196])for(const delay of [0,2]){
 const m=E.mk(B+'/monty.bin');let steps=0,phase=0,ts=0,trace=[];
 m.onInstr=pc=>{if(pc!==s.L_A5D1)return;steps++;
 if(steps===80){m.wr(0x71a7,1);m.wr(0x71a8,10);m.wr(0x705f,0);for(let a=0x70c0;a<0x7186;a++)m.wr(a,255);m.wr(0x7300,92);m.wr(0x7304,95);m.wr(0x7301,18);m.wr(0x7305,18);m.wr(0x7079,0);m.wr(0x7076,0);m.wr(0x7077,0);m.wr(0x707c,92);let c=m.cpu;c.sp-=2;m.wr(c.sp,pc&255);m.wr(c.sp+1,pc>>8);c.pc=s.L_A067;phase=1;m.keyboard.matrix[0]=16;return;}
 if(phase===1&&m.rd(0x71a8)===9&&m.rd(0x7305)<=target){
  for(let a=s.nes_chain_catch;a<s.nes_chain_catch_end;a++)
   assert.equal(m.rd(a),m.img[a],'chain helper survives boot and both room loads');
  phase=2;ts=steps;m.keyboard.matrix[0]=delay?0:128;
 }
 if(phase===2){if(steps-ts>=delay)m.keyboard.matrix[0]=128;trace.push([m.frames,steps-ts,m.rd(0x7304),m.rd(0x7305),m.rd(0x7079),m.rd(s.kbmat)]);if(trace.length>24)phase=3;}
 };
 for(let f=0;f<550&&phase<3;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
 assert.equal(phase,3,`approach did not finish: ${target}/${delay}`);
 assert.equal(trace.at(-1)[4],4,`lost rope: ${target}/${delay}`);
 assert(trace.at(-1)[2]>110,'Joe must actually descend');
 assert(trace.every(q=>q[2]<=95||q[4]===4),`fall after Down: ${target}/${delay}: ${JSON.stringify(trace)}`);
 assert(trace.every(q=>q[2]<=95||q[3]===196),`descending through ledge: ${target}/${delay}: ${JSON.stringify(trace)}`);
 cases++;
}

console.log(JSON.stringify({B,cases,route:'1,10 -> 1,9 -> right rope',realFrames:true,keyboardPolling:true,fall:false}));
