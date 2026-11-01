// Real-i8080 byte specializations; compare output and background restoration.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-physics-checked',P=process.env.SPECIAL||'build/joe-byte-special',s=symbols(B);
assert.equal(s.JOE_BACKGROUND_STRIDE,2,'two-byte background required');
assert.equal(s.NES_JOE_BLEND_MODE,1,'two-plane Joe required');
const base={mode:'baseline',m:E.mk(B+'/monty.bin'),pc:s.joe_put,rows:[s.jn_put_two,s.jn_put_two_second],code:s.joe_restore-s.joe_put};
const modes=['transparent','opaque','transparent-first','opaque-first'].map(mode=>{
 const dir=P+'/'+mode,p=symbols(dir),m=E.mk(B+'/monty.bin'),blob=fs.readFileSync(dir+'/put.bin');for(let i=0;i<blob.length;i++)m.wr(p.special_begin+i,blob[i]);
 return {mode,m,pc:p.special_joe_put,rows:[p.special_jn_put_two,p.special_jn_put_two_second],code:blob.length};
});
const builds=[base,...modes],data=[],counts={},fullCounts={};let checked=0;
function call(q,pc){const {m}=q,c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=pc;c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);let cycles=0,setup=null;
 for(let i=0;c.pc!==s.unit_trap;i++){assert(i<30000,'hung '+q.mode);if(setup===null&&q.rows.includes(c.pc))setup=cycles;c.instruction();cycles+=c.vcycles;}
 assert.equal(c.sp,0x73c0,'balanced stack '+q.mode);return {total:cycles,setup:setup??cycles};}
for(let pose=0;pose<23;pose++)for(const mirror of [0,128])for(let shift=0;shift<8;shift++){
 const first=base.m.rd(s.joe_top_rows+pose);
 for(let skip=first;skip<23;skip++)for(const rows of new Set([1,23-skip])){
  const full=skip===first&&rows===23-first,cols=shift?3:2,low=[0,7,239,255][(pose+skip+rows+shift)%4],xcol=15;
  for(let i=0;i<12*23;i++)base.m.wr(s.JOE_PICTURE+i,0xa5);
  for(let i=0;i<5;i++)base.m.wr(s.jn_key+i,255);
  for(const[a,v]of[[s.jn_frame,pose],[s.jn_dir,mirror],[s.spr_new+2,120+shift],[s.jn_skip,skip],[s.jn_rows_count,rows]])base.m.wr(a,v);
  const prep=call(base,s.joe_prepare).total,picture=Array.from({length:12*23},(_,i)=>base.m.rd(s.JOE_PICTURE+i));
  for(let i=0;i<cols*rows;i++){const mask=picture[4*i],kind=mask===255?'transparent':mask===0?'opaque':'mixed';counts[kind]=(counts[kind]||0)+1;if(full)fullCounts[kind]=(fullCounts[kind]||0)+1;}
  const pixels=new Map();
  for(let col=-1;col<=cols;col++)for(let row=-1;row<=rows;row++)for(const plane of [0x8000,0xa000,0xc000]){
   const addr=plane+256*(xcol+col)+((low-row)&255);pixels.set(addr,((addr*17)+(pose*29)+(row*31)+shift+mirror+skip)&255);
  }
  const timings=[],backgrounds=[];
  for(const q of builds){const {m}=q;
   for(let i=0;i<picture.length;i++)m.wr(s.JOE_PICTURE+i,picture[i]);
   for(const[a,v]of pixels)m.wr(a,v);
   for(let i=0;i<2*3*23;i++)m.wr(s.JOE_BACKGROUND+i,0x5a);
   for(const target of [s.spr_rec,s.spr_new])for(const[o,v]of[[7,xcol],[8,xcol+cols-1],[9,low],[10,xcol],[11,rows]])m.wr(target+o,v);
   for(const[a,v]of[[s.jn_hold,0],[s.jn_frame,pose],[s.jn_dir,mirror],[s.jn_skip,skip]])m.wr(a,v);
   const draw=call(q,q.pc);timings.push({draw:draw.total,setup:draw.setup,prep});
   backgrounds.push(Buffer.from(Array.from({length:2*3*23},(_,i)=>m.rd(s.JOE_BACKGROUND+i))));
   const expected=new Map(pixels);
   for(let col=0;col<cols;col++)for(let r=0;r<rows;r++){
    const k=4*(col*rows+r),a=256*(xcol+col)+((low-r)&255),mask=picture[k];
    expected.set(0xc000+a,(pixels.get(0xc000+a)&mask)|picture[k+1]);expected.set(0xa000+a,(pixels.get(0xa000+a)&mask)|picture[k+3]);
   }
   for(const[a,v]of expected){assert.equal(m.rd(a),v,JSON.stringify({mode:q.mode,pose,mirror,shift,skip,rows,a}));checked++;}
   timings.at(-1).restore=call(q,s.joe_restore).total;
   for(const[a,v]of pixels){assert.equal(m.rd(a),v,'restore '+JSON.stringify({mode:q.mode,pose,mirror,shift,skip,rows,a}));checked++;}
  }
  for(let i=1;i<backgrounds.length;i++)assert.deepEqual(backgrounds[i],backgrounds[0],'identical background format');
  data.push({pose,mirror,shift,skip,rows,full,timings});
 }
}
function summarize(rows,index){const mean=f=>+(rows.reduce((sum,q)=>sum+f(q),0)/rows.length).toFixed(2);return {cases:rows.length,baselineDraw:mean(q=>q.timings[0].draw),draw:mean(q=>q.timings[index].draw),drawSaved:mean(q=>q.timings[0].draw-q.timings[index].draw),baselineTotal:mean(q=>q.timings[0].draw+q.timings[0].prep+q.timings[0].restore),total:mean(q=>q.timings[index].draw+q.timings[index].prep+q.timings[index].restore),baselineSetup:mean(q=>q.timings[0].setup),setup:mean(q=>q.timings[index].setup),minDrawSaving:Math.min(...rows.map(q=>q.timings[0].draw-q.timings[index].draw)),maxDrawSaving:Math.max(...rows.map(q=>q.timings[0].draw-q.timings[index].draw))};}
const full=data.filter(q=>q.full),report={B,isolated:true,cases:data.length,fullCases:full.length,pixelAndRestoreComparisons:checked,byteClassesFull:fullCounts,byteClassesAll:counts,modes:modes.map((q,i)=>({mode:q.mode,code:q.code,extraCode:q.code-base.code,extraData:0,all:summarize(data,i+1),full:summarize(full,i+1),walking:summarize(full.filter(z=>z.pose<=4),i+1)})),baselineCode:base.code};
fs.writeFileSync(P+'/comparison.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
