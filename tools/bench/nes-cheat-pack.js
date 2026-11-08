// Reuse only empty high trim records; trainer code must survive every table write.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
assert.equal(s.NES_CHEAT_PACKED,1);assert.equal(s.SPR_TRIM_COUNT,32);
assert.equal(s.cheat_code_begin,s.spr_trim+128);assert(s.cheat_code_end<=s.spr_trim+256);
function call(machine,syms,name,a=0){const c=machine.cpu;c.iff=false;c.iff_pending=0;c.pc=syms[name];c.sp=0x73be;c.regs[7]=a;
 machine.wr(c.sp,syms.unit_trap&255);machine.wr(c.sp+1,syms.unit_trap>>8);let cycles=0;
 for(let n=0;c.pc!==syms.unit_trap;n++){assert(n<100000,name+' hung');c.instruction();cycles+=c.vcycles||0;}
 return cycles;
}
for(let f=0;f<120;f++)m.frame();
const code=Array.from(m.img.slice(s.cheat_code_begin,s.cheat_code_end));
const check=()=>assert.deepEqual(Array.from({length:code.length},(_,i)=>m.rd(s.cheat_code_begin+i)),code,'trainer code overwritten');
let emptySources=0,records=0,cases=0;
for(let name=128;name<256;name+=4){call(m,s,'sprite_source',name);const hl=m.cpu.regs[4]*256+m.cpu.regs[5];
 assert(Array.from({length:32},(_,i)=>m.rd(hl+i)).every(v=>v===0),'discarded sprite source must be empty');emptySources++;
}
call(m,s,'trim_build');check();
for(let name=0;name<128;name+=4){call(m,s,'sprite_source',name);const hl=m.cpu.regs[4]*256+m.cpu.regs[5];let first=255,last=0,left=0,right=0;
 for(let y=0;y<16;y++){const l=m.rd(hl+y),r=m.rd(hl+16+y);left|=l;right|=r;if(l|r){if(first===255)first=y;last=y;}}
 assert.deepEqual([m.rd(s.spr_trim+name),m.rd(s.spr_trim+name+1),m.rd(s.spr_trim+name+2)],[s.PS_BLOCKS&&name>=0x10&&name<=0x28?1:first,s.PS_BLOCKS&&name>=0x10&&name<=0x28?14:last,(!left?1:0)|(!right?2:0)] /* катящийся череп: общее окно 1..14 */);records++;
}
const base=process.env.BASE,old=base?E.mk(base+'/monty.bin'):null,os=base?symbols(base):null;if(old){for(let f=0;f<120;f++)old.frame();call(old,os,'trim_build');}
let delta=null;
for(let name=0;name<256;name+=4)for(const rows of[1,8,16])for(const y of[0,47,48,224,239,255]){
 for(const [machine,syms]of old?[[m,s],[old,os]]:[[m,s]]){
  machine.wr(syms.sp_name,name);machine.wr(syms.sp_y,y);machine.wr(syms.sp_x,0);machine.wr(syms.st_rows,rows);machine.wr(syms.sv_lo,200);
 }
 const cycles=call(m,s,'trim_sprite');
 if(name>=128)assert.equal(!!m.cpu.zf,true,'high sprite remains empty');
 if(old){const before=call(old,os,'trim_sprite');assert.equal(!!m.cpu.zf,!!old.cpu.zf,'same empty status');
  if(!m.cpu.zf){for(const n of['sm_off','st_rows','sv_lo','sv_zc'])assert.equal(m.rd(s[n]),old.rd(os[n]),'same '+n);if(delta===null)delta=cycles-before;assert(cycles<=before,'valid sprite trim must not get slower');}
 }
 cases++;
}
check();
const live=E.mk(B+'/monty.bin');for(let f=0;f<560;f++){if(f===10)live.keyboard.matrix[2]=2;if(f===100)live.keyboard.matrix[2]=0;live.frame();}
let shifts=0;for(let i=0;i<s.PS_N*(s.PS_SHIFTS||8);i++)if(live.rd(s.ps_tab+2*i)||live.rd(s.ps_tab+2*i+1))shifts++;
assert.equal(shifts,s.PS_BLOCKS||s.PS_N*(s.PS_SHIFTS||8),'every configured enemy shift must be prepared');
for(let i=0;i<code.length;i++)assert.equal(live.rd(s.cheat_code_begin+i),code[i],'boot/cache damaged trainer code');
console.log(JSON.stringify({B,emptySources,records,trimCases:cases,trainerBytes:code.length,lowCacheBytes:s.PS_TOP-s.ps_heap,cachedShifts:shifts,trimCycleDelta:delta}));
