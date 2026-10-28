// Fatal impact and fire use distinct original NES animations.
const assert=require('node:assert/strict'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');
function call(name,a=0){const c=m.cpu;c.iff=false;c.iff_pending=0;c.sp=0x73be;c.pc=s[name];c.regs[7]=a;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');c.instruction();}return c.regs[7];}
m.wr(0x7049,6);m.wr(0x7079,6);m.wr(0x707c,50);m.wr(0x7300,100);m.wr(0x7304,103);m.wr(0x7303,6);m.wr(0x7307,11);
m.wr(0x705b,4);m.wr(0x71a8,9);m.wr(s.jn_fire,1);call('hs_8A86');
assert.equal(m.rd(0x7079),9);assert.equal(m.rd(s.jn_fire),0,'hard landing clears fire cause');
for(const [timer,pose] of [[112,5],[83,5],[82,6],[53,6],[52,18]]){
 m.wr(0x70a9,timer);assert.equal(call('joe_select'),pose,`impact timer ${timer}`);
}
m.wr(0x7049,6);m.wr(0x7079,6);m.wr(0x7058,0x38);m.wr(0x7057,0);m.wr(0x7059,0);m.wr(0x705a,0);m.wr(0x705b,0x38);m.wr(0x705c,0);
call('hs_8A86');assert.equal(m.rd(0x7079),10);assert.equal(m.rd(s.jn_fire),1,'fire cause captured');
for(const [timer,pose] of [[112,20],[104,20],[103,21],[95,21],[94,22],[86,22],[85,18]]){
 m.wr(0x70a9,timer);assert.equal(call('joe_select'),pose,`fire timer ${timer}`);
}
console.log(JSON.stringify({B,impact:[5,6,18],fire:[20,21,22,18],distinct:true}));
