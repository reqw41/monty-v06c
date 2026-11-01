// A cancelled walking displacement is not a newly painted visual epoch.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/joe-rhythm-final',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]=2;if(f===100)m.keyboard.matrix[2]=0;m.frame();}
function call(){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s.joe_motion_pending;c.sp=0x73be;
 m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<10000,'motion comparison hung');c.instruction();}
 return !!(c.store_flags()&0x40);
}
let cases=0;
for(let state=0;state<=10;state++)for(const [epoch,last]of [[2,0],[255,253],[0,254]])for(const changed of [-1,0,1,2,3]){
 const sources=[0x7300+4*m.rd(0x72e0),0x7300+4*m.rd(0x72e0+1)];
 for(let k=0;k<2;k++){
  m.wr(sources[k],80+3*k);m.wr(sources[k]+1,120);
  m.wr(s.spr_rec+16*k+1,80+3*k);m.wr(s.spr_rec+16*k+2,120);
 }
 if(changed>=0){const a=sources[changed>>1]+(changed&1);m.wr(a,m.rd(a)+2);}
 m.wr(0x7079,state);m.wr(s.jn_epoch,epoch);m.wr(s.jn_last_epoch,last);
 assert.equal(call(),changed<0,'Z must describe the coordinate comparison in every state');
 assert.equal(m.rd(s.jn_last_epoch),changed<0&&state!==1?epoch:last,'only a stationary non-walking pose may validate a newer epoch');
 cases++;
}
console.log(JSON.stringify({B,cases,states:11,epochWrap:true,cancelledWalkKeepsDeadline:true,coordinateFlags:'preserved'}));
