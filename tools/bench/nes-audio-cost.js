// Player CPU cost over 1000 frames, with preparation nested inside polling.
const path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),L=require('./logic-profile');
const B=process.env.B||'build/nes-blend80-sp',s=L.symbols(B);
for(const scene of ['title','game']){
 const m=E.mk(B+'/monty.bin'),p=L.profiler(m,s),c=L.calls(m,s,p,['nes_poll','nes_tick','nes_prepare_core','joe_footstep']);
 // The IRQ resets PC0 with XOR A / OUT 00 before testing kb_req.
 const reset=[];
 for(let a=s.isr;a<s.isr+32;a++)if(m.rd(a)===0xAF&&m.rd(a+1)===0xD3&&m.rd(a+2)===0){reset.push(a,a+1);break;}
 if(reset.length!==2)throw Error('Speaker reset instructions not found');
 let previous=-1,resetCycles=0;
 m.onInstr=pc=>{
  const measure=m.frames>=300&&m.frames<1300;
  if(measure&&reset.includes(previous))resetCycles+=m.cpu.vcycles||0;
  previous=pc;c.instruction(pc,p.instruction(pc),measure);
 };
 for(let f=0;f<1300;f++){
  if(scene==='game'){
   if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;
   if(f>300){m.keyboard.matrix[0]=Math.floor(f/70)%2?0x40:0x10;m.keyboard.matrix[7]=f%60<3?0x80:0;}
  }
  m.frame();
 }
 const stats={};let total=0;
 for(const q of c.stats.values()){
  const z=stats[q.name]??={cycles:0,count:0,max:0};
  z.cycles+=q.cycles;z.count+=q.count;z.max=Math.max(z.max,q.max);
 }
 for(const [name,z]of Object.entries(stats)){
  z.perFrame=Math.round(z.cycles/1000);
  // External entries are CALLs; recursive tail jumps are one tracked call.
  if(name!=='nes_prepare_core'&&name!=='joe_footstep')total+=z.cycles+24*z.count;
 }
 const foot=stats.joe_footstep||{cycles:0,count:0};
 const speaker=resetCycles+foot.cycles+24*foot.count;
 console.log(JSON.stringify({B,scene,frames:1000,stats,playerCyclesPerFrame:Math.round(total/1000),speakerResetCyclesPerFrame:resetCycles/1000,speakerCyclesPerFrame:speaker/1000,totalSoundCyclesPerFrame:(total+speaker)/1000,cpuPercent:100*(total+speaker)/(1000*59904)}));
}
