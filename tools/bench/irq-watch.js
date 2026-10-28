// Wall-clock CPU cycles between IRQ entry and its matching return, including
// stack switches. Used when validating a larger atomic display budget.
module.exports=(m,s,startFrame=400)=>{
 let cycles=0,active=null,count=0,max=0,overFrame=0,example=null;
 return {instruction(pc){
  cycles+=m.cpu.vcycles||0;
  if(active&&pc===active.pc&&m.cpu.sp===active.sp+2){
   const elapsed=cycles-active.start;
   if(active.frame>=startFrame){count++;if(elapsed>max){max=elapsed;example={frame:active.frame,state:active.state,cycles:elapsed};}if(elapsed>=59904)overFrame++;}
   active=null;
  }
  if(pc===0x38&&!active){const sp=m.cpu.sp;active={sp,pc:m.rd(sp)|(m.rd(sp+1)<<8),start:cycles,frame:m.frames,state:m.rd(0x7079)};}
 },result(){return {count,max,overFrame,example};}};
};
