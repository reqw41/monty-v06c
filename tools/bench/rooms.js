#!/usr/bin/env node
// All 99 rooms x 3 levels, immortal hero; FREE=1 lets him fall and ride belts.
'use strict';
const fs = require('fs'), path = require('path');
process.chdir(path.resolve(__dirname, '../..'));
const E = require('../vec_emu'), {symbols, profiler} = require('./logic-profile');
const B = process.env.B || 'build/native', s = symbols(B);
const samples = +(process.env.N || 128), warmup = +(process.env.WARM || 64);
const free = process.env.FREE === '1', hiddenJoe = process.env.HIDE_JOE === '1';
if (samples < 1 || warmup < 1) throw Error('N and WARM must be positive');
const rows = [];
function save(complete) {
  if(process.env.OUT) fs.writeFileSync(process.env.OUT,JSON.stringify({build:B,samples,warmup,free,hiddenJoe,complete,rows},null,2)+'\n');
}
for (const lv of process.env.LV ? [+process.env.LV] : [1,2,3]) {
  const m = E.mk(B + '/monty.bin'), p = profiler(m,s);
  const rooms = []; for (let r=0;r<9;r++) for(let c=8-r;c<=10+r;c++) rooms.push([r,c]);
  let steps=0, ri=-1, age=0, entered=false, pose=null, start=null, frames=0, hist={}, lastFrame=0;
  function teleport() {
    ri++; if(ri===rooms.length) return;
    const [r,c]=rooms[ri]; m.wr(0x705F,m.rd(0x705F)&~4);
    m.wr(0x71A7,r); m.wr(0x71A8,c); m.wr(0x7079,9);
    age=0;entered=false;pose=null;
  }
  m.onInstr=pc=>{
    p.instruction(pc);
    // Hide at the rendering boundary: hero logic can restore his colors each step.
    if (hiddenJoe && pc===s.spr_plan) {m.wr(0x7303,0);m.wr(0x7307,0);}
    if (pc===s.L_8DA2 && ri>=0 && entered) { const c=m.cpu;c.pc=m.rd(c.sp)|m.rd(c.sp+1)<<8;c.sp+=2;return; }
    if(pc!==s.L_A5D1) return;
    steps++;m.wr(0x7049,6);m.wr(0x707C,m.rd(0x7300));
    if(steps===50) {teleport();return;}
    if(ri<0 || ri===rooms.length) return;
    const [r,c]=rooms[ri];
    if(m.rd(0x71A7)!==r || m.rd(0x71A8)!==c) throw Error(`room escaped ${lv}/${r},${c}`);
    if(!entered) {
      if(m.rd(0x7079)===9 || m.rd(s.video_dirty)&4) return;
      entered=true;pose=[...Array(8)].map((_,i)=>m.rd(0x7300+i));
    }
    // Freeze the entrance pose between complete logic steps, not inside routines.
    // This keeps belts/falls from leaving the room and preserves their work per step.
    if (!free) {pose.forEach((v,i)=>m.wr(0x7300+i,v));m.wr(0x7079,0);m.wr(0x707C,pose[0]);}
    if (hiddenJoe) {m.wr(0x7303,0);m.wr(0x7307,0);}
    age++;
    if(age===warmup) {start={...p.totals};frames=m.frames;hist={};lastFrame=m.frames;}
    if(age>warmup) {const d=m.frames-lastFrame;hist[d]=(hist[d]||0)+1;lastFrame=m.frames;}
    if(age===warmup+samples) {
      const t={};for(const k of ['L','D','I','W']) t[k]=(p.totals[k]-start[k])/samples;
      const row={level:lv,row:r,col:c,steps:samples,frames:m.frames-frames,sps:50*samples/(m.frames-frames),logic:t.L,display:t.D,irq:t.I,idle:t.W,histogram:hist};rows.push(row);
      console.log(`${lv} ${r},${c} ${row.sps.toFixed(2)} logic=${Math.round(t.L)} display=${Math.round(t.D)} irq=${Math.round(t.I)} idle=${Math.round(t.W)}`);
      save(false);
      teleport();
    }
  };
  for(let f=0;ri<rooms.length;f++) {
    if(f>200000) throw Error(`timeout level ${lv}, room ${ri}`);
    if(f===10)m.keyboard.matrix[2]|=1<<lv;
    if(f===100)m.keyboard.matrix[2]&=~(1<<lv);
    m.frame();
  }
}
console.log('Slowest logic:',rows.slice().sort((a,b)=>b.logic-a.logic).slice(0,15));
save(true);
