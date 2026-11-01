// Заполнение квазидиска образами Джо для опыта NES_QD: все кадры × 2 направления × 8 сдвигов, каждый по 512 байт (страница = 128 образов).
// Образы строит настоящая joe_prepare с обычным ключом (стандартные skip/rows).
'use strict';
const path=require('path');
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
function fill(m,B){
 const s=symbols(B);
 const mem=m.memory,FR=23;
 const wrQ=(pg,a,v)=>{mem.bytes[mem.tobank((a&0xffff)+((pg+1)<<16))]=v;};
 const sq=symbols(process.env.QD_GAME||'build/qd');const top=Array.from({length:FR},(_,i)=>m.rd(sq.joe_top_rows+i));
 // отдельный экземпляр эмулятора для сборки образов, чтобы не трогать состояние игры
 const w=E.mk(B+'/monty.bin');
 for(let f=0;f<20;f++)w.frame();
 const call=name=>{const c=w.cpu;c.iff=false;c.iff_pending=0;c.sp=0x73be;w.wr(c.sp,s.unit_trap&255);w.wr(c.sp+1,s.unit_trap>>8);c.pc=s[name];for(let n=0;c.pc!==s.unit_trap;n++){if(n>1e6)throw Error(name+' hung');c.instruction();}};
 let count=0;
 for(let f=0;f<FR;f++)for(let d=0;d<2;d++)for(let sh=0;sh<8;sh++){
  const skip=top[f],rows=FR-skip;
  w.wr(s.jn_frame,f);w.wr(s.jn_dir,d?0x80:0);w.wr(s.jn_skip,skip);w.wr(s.jn_rows_count,rows);w.wr(s.spr_new+2,sh);
  for(let i=0;i<5;i++)w.wr(s.jn_key+i,255);
  if(s.jn_qd!==undefined)w.wr(s.jn_qd,0);
  // принудительно обычная сборка: образ вне квазидиска
  call('joe_prepare');
  const idx=(f*2+d)*8+sh,pg=idx>>7,off=(idx&127)<<9;
  for(let i=0;i<12*FR;i++)wrQ(pg,off+i,w.rd(s.JOE_PICTURE+i));
  count++;
 }
 return count;
}
module.exports={fill};
