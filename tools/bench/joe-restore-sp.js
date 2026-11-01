// Exhaustive row counts, widths and page-boundary offsets for the SP restore.
const assert=require('node:assert/strict'),path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-blend80-sp',s=symbols(B),m=E.mk(B+'/monty.bin');
assert(s.jr_sp_pair,'SP restore build required');
let cases=0;
for(let rows=1;rows<=23;rows++)for(let cols=1;cols<=3;cols++)for(const x of [0,15,29])for(const low of [0,7,31,239,255]){
 const want=Buffer.alloc(0x6000);
 for(let i=0;i<want.length;i++){want[i]=(i*17+(i>>8)*29+rows)&255;m.wr(0x8000+i,want[i]);}
 for(let c=0;c<cols;c++)for(let r=0;r<rows;r++){
  const stride=s.JOE_BACKGROUND_STRIDE||3;
  const a=(x+c)*256+((low-r)&255),k=stride*(c*rows+r),v=(k*31+rows*7)&255;
  m.wr(s.JOE_BACKGROUND+k,v);m.wr(s.JOE_BACKGROUND+k+1,v^0xA5);
  if(stride===3)m.wr(s.JOE_BACKGROUND+k+2,0xCC);
  want[0x4000+a]=v;want[0x2000+a]=v^0xA5;
 }
 for(const [offset,v] of [[7,x],[8,x+cols-1],[9,low],[10,x],[11,rows]])m.wr(s.spr_rec+offset,v);
 const cpu=m.cpu;cpu.iff=false;cpu.iff_pending=0;cpu.regs[0]=0x12;cpu.regs[1]=0x34;cpu.sp=0x73BE;cpu.pc=s.joe_restore;
 m.wr(cpu.sp,s.unit_trap&255);m.wr(cpu.sp+1,s.unit_trap>>8);
 for(let n=0;cpu.pc!==s.unit_trap;n++){assert(n<10000,'restore hung');cpu.instruction();}
 assert.equal(cpu.sp,0x73C0);assert.equal(cpu.regs[0],0x12);assert.equal(cpu.regs[1],0x34);
 for(let i=0;i<want.length;i++)assert.equal(m.rd(0x8000+i),want[i],`rows=${rows} cols=${cols} x=${x} low=${low} address=${(0x8000+i).toString(16)}`);
 cases++;
}
console.log(JSON.stringify({B,cases,rows:'1..23',columns:'1..3',thirdPlane:'unchanged',outsideRectangle:'unchanged',stackAndBC:'preserved'}));
