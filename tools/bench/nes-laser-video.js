// The narrow horizontal beams in room (1,9) use all four original NES CHR poses.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');
const room=JSON.parse(fs.readFileSync('build/nes_full/rooms.json')).records[5].native;
assert.equal(room[10*32+2],0xE8,'room has the horizontal beam shown in screenshot');
const rom=fs.readFileSync('orig/nes/monty.nes'),poses=[];
for(let phase=0;phase<4;phase++){
 const strip=m.rd(s.full_laser_h+phase),got=Array.from({length:8},(_,y)=>m.rd(s.full_raw+8*strip+y));
 const chr=0x135+phase,want=Array.from({length:8},(_,y)=>rom[32784+16*chr+y]|rom[32784+16*chr+y+8]);
 assert.deepEqual(got,want,`horizontal beam phase ${phase}`);poses.push(got.join(','));
}
assert.equal(new Set(poses).size,4,'four visibly distinct poses');
const c=m.cpu;c.iff=false;c.iff_pending=0;c.sp=0x73be;c.pc=s.tile_belt_frames;m.wr(s.rr_t,0xE8);m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000);c.instruction();}assert.equal(c.regs[7],4,'cache builds four phases');
console.log(JSON.stringify({B,room:'1,9',laser:'horizontal',originalChr:['135','136','137','138'],poses:4}));
