// Compare prepared bytes with the frozen release, including every clipping row.
// Enemy masks additionally have an independent reference from raw source bits.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const dirs=process.argv.slice(2);assert.equal(dirs.length,2,'pass before and after build directories');
const builds=dirs.map(B=>({B,s:symbols(B),m:E.mk(B+'/monty.bin')}));
function call(q,name){const {m,s}=q,c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;
 m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);let cycles=0;
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<20000,name+' hung');c.instruction();cycles+=c.vcycles;}
 assert.equal(c.sp,0x73c0,'balanced stack');return cycles;
}
const results={joe:[],enemy:[]};
for(let pose=0;pose<23;pose++)for(const mirror of [0,128])for(let shift=0;shift<8;shift++){
 const first=builds[0].m.rd(builds[0].s.joe_top_rows+pose);
 for(let skip=first;skip<23;skip++)for(const rows of new Set([1,23-skip])){
  const pictures=[],cycles=[];
  for(const q of builds){const {m,s}=q;
   for(let a=s.JOE_PICTURE;a<s.JOE_PICTURE+12*23;a++)m.wr(a,0xa5);
   for(let i=0;i<5;i++)m.wr(s.jn_key+i,255);
   for(const [a,v]of [[s.jn_frame,pose],[s.jn_dir,mirror],[s.spr_new+2,120+shift],[s.jn_skip,skip],[s.jn_rows_count,rows]])m.wr(a,v);
   cycles.push(call(q,'joe_prepare'));
   pictures.push(Buffer.from(Array.from({length:12*23},(_,i)=>m.rd(s.JOE_PICTURE+i))));
   const snapshot=pictures.at(-1),cached=call(q,'joe_prepare');assert(cached<1000,'same key must avoid rebuild');
   assert.deepEqual(Buffer.from(Array.from({length:12*23},(_,i)=>m.rd(s.JOE_PICTURE+i))),snapshot,'cached picture unchanged');
  }
  assert.deepEqual(pictures[1],pictures[0],`Joe pose=${pose} mirror=${mirror} shift=${shift} skip=${skip} rows=${rows}`);
  results.joe.push({pose,mirror,shift,skip,rows,before:cycles[0],after:cycles[1]});
 }
}
for(let name=0x0c;name<=0x30;name+=4)for(let shift=0;shift<8;shift++)for(let first=0;first<16;first++)for(let rows=1;rows<=16-first;rows++){
 const masks=[],cycles=[];
 for(const q of builds){const {m,s}=q;
  for(let i=0;i<4;i++)m.wr(s.mk_key+8+i,255);
  for(let i=0;i<48;i++)m.wr(s.SPR_SLOTS+512+s.SM_OFS+i,0xa5);
  for(const [a,v]of [[s.sp_k,2],[s.sp_name,name],[s.sp_x,120+shift],[s.sm_off,first],[s.st_rows,rows]])m.wr(a,v);
  cycles.push(call(q,'spr_masks'));
  const base=s.SPR_SLOTS+512+s.SM_OFS,src=m.rd(s.sprite_sources+(name-12)/2)|(m.rd(s.sprite_sources+(name-12)/2+1)<<8);
  const mask=Buffer.from(Array.from({length:48},(_,i)=>m.rd(base+i)));masks.push(mask);
  for(let r=0;r<rows;r++)for(let col=0;col<(shift?3:2);col++){
   const bits=(m.rd(src+first+r)<<16)|(m.rd(src+16+first+r)<<8);
   assert.equal(mask[col*16+r],(bits>>>shift>>>((2-col)*8))&255,'raw enemy bits');
  }
  const cached=call(q,'spr_masks');assert(cached<1000,'same enemy key must avoid rebuild');
  assert.deepEqual(Buffer.from(Array.from({length:48},(_,i)=>m.rd(base+i))),mask,'cached mask unchanged');
 }
 assert.deepEqual(masks[1],masks[0],`enemy name=${name} shift=${shift} first=${first} rows=${rows}`);
 results.enemy.push({name,shift,first,rows,before:cycles[0],after:cycles[1]});
}
function summary(rows){const avg=k=>+(rows.reduce((n,q)=>n+q[k],0)/rows.length).toFixed(2);return {cases:rows.length,before:avg('before'),after:avg('after'),savingPercent:+(100*(1-avg('after')/avg('before'))).toFixed(2)};}
const report={dirs,joe:summary(results.joe),enemy:summary(results.enemy),joeFull:summary(results.joe.filter(q=>q.rows===23-q.skip&&q.skip===builds[0].m.rd(builds[0].s.joe_top_rows+q.pose))),enemyFull:summary(results.enemy.filter(q=>q.rows===16&&q.first===0)),all:results};
if(process.env.OUT)fs.writeFileSync(process.env.OUT,JSON.stringify(report,null,2)+'\n');
const {all,...brief}=report;console.log(JSON.stringify(brief));
