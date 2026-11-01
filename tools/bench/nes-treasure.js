// Exact original 6502 treasure layout and PRNG vs native i8080 generator.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-treasure',s=symbols(B);
const m=E.mk(B+'/monty.bin');
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;
 m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<5000000,name+' hung at '+c.pc.toString(16));c.instruction();}}
const reference=JSON.parse(fs.readFileSync('build/nes-treasure/reference.json'));
for(const r of reference){
 assert(r.ropes.length>=5&&r.ropes.length<=7,'original NES rope count');
 assert(r.ropes.every(q=>q.column>=2&&q.column<=29&&q.row>=3&&q.row+q.length<=24&&q.length>=3),'original NES rope bounds');
 for(let i=0;i<960;i++)m.wr(s.VNT+i,i<192?0xa5:0);
 m.wr(s.FIELD_VNT+768,0x5a);m.wr(0x71a6,r.level);m.wr(s.nt_rng,r.seed&255);m.wr(s.nt_rng+1,r.seed>>8);
 call('nes_treasure_generate');
 assert.deepEqual(Array.from({length:768},(_,i)=>m.rd(s.FIELD_VNT+i)),r.cells,'NES treasure '+[r.level,r.seed]);
 assert.equal(m.rd(s.nt_rng)|(m.rd(s.nt_rng+1)<<8),r.rng,'exact PRNG consumption');
 assert.equal(r.cells.filter(t=>t===0x98).length,r.level===1?8:r.level===2?12:16);
 for(let i=0;i<192;i++)assert.equal(m.rd(s.VNT+i),0xa5,'generator must not touch HUD');
 assert.equal(m.rd(s.FIELD_VNT+768),0x5a,'field bounds');
}
console.log(JSON.stringify({B,originalNESCases:reference.length,levels:9,gems:[8,12,16],fieldCells:768,exactRng:true,bounds:'clean'}));

// Full rebuild must erase the previous room, hide enemies and render every
// field tile from the independent NES CHR reference. No gameplay ROM patches.
m.cpu.pc=0;
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]=2;if(f===100)m.keyboard.matrix[2]=0;m.frame();}
const ref=require('./nes-video-ref'),screens=[];
for(const level of [1,2,3]){
 m.wr(0x71a6,level);m.wr(0x71a7,9);m.wr(0x71a8,10);m.wr(0x705f,0x28);m.wr(0x70ac,178);
 m.wr(0x7047,1);m.wr(0x7048,1);m.wr(s.nes_q_idle,1);
 m.wr(0x7303,0);m.wr(0x7307,0);m.wr(0x7049,6);
 call('L_A60B');
 const want=reference.find(r=>r.level===level&&r.seed===0x101);
 assert.deepEqual(Array.from({length:768},(_,i)=>m.rd(s.FIELD_VNT+i)),want.cells,'room wrapper');
 for(let slot=2;slot<6;slot++)assert.equal(m.rd(0x7303+4*slot),0,'treasure hides old enemies');
 assert.equal(m.rd(s.nf_snake_count),0);
 call('room_redraw');
 for(let i=0;i<768;i++){
  const row=6+(i>>5),col=i&31,t=want.cells[i],bytes=ref.cell(m,s,t,m.rd(s.fire_shown),m.rd(s.belt_shown));
  for(let p=0;p<3;p++)for(let y=0;y<8;y++)assert.equal(m.rd(0x8000+p*8192+col*256+255-16-row*8-y),bytes[p*8+y],'treasure pixel '+[level,i,p,y]);
 }
 if(process.env.OUT){
  fs.mkdirSync(process.env.OUT,{recursive:true});const pixels=Buffer.alloc(65536);
  for(let y=0;y<256;y++)for(let x=0;x<256;x++){const a=(x>>3)*256+255-y,b=128>>(x&7);pixels[y*256+x]=[4,2,1].reduce((v,k,p)=>v+(m.rd(0x8000+p*8192+a)&b?k:0),0);}
  fs.writeFileSync(path.join(process.env.OUT,'level-'+level+'.idx'),pixels);
  fs.writeFileSync(path.join(process.env.OUT,'level-'+level+'.json'),JSON.stringify({palette:Array.from({length:8},(_,i)=>m.rd(s.pal+2*i))}));
 }
 screens.push(level);
 // Each gem is collected once for 1000 points, through the real pickup path.
 const pos=want.cells.indexOf(0x98),address=192+pos;
 m.wr(0x71b0,address&255);m.wr(0x71b1,address>>8);m.cpu.regs[7]=0x44;m.cpu.regs[1]=0;
 m.wr(0x7017,0);m.wr(0x7018,0);m.wr(0x7019,0);m.wr(0x71b2,255);
 const flags=Array.from({length:0xc6},(_,i)=>m.rd(0x70c0+i));
 call('L_901B');
 assert.deepEqual(Array.from({length:0xc6},(_,i)=>m.rd(0x70c0+i)),flags,'bonus jewel must not alter pyramid object flags');
 assert.equal(m.rd(0x7018),0x10,'1000 BCD points');
 for(const delta of [0,1,32,33])assert.equal(m.rd(s.VNT+address+delta),0,'collected gem disappears');
}
console.log(JSON.stringify({B,renderedLevels:screens,pixelsCompared:3*768*8*8,gemsCollected:3,scoreEach:1000,enemiesHidden:true}));
