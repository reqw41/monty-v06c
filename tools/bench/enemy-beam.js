// Враги «на луче»: экран, каким его показал луч (захват выборок видеопамяти растром), против логики.
// Кадр считается «враг пропал», если ни в одном смещении dx=-8..8, dy=-4..4 от логической позиции
// не найдено >=60 % точек его шаблона ни в одной плоскости. Отдельно — частичные (разорванные) кадры.
// B=build/quick ROOM=1,9 N=700 WALK=1 node tools/bench/enemy-beam.js
'use strict';
const path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),REF=require('./video-ref');
const B=process.env.B||'build/quick',s=symbols(B),m=E.mk(B+'/monty.bin');
const [R,C]=(process.env.ROOM||'1,9').split(',').map(Number),N=+(process.env.N||700),WALK=process.env.WALK!=='0';
const beam=new Uint8Array(4*8192);
{const P=m.ctx.PixelFiller.prototype,of=P.fetchPixels;P.fetchPixels=function(){of.call(this);const a=((this.fb_column&0xff)<<8)|(this.fb_row&0xff);const v=this.pixel32;
 for(let p=0;p<4;p++)beam[p*8192+a]=(v>>>(8*p))&255;};}
const ad=(c,y)=>c*256+255-y-(y<48?8:16);
let SRC=0;const px=(p,x,y)=>{if(x<0||x>255||y<0||y>=240)return 0;const a=ad(x>>3,y);return ((SRC?m.rd(0x8000+p*0x2000+a):beam[p*8192+a])>>(7-(x&7)))&1;};
const FAM=nm=>nm>=0x2c&&nm<=0x30?[0x2c,0x30]:nm>=0x0c&&nm<=0x28?[0x0c,0x10,0x14,0x18,0x1c,0x20,0x24,0x28]:[nm];
function match(nm,x0,top){if(process.env.FAMILY)return Math.max(...FAM(nm).map(n=>match1(n,x0,top)));return match1(nm,x0,top);}
function match1(nm,x0,top){let best=0;for(let dy=-4;dy<=4;dy++)for(let dx=-8;dx<=8;dx++){let tot=0,hit=[0,0,0,0];
 for(let y=0;y<16;y++)for(let h=0;h<2;h++){const b=REF.sprite(nm,h,y);for(let bx=0;bx<8;bx++)if(b&(128>>bx)){tot++;const X=x0+dx+8*h+bx,Y=top+dy+y;for(let p=0;p<4;p++)hit[p]+=px(p,X,Y);}}
 if(!tot)return 1;const f=Math.max(...hit)/tot;if(f>best)best=f;}return best;}
const obj=k=>0x7300+4*m.rd(0x72E0+k);
let steps=0,on=false,f0=0,fr=0,done=false,cool=0;const st={};const ex=[];
const ev=[];m.onInstr=pc=>{
 if(on&&(pc===s.restore1||pc===s.draw1||pc===s.ck_repaint||pc===s.same_place)){const f=m.v06c.filler;if(f)ev.push([pc===s.restore1?'R':pc===s.draw1?'D':pc===s.ck_repaint?'P':'S',m.cpu.b(),':'+f.raster_line]);}
 if(pc===s.draw_all||pc===s.L_A067)cool=60;
 if(pc===s.L_8DA2&&steps>60){const c=m.cpu;c.pc=m.rd(c.sp)|m.rd(c.sp+1)<<8;c.sp+=2;return;}
 if(pc!==s.L_A5D1)return;steps++;m.wr(0x7049,6);if(s.nes_amulet_ticks){m.wr(s.nes_amulet_ticks,200);m.wr(s.nes_amulet_ticks+1,0);}
 if(cool>0)cool--;
 if(steps===50){m.wr(0x71A7,R);m.wr(0x71A8,C);m.wr(0x7079,9);}
 if(steps===160){on=true;f0=m.frames;}
 if(on&&WALK){const ph=Math.floor((steps-160)/30)%2;m.keyboard.matrix[0]=(m.keyboard.matrix[0]&~0x50)|(ph?0x10:0x40);}
 if(on&&steps===160+N){on=false;done=true;}
};
// снимок логики берём в начале кадра (то, что должно быть видно в этом кадре — с допуском dx/dy)
for(;!done&&fr<40000;fr++){
 if(fr===10)m.keyboard.matrix[2]|=2;if(fr===100)m.keyboard.matrix[2]&=~2;
 const jp=obj(0),jy=m.rd(jp),jx=m.rd(jp+1);const snap=[];for(let k=2;k<6;k++){const p=obj(k),y=m.rd(p),col=m.rd(p+3)&15;if(y<192&&col&&![6,11].includes(col)){const x=m.rd(p+1);if(Math.abs(x-jx)<18&&Math.abs(y-jy)<26)continue;snap.push([k,x,(y+1)&255,m.rd(p+2)&252]);}}
 ev.length=0; m.frame();
 if(!on||cool||m.rd(0x7079)>=9)continue;
 for(const [k,x,top,nm] of snap){const f=match(nm,x,top),o=st[k]=st[k]||{frames:0,gone:0,partial:0,runs:[],run:0};o.frames++;
  if(f<0.6){o.gone++;o.run++;if(ex.length<10){const r=s.spr_rec+16*k;SRC=1;const fmem=match(nm,x,top);SRC=0;ex.push({rec:[0,1,2,3,4].map(j=>m.rd(r+j)),fmem:+fmem.toFixed(2),ev:ev.filter(e=>e[1]===k).map(e=>e.join('')).join(' '),fr:m.frames-f0,k,x,top,nm,f:+f.toFixed(2),jx:m.rd(obj(0)+1),jy:m.rd(obj(0)),st:m.rd(0x7079)});}}else{if(o.run)o.runs.push(o.run);o.run=0;if(f<0.95)o.partial++;}}
}
const out={room:R+','+C,walk:WALK,frames:m.frames-f0};
for(const k in st){const o=st[k];out['obj'+k]={кадров:o.frames,пропал:o.gone,частично:o.partial,макс_подряд:Math.max(0,...o.runs,o.run)};}
console.log(JSON.stringify(out));if(process.env.EX)console.log(JSON.stringify(ex));
