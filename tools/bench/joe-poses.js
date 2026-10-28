// Display fixture: all NES poses, both directions and all eight X shifts.
// Overrides only the display selector; this is pixel coverage, not a physics/speed test.
const fs=require('fs'),path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin'),check=require('./framecheck')(m,s,{manual:true});
const profiling=process.env.PROFILE==='1',lp=require('./logic-profile'),prof=profiling?lp.profiler(m,s):null,calls=profiling?lp.calls(m,s,prof,['joe_prepare','joe_put','joe_restore']):null;
let steps=0,pose=0,shift=0,mirror=0,phase=0,painting=null;const visited=new Set(),out=process.env.OUT;
if(out)fs.mkdirSync(out,{recursive:true});
m.onInstr=pc=>{if(prof){const context=prof.instruction(pc);calls.instruction(pc,context,steps>=250);}check.instruction(pc);if(pc===s.L_A5D1)steps++;
 if(steps<250)return;
 if(process.env.FORCE80==='1'&&pc===s.jn_put_tested)m.wr(s.jn_no80,0);
 if(pc===s.spr_plan){pose=phase%23;shift=Math.floor(phase/23)%8;mirror=Math.floor(phase/(23*8))%2;m.wr(0x7300,52);m.wr(0x7304,55);m.wr(0x7301,120+shift);m.wr(0x7305,120+shift);m.wr(0x7303,6);m.wr(0x7307,11);}
 if(pc===s.joe_select){m.cpu.regs[7]=pose;m.wr(s.jn_dir,mirror?128:0);const sp=m.cpu.sp;m.cpu.pc=m.rd(sp)|(m.rd(sp+1)<<8);m.cpu.sp=sp+2;}
 if(painting&&pc===painting.pc&&m.cpu.sp===painting.sp+2){checkerAfterPaint();painting=null;}
 if(pc===s.joe_put){const sp=m.cpu.sp;painting={sp,pc:m.rd(sp)|(m.rd(sp+1)<<8),key:`${pose}/${mirror}/${shift}`};}
};
function checkerAfterPaint(){check.checkNow();if(!visited.has(painting.key)){visited.add(painting.key);phase++;}}
const N=5000;
for(let f=0;visited.size<368&&f<N;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
const q=check.result();console.log(JSON.stringify({B,visited:visited.size,expected:368,check:q,profile:calls?[...calls.stats.values()].map(z=>({...z,avg:Math.round(z.cycles/z.count)})):undefined}));if(q.bad||visited.size!==368)process.exitCode=1;
