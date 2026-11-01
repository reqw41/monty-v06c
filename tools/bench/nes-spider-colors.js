// Independent one-plane pixel and restore checks, including cached masks and repaint.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
assert(s.NES_GREEN_SPIDERS,'green spider build required');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
const boot=m.memory.bytes.slice();let cases=0;
function call(name,hl,b=0){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;c.regs[4]=hl>>8;c.regs[5]=hl&255;c.regs[0]=b;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<200000,name+' hung');c.instruction();}}
for(const nm of [0x2c,0x30,0x0c,0x28])for(const rows of [1,8,16])for(const cached of [false,true])for(const col of [8,31])for(const reuse of [false,true]){
 m.memory.bytes.set(boot);const k=2,rec=s.spr_rec+16*k,next=s.spr_new+16*k,page=s.SPR_SLOTS+256*k,lo=170;
 m.wr(s.sp_k,k);m.wr(s.sp_mpage,page>>8);m.wr(s.en_reuse,0);m.wr(rec+3,nm);m.wr(next+3,nm);
 for(const [off,v]of [[9,lo],[10,col],[11,rows],[12,0]])m.wr(next+off,v);
 m.wr(s.ps_hi+k,cached?0xe0:0);m.wr(s.ps_lo+k,0);m.wr(s.ps_r+k,rows);
 const masks=Array.from({length:3},(_,x)=>Array.from({length:rows},(_,y)=>(0xa5^(x*29)^(y*17))&255));
 for(let x=0;x<3;x++)for(let y=0;y<rows;y++)m.wr(cached?0xe000+x*rows+y:page+s.SM_OFS+16*x+y,masks[x][y]);
 for(let p=0;p<3;p++)for(let x=0;x<32;x++)for(let y=0;y<256;y++)m.wr(0x8000+p*0x2000+x*256+y,(p*37+x*13+y*11)&255);
 const before=m.dump();call('enemy_native_put',rec+14);
 const plane=[0x2c,0x30].includes(nm)?0:2;
 function verify(){for(let p=0;p<3;p++)for(let x=0;x<32;x++)for(let y=0;y<256;y++){
  const a=0x8000+p*0x2000+x*256+y,dy=lo-y;
  const mask=p===plane&&x>=col&&x<col+3&&dy>=0&&dy<rows?masks[x-col][dy]:0;
  assert.equal(m.rd(a),before[a]|mask,`name ${nm.toString(16)}, rows ${rows}, cached ${cached}, col ${col}, plane ${p}, ${x}/${y}`);
 }}
 verify();
 if(reuse){m.wr(s.en_reuse,1);call('enemy_native_put',rec+14);verify();}
 call('enemy_restore',rec,k);
 for(let a=0x8000;a<0xe000;a++)assert.equal(m.rd(a),before[a],'restore changed screen '+a.toString(16));
 cases++;
}
assert.equal(m.rd(s.style_pal+8),32,'shared snake/spider green byte');
assert.equal(m.rd(s.style_pal+2),255,'skulls stay white');
console.log(JSON.stringify({B,cases,spiderPoses:2,skullPoses:2,spiderPlane:'8000',skullPlane:'C000',cachedAndUncached:true,repaint:true,restore:'all three planes exact'}));
