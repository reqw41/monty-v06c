// Compare cold helpers with the unmodified main build, including real i8080 costs.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const builds=[process.env.BASE||'build/mh2-base',process.env.B||'build/mh2-reserve'];
const machines=builds.map(B=>{const s=symbols(B),m=E.mk(B+'/monty.bin');for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}return {s,m,boot:m.memory.bytes.slice()};});
function call(x,name,{a=0,bc=0,de=0,hl=0}={}){const {s,m}=x,c=m.cpu;c.iff=false;c.iff_pending=0;c.regs[7]=a;c.regs[0]=bc>>8;c.regs[1]=bc&255;c.regs[2]=de>>8;c.regs[3]=de&255;c.regs[4]=hl>>8;c.regs[5]=hl&255;c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);c.pc=s[name];let cycles=0;for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');c.instruction();cycles+=c.vcycles;}return cycles;}
const result={builds,images:[],blits:[],text:[],fills:[],live:[]};
for(let mode=0;mode<64;mode++){
 const got=machines.map(x=>{const {m,s}=x;m.memory.bytes.set(x.boot);for(let i=0x8000;i<0xe000;i++)m.wr(i,(i*19+23)&255);for(let i=0;i<8;i++)m.wr(0xe000+i,(i*37+mode*11)&255);m.wr(s.tile_dst,0xf8);m.wr(s.tile_dst+1,0x7c);const cycles=call(x,'da_img',{bc:0x5500|mode,de:0xe000});assert.equal(m.cpu.regs[0],0x55);assert.equal(m.cpu.regs[1],mode);assert.equal((m.cpu.regs[2]<<8)|m.cpu.regs[3],0xe000);return {cycles,bytes:Array.from({length:24},(_,i)=>m.rd(0x7cf8+i))};});
 assert.deepEqual(got[1].bytes,got[0].bytes,'image mode '+mode);result.images.push(got.map(r=>r.cycles));
}
for(const row of [2,3,10])for(const col of [0,14,18,29,31]){
 const got=machines.map(x=>{const {m,s}=x;m.memory.bytes.set(x.boot);for(let i=0x8000;i<0xe000;i++)m.wr(i,(i*19+23)&255);for(let i=0;i<24;i++)m.wr(0xe000+i,(i*37+row*11)&255);m.wr(s.tile_src,0);m.wr(s.tile_src+1,0xe0);m.wr(s.rr_r,row);m.wr(s.rr_c,col);const cycles=call(x,'da_blit',{bc:0x1234,hl:((0x80+col)<<8)|(255-8*row)});return {cycles,bytes:Array.from({length:0x6000},(_,i)=>m.rd(0x8000+i))};});
 assert.deepEqual(got[1].bytes,got[0].bytes,'blit '+row+','+col);result.blits.push(got.map(r=>r.cycles));
}
for(let ink=0;ink<8;ink++){
 const got=machines.map(x=>{const {m,s}=x;m.memory.bytes.set(x.boot);for(let i=0x8000;i<0xe000;i++)m.wr(i,(i*19+23)&255);m.wr(s.cmap+15,ink);const cycles=call(x,'txt_draw',{hl:s.game_over_txt,de:0x1eb});return {cycles,bytes:Array.from({length:0x6000},(_,i)=>m.rd(0x8000+i))};});
 assert.deepEqual(got[1].bytes,got[0].bytes,'text ink '+ink);result.text.push(got.map(r=>r.cycles));
}
for(const count of [16,32,256,768]){
 const got=machines.map(x=>{const {m}=x;m.memory.bytes.set(x.boot);for(let i=0x8000;i<0x8400;i++)m.wr(i,0x55);const cycles=call(x,'memfill_f',{bc:count,de:0x1234,hl:0x8000});assert.equal((m.cpu.regs[2]<<8)|m.cpu.regs[3],0x1234);assert.equal((m.cpu.regs[0]<<8)|m.cpu.regs[1],0);assert.equal((m.cpu.regs[4]<<8)|m.cpu.regs[5],0x8000+count);return {cycles,bytes:Array.from({length:1024},(_,i)=>m.rd(0x8000+i))};});
 assert.deepEqual(got[1].bytes,got[0].bytes,'fill '+count);result.fills.push(got.map(r=>r.cycles));
}
{
 const got=machines.map(x=>{const {m,s}=x;m.memory.bytes.set(x.boot);m.wr(s.flp3,0xC9);for(let i=0;i<8;i++)m.wr(0xe000+i,i*31);const cycles=call(x,'fl_fast1',{bc:0x1234,de:0xe000,hl:0x80af});assert.equal((m.cpu.regs[0]<<8)|m.cpu.regs[1],0x1234);return {cycles,bytes:Array.from({length:8},(_,i)=>m.rd(0x80af-i))};});
 assert.deepEqual(got[1].bytes,got[0].bytes,'live strip');result.live.push(got.map(r=>r.cycles));
}
// The installed helper is byte-for-byte identical despite its new address.
assert.deepEqual(Array.from({length:11},(_,i)=>machines[1].m.rd(machines[1].s.nt_jump_ended+i)),Array.from({length:11},(_,i)=>machines[0].m.rd(machines[0].s.nt_jump_ended+i)));
for(const key of ['images','blits','text','fills','live']){const pairs=result[key];console.log(key,pairs.length,'cases, delta cycles',Math.min(...pairs.map(p=>p[1]-p[0])),Math.max(...pairs.map(p=>p[1]-p[0])));}
if(process.env.OUT)fs.writeFileSync(process.env.OUT,JSON.stringify(result,null,2)+'\n');
