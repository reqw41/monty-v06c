// GAME OVER restores the native title and permits a fresh level selection.
'use strict';
const assert=require('assert/strict'),fs=require('fs'),path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');
const title=fs.readFileSync('build/nes_title/title_screen_full.raw');
assert.equal(title.length,0x6000);
const cold=fs.readFileSync(B+'/monty.bin');let musicPlayed=0,titleMusic=-1,steps=0,forced=0,restarts=0,entered=false,after=0,menus=0,overlays=0;
const selected=[2,3];
m.onInstr=pc=>{
 if(pc===s.go1){
  if(overlays<forced){
   for(let plane=0;plane<3;plane++)for(let col=0;col<32;col++)for(let y=0;y<8;y++){
    const base=0x8000+0x2000*plane+256*col;
    assert.equal(m.rd(base+255-y),0,`top margin ${plane}/${col}/${y}`);
    assert.equal(m.rd(base+199-y),0,`HUD gap ${plane}/${col}/${y}`);
   }
   assert([0x8000,0xA000,0xC000].some(base=>[...Array(32)].some((_,col)=>[...Array(8)].some((_,y)=>m.rd(base+256*col+y)))),
    'the field reaches the bottom eight physical scanlines');
   const glyphs=new Map();
   for(const base of [s.font_tab,s.font_extra])for(let p=base;m.rd(p)&&m.rd(p)!==255;p+=9)
    glyphs.set(String.fromCharCode(m.rd(p)),Array.from({length:8},(_,y)=>m.rd(p+1+y)));
   const line='GAME OVER';
   for(let i=0;i<line.length;i++)for(let plane=0;plane<3;plane++)for(let y=0;y<8;y++){
    const addr=0x8000+0x2000*plane+256*(11+i)+s.SCREEN_TOP-8*15-y;
    assert.equal(m.rd(addr),plane===2?(glyphs.get(line[i])||Array(8).fill(0))[y]:0,`white GAME OVER pixel ${i}/${plane}/${y}`);
   }
   assert.equal(m.rd(s.cmap+15),1,'fixed white GAME OVER ink');
   assert.equal(m.rd(s.pal+2),255,'white palette is independent of the room');
   overlays++;
  }
  m.keyboard.matrix[7]|=128;
 }
 if(pc===s.warm_restart&&titleMusic>=0){const p=m.rd(s.nes_m_ptr)|m.rd(s.nes_m_ptr+1)<<8;assert.notEqual(p,titleMusic,'title music played while waiting');musicPlayed++;titleMusic=-1;}
 if(pc===s.title_warm_menu&&menus===forced-1){
  // HUD digits (level, record) are drawn over the restored title: rows 24..39, columns 14..29.
  const hudDigit=i=>{const col=(i>>8)&31,y=255-(i&255);return (col>=14&&col<30&&y>=24&&y<40)||y>=8*s.TITLE_SCENE_ROW0;}; // + game-drawn scene (nes-title-font, nes-title-palette)
  for(let i=0;i<title.length;i++)if(!hudDigit(i))assert.equal(m.rd(0x8000+i),title[i],`restored title byte ${i.toString(16)}`);
  assert.equal(m.rd(s.pal+2*s.NES_TITLE_TEXT_SLOT),173,'NES title ink');
  assert.equal(m.rd(s.cmap+15),s.NES_TITLE_TEXT_SLOT,'menu uses title credit ink');
  assert.equal(m.rd(s.pal+2),255,'white title rope');
  // музыка заставки восстановлена (копия под E040) и играет
  assert.equal(m.rd(s.nes_pitch_page),0xE0,'title pitch page after GAME OVER');
  assert.equal(m.rd(s.nes_loop),1,'title loops');
  for(let i=0;i<64;i++)assert.equal(m.rd(0xE040+i),cold[0xEC40+i],'title copy note table '+i);
  titleMusic=m.rd(s.nes_m_ptr)|m.rd(s.nes_m_ptr+1)<<8;
  menus++;
  m.keyboard.matrix[7]&=~128;
  m.keyboard.matrix[2]|=1<<selected[menus-1];
 }
 if(pc===s.warm_restart){restarts++;entered=true;}
 if(pc===s.L_A59D&&entered){
  assert.equal(m.cpu.regs[0],selected[restarts-1],`selected level ${restarts}`);
  for(let p=0x70C0;p<0x7186;p++)assert.equal(m.rd(p),0,'persistent flag '+p.toString(16));
  for(const p of [0x7012,0x7068,0x7073,0x7074])assert.equal(m.rd(p),2,'process counter');
  assert.equal(m.rd(0x7303),6);assert.equal(m.rd(0x7307),11);
  m.keyboard.matrix[2]=0;entered=false;
 }
 if(pc===s.L_A5D1){
  steps++;if(restarts===2)after++;
  if((steps===300||steps===650)&&forced<2){
   forced++;m.wr(0x70C0,255);m.wr(0x7017,0x45);m.cpu.sp=s.GSTACK;m.cpu.pc=s.game_over;
  }
 }
};
for(let f=0;after<300&&f<5000;f++){
 if(f===10)m.keyboard.matrix[2]|=2;if(f===100&&restarts===0)m.keyboard.matrix[2]&=~2;
 m.frame();
}
assert.equal(overlays,2);assert.equal(menus,2);assert.equal(restarts,2);assert(after>=300,'game stopped after restart');
if(s.nt_jump_curve!==undefined)for(let i=0;i<s.nt_motion_end-s.nt_jump_curve;i++)
 assert.equal(m.rd(s.nt_jump_curve+i),m.img[s.nt_motion_source+i],'treasure jump survives GAME OVER');
assert.equal(m.rd(0x71A6),3);assert.equal(m.rd(0x7017),0);
console.log(JSON.stringify({B,restarts,selected,menus,overlays,stepsAfterSecond:after,level:m.rd(0x71A6),musicPlayed,bootstrap:'title restored from permanent ZX0 stream'}));
