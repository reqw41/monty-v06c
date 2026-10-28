// Прыжки на месте в стартовой комнате: по кадрам игровая Y Джо (7300) против показанной (spr_rec+1) и скачок показанной Y за кадр.
// node tools/bench/jumpframes.js  (B=папка сборки)
const fs=require('fs');const H=require('path').resolve(__dirname,'../..');process.chdir(H);
const E=require(H+'/tools/vec_emu');const sym={};for(const l of fs.readFileSync((process.env.B||'build/native')+'/monty.sym','latin1').split('\n')){const q=l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i);if(q)sym[q[1]]=parseInt(q[2],16);}
const m=E.mk((process.env.B||'build/native')+'/monty.bin');const motion=require('./joe-motion')(m,sym);let steps=0,fc=0;const log=[];
const idx=(x,y)=>{const a=(x>>3)*256+0xDF-y,b=7-(x&7);return((m.rd(0x8000+a)>>b)&1)<<2|((m.rd(0xA000+a)>>b)&1)<<1|((m.rd(0xC000+a)>>b)&1);};
const joeTop=()=>{for(let y=0;y<192;y++)for(let x=0;x<256;x+=1){const i=idx(x,y);if(i===3){/*первая строка с цветом Джо 6*/ return y;}}return -1;};
m.onInstr=(pc)=>{motion.instruction(pc);if(pc===sym.L_A5D1){steps++;m.wr(0x7049,6);}};
const K=(r,b,d)=>{if(d)m.keyboard.matrix[r]|=b;else m.keyboard.matrix[r]&=~b;};
while(fc<900){if(fc===10)K(2,2,1);if(fc===100)K(2,2,0);
 if(fc>400){const t=fc-400;K(7,0x80,(t%60)<3);}   // прыжки на месте
 fc++;m.frame();motion.frame();
 if(fc>420){log.push([fc,steps,m.rd(0x7079),(sym.jn_shown!==undefined?Math.max(m.rd(0x7300),m.rd(0x7304)):m.rd(0x7300)),(sym.jn_shown!==undefined?0xDF-m.rd(sym.spr_rec+9)-m.rd(sym.jn_shown_skip)+sym.joe_nes_rows-17:m.rd(sym.spr_rec+1)),m.rd(sym.spr_rec)]);}}
// показанная Y — из записи «нарисовано» слоя 0 (spr_rec+1), игровая — 7300
let s='';for(const r of log.slice(0,90)){s+=`${r[0]}:ш${r[1]} с${r[2]} игр${r[3]} пок${r[4]}${r[5]?'':'(нет)'}  `;}console.log(s);
const jumps=[];for(let i=1;i<log.length;i++){if(log[i][2]===2||log[i-1][2]===2)jumps.push(Math.abs(log[i][4]-log[i-1][4]));}
const h={};jumps.forEach(d=>h[d]=(h[d]||0)+1);console.log('скачок показанной Y за кадр в прыжке:',JSON.stringify(h));

console.log('задержка и скачки по завершённой логике:',JSON.stringify(motion.result()));
