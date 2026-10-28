// Клетки против графики MSX (38 — статичный фон ZX) по VNT, fire_shown и room_colors; клетки под
// нарисованными спрайтами (spr_rec +5..+8) и ожидающие передачи (PND & 1) — пропуск.
// Незавершённая группа crit может владеть клеткой и после опустошения dlist.
// Полный framecheck отдельно проверяет и эти клетки против уже переданного фона. node cellchk.js dir [шагов] [TP]
const REF = require('./video-ref');
const fs = require('fs'); process.chdir(require('path').resolve(__dirname, '../..'));
const E = require('../vec_emu');
const dir = process.argv[2], N = +(process.argv[3] || 2000), TP = process.argv[4] === 'tp';
const sym = {}; for (const l of fs.readFileSync(dir + '/monty.sym', 'latin1').split('\n')) { const q = l.match(/^(\w+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const ROWS=sym.SCREEN_ROWS||24, TOP=sym.SCREEN_TOP??0xDF;
const m = E.mk(dir + '/monty.bin'); const K = (r, b, d) => { if (d) m.keyboard.matrix[r] |= b; else m.keyboard.matrix[r] &= ~b; };
const ROOMS = []; for (let r = 0; r < 9; r++) for (let c = 8 - r; c <= 10 + r; c++) ROOMS.push([r, c]);
let steps = 0, fc = 0, checks = 0, bad = 0; const ex = [];
const keys = (s) => { K(7, 0x80, (s >= 20 && s < 30) || (s > 200 && s % 37 < 4)); const ph = s < 100 ? -1 : Math.floor((s - 100) / 70) % 3; K(0, 0x40, ph === 0); K(0, 0x10, ph === 1); };
function check() {
  if (m.rd(sym.video_dirty) & (sym.DIRTY_ROOM | sym.DIRTY_COLOR)) return;
  const sp = []; for (let k = 0; k < 6; k++) { const a = sym.spr_rec + 16 * k; if (m.rd(a)) sp.push([m.rd(a + 5), m.rd(a + 6), m.rd(a + 7), m.rd(a + 8)]); }
  const th = m.rd(sym.fire_shown); checks++;
  for (let r=0;r<ROWS;r++)for(let c=0;c<32;c++){
    if(!(ROWS===30&&r<6)&&(m.rd(sym.PND+32*r+c)&1))continue;
    if(sp.some(([r0,r1,c0,c1])=>r>=r0&&r<=r1&&c>=c0&&c<=c1))continue;
    const t=m.rd(sym.VNT+32*r+c),anim=REF.isAnimated(sym,t);
    if(process.env.NOFIRE&&m.rd(sym.lv_idx+t)!==255&&anim)continue;
    if(process.env.SKIPF&&t>=0xD0&&t<=0xD5)continue;
    if(process.env.LIVEONLY&&m.rd(sym.lv_idx+t)===255)continue;
    let valid=false;
    for(let f=0;f<(process.env.FANY&&anim?4:1)&&!valid;f++){
      const b=REF.cell(m,sym,t,process.env.FANY&&anim?f:th,m.rd(sym.belt_shown));valid=true;
      for(let p=0;p<3&&valid;p++)for(let y=0;y<8;y++)if(m.rd(0x8000+8192*p+c*256+TOP-8*r-y)!==b[p*8+y]){valid=false;break;}
    }
    if(!valid){bad++;if(ex.length<6)ex.push(`step ${steps} cell ${r},${c} tile ${t.toString(16)}`);}
  }
}
m.onInstr = (pc) => { if (process.env.R19 && pc === sym.L_8DA2 && steps > 60) { const c = m.cpu; c.pc = m.rd(c.sp) | (m.rd(c.sp + 1) << 8); c.sp += 2; return; }
  if (pc === sym.L_A5D1) { steps++; keys(steps); m.wr(0x7049, 6); if (process.env.R19) { m.wr(0x707C, m.rd(0x7300)); if (steps === 50) { m.wr(0x705F, m.rd(0x705F) & ~4); m.wr(0x71A7, 1); m.wr(0x71A8, 9); m.wr(0x7079, 9); } } if (steps % (process.env.EVERY ? 1 : 7) === 0) check();
  if (TP && steps >= 300 && steps % 60 === 0) { const [r, c] = ROOMS[(steps / 60 - 5) % ROOMS.length]; m.wr(0x71A7, r); m.wr(0x71A8, c); m.wr(0x7079, 9); } } };
while (steps < N) { if(fc>+(process.env.FRAME_LIMIT||N*6+1000))throw Error('cellchk timeout '+JSON.stringify({steps,fc,pc:m.cpu.pc,room:[m.rd(0x71A7),m.rd(0x71A8)],state:m.rd(0x7079),source:[...Array(8)].map((_,i)=>m.rd(0x7300+i)),record:[...Array(16)].map((_,i)=>m.rd(sym.spr_rec+i)),next:[...Array(16)].map((_,i)=>m.rd(sym.spr_new+i)),jn:{frame:m.rd(sym.jn_frame),hold:m.rd(sym.jn_hold),epoch:m.rd(sym.jn_epoch),last:m.rd(sym.jn_last_epoch)}})); if (fc === 10) K(2, 2, 1); if (fc === 100) K(2, 2, 0); fc++; m.frame(); }
console.log(dir, 'проверок', checks, 'неверных клеток', bad); console.log(ex.join('\n'));

if (bad || !checks) process.exitCode = 1;
