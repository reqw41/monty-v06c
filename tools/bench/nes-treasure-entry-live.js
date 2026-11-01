// Real keyboard/IRQ/rendering path, against the same unmodified NES layouts.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),results=[];
const reference=JSON.parse(fs.readFileSync('build/nes-treasure/platform-entry-reference.json')).bonus;
const demo=process.env.DEMO==='1',sides=demo?[process.env.DEMO_SIDE||'left']:['left','right'];
for(const side of sides)for(const seed of (demo?[65]:[1,65,257])){
 const m=E.mk(B+'/monty.bin'),x0=side==='left'?52:188,dx=side==='left'?2:-2,ref=reference.find(q=>q.level===1&&q.side===side&&q.seed===seed);
 let phase=0,steps=0,idle=0,entered=false,frame,entryPosition,caught=null,bonusTick=0,held=0,seeded=false,movieFrame=0;
 m.onInstr=pc=>{
  // Fixture the PRNG only, not the generated field or hero: both sides must
  // see the identical original NES room. The shipping ROM stays random.
  if(pc===s.L_A60B&&!seeded&&phase>=2){seeded=true;m.wr(0x7047,seed&255);m.wr(0x7048,seed>>8);}
  if(pc!==s.L_A5D1)return;
  if(++steps===(demo?1:80)&&phase===0){
   phase=1;if(!demo){for(const [a,v]of[[0x71a7,8],[0x71a8,10],[0x705f,0],[0x7079,0],[0x7072,0],[0x7300,172],[0x7304,175],[0x7301,x0],[0x7305,x0],[0x7076,0],[0x7077,0],[0x7078,dx&255]])m.wr(a,v);
    m.cpu.sp-=2;m.wr(m.cpu.sp,s.L_A5D1&255);m.wr(m.cpu.sp+1,s.L_A5D1>>8);m.cpu.pc=s.L_A067;return;
   }
  }
  if(phase===1){
   assert.equal(m.rd(0x71a7),8);assert(!(m.rd(0x705f)&32));assert.deepEqual([m.rd(0x7305),m.rd(0x7304),m.rd(0x7079)],[x0,175,0],'wait for player on the existing platform');
   if(++idle===120){m.keyboard.matrix[0]=side==='left'?64:16;m.keyboard.matrix[7]=128;phase=2;}
  }else if(phase===2&&m.rd(0x7079)===2){phase=3;m.keyboard.matrix[0]=m.keyboard.matrix[7]=0;}
  else if(phase===3&&(m.rd(0x705f)&32)){
   if(!entered){entered=true;entryPosition=[m.rd(0x7305),m.rd(0x7304)];assert.deepEqual(entryPosition,[side==='left'?128:112,44]);assert.equal(m.rd(0x7076),dx&255);return;}
   bonusTick++;
   if(m.rd(0x7079)===4){
    if(caught===null){caught=bonusTick-1;assert.equal(caught,ref.caught,'original NES catch step');assert.deepEqual([m.rd(0x7305),m.rd(0x7304)-7,64],ref.trace[caught],'original NES rope and Y');}
    if(++held>=12)phase=4;
   }else if(m.rd(0x71a7)!==9||m.rd(0x71a8)!==10){assert.equal(ref.caught,null,'left first panel before expected rope catch');phase=4;}
  }
 };
 for(frame=0;frame<1500&&phase!==4;frame++){
  if(!demo&&frame===10)m.keyboard.matrix[2]=2;if(!demo&&frame===100)m.keyboard.matrix[2]=0;m.frame();
  if(process.env.MOVIE&&seed===65&&idle>=105){
   const out=path.join(process.env.MOVIE,side);fs.mkdirSync(out,{recursive:true});const pixels=Buffer.alloc(65536);
   for(let y=0;y<256;y++)for(let x=0;x<256;x++){const a=(x>>3)*256+255-y,b=128>>(x&7);pixels[256*y+x]=[4,2,1].reduce((v,k,i)=>v+(m.rd(0x8000+8192*i+a)&b?k:0),0);}
   const name=String(movieFrame++).padStart(4,'0');fs.writeFileSync(path.join(out,name+'.idx'),pixels);fs.writeFileSync(path.join(out,name+'.json'),JSON.stringify({rgb:m.palette().filter((_,i)=>!(i&1)).map(v=>[v&255,(v>>>8)&255,(v>>>16)&255]),x:m.rd(0x7305),y:m.rd(0x7304),state:m.rd(0x7079)}));
  }
 }
 assert.equal(phase,4,'manual jump enters bonus');assert.equal(m.rd(0x7049),6);assert.equal(caught,ref.caught,'same first-panel catch outcome as NES');
 results.push({side,seed,spawn:[x0,175],idleTicks:idle,bonusEntry:entryPosition,diagonalMomentum:dx,ropeCatchStep:caught,heldTicks:held});
}
console.log(JSON.stringify({B,demo,entries:results,automaticInput:false}));
