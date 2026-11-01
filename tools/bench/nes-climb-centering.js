// Original NES ladder and rope anchors, without a separate visual correction.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-treasure',s=symbols(B),m=E.mk(B+'/monty.bin');
let cases=0;for(let pose=0;pose<23;pose++)for(let x=0;x<240;x++){
 m.wr(s.jn_frame,pose);m.wr(s.spr_new+2,x);m.wr(0x7301,x);m.wr(0x7305,x);
 const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s.jn_visual_x;c.sp=0x73be;
 m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<100);c.instruction();}
 assert.equal(c.regs[7],x);
 assert.equal(m.rd(0x7301),x);assert.equal(m.rd(0x7305),x);assert.equal(m.rd(s.spr_new+2),x);cases++;
}
const rom=fs.readFileSync('orig/nes/monty.nes');
function bounds(tiles){const xs=[];for(let i=0;i<tiles.length;i++)for(let y=0;y<8;y++)for(let x=0;x<8;x++)if((rom[32784+16*tiles[i]+y]|rom[32784+16*tiles[i]+8+y])&(128>>x))xs.push(i*8+x);return [Math.min(...xs),Math.max(...xs)];}
const ladder=bounds([0x10f,0x110]),rope=bounds([0x10d]);
assert.deepEqual(ladder,[0,15]);assert.deepEqual(rope,[2,5]);
assert.equal(0+7.5,(ladder[0]+ladder[1])/2,'ladder axis');
assert.equal(-4+7.5,(rope[0]+rope[1])/2,'rope axis');
console.log(JSON.stringify({B,cases,ladderVisualOffset:0,ropeVisualOffset:0,gameplayCoordinates:'unchanged'}));
