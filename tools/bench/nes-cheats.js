// Trainer is entered only at the menu. Real keyboard edges skip one level;
// collision deaths still animate/respawn while all life-loss routes retain lives.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B);
function call(m,name,a=0){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;c.regs[7]=a;
 m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);
 for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');c.instruction();}}
const menu=E.mk(B+'/monty.bin');for(let f=0;f<120;f++)menu.frame();let menuCases=0;
for(const [f,d,expected,level]of[[0,0,0,0],[8,0,0,0],[32,0,0,0],[40,0,1,1],[40,8,1,1],[0,2,0,0],[0,4,0,0],[0,8,0,0]]){
 menu.wr(s.kbmat+1,f);menu.wr(s.kbmat+2,d);menu.wr(s.cheat_mode,0);call(menu,'cheat_menu_keys');
 assert.equal(menu.rd(s.cheat_mode),expected);assert.equal(menu.cpu.cf?1:0,level?1:0);
 if(level)assert.equal(menu.cpu.regs[0],level);menuCases++;
}
function boot(cheat){const m=E.mk(B+'/monty.bin');let steps=0;
 m.onInstr=pc=>{if(pc===s.L_A5D1)steps++;};
 for(let f=0;f<800&&steps<80;f++){
  if(f===10){if(cheat)m.keyboard.matrix[1]=40;else m.keyboard.matrix[2]=2;}
  if(f===100){m.keyboard.matrix[1]=0;m.keyboard.matrix[2]=0;}
  m.frame();
 }
 assert(steps>=80,'menu start/intro');assert.equal(m.rd(s.cheat_mode),cheat?1:0);
 assert.equal(m.rd(0x71a6),1);assert.equal(m.rd(0x7079),0);m.onInstr=null;return m;
}
let lifeCases=0;
for(const cheat of [false,true]){
 const m=boot(cheat),snapshot=m.memory.bytes.slice();
 for(const [entry,state]of[['L_8DA2',8],['hs_8AF0',9],['hs_8A91',10]]){
  m.memory.bytes.set(snapshot);m.wr(0x7049,1);call(m,entry,9);
  assert.equal(m.rd(0x7049),cheat?1:0,entry+' life count');
  assert.equal(m.rd(0x7079),state,entry+' death animation');lifeCases++;
 }
}
const normal=boot(false);normal.keyboard.matrix[5]=16;
for(let f=0;f<150;f++)normal.frame();assert.equal(normal.rd(0x71a6),1,'L disabled outside trainer');
const m=boot(true);let skips=0,steps=0,last=0,observed=[],warm=false;
m.wr(0x7017,0x12);m.wr(0x7018,0x34);m.wr(0x7019,0x56);
m.onInstr=pc=>{
 if(pc===s.nes_level_number)skips++;
 if(pc===s.L_A5D1){steps++;if(m.rd(0x71a6)!==last){last=m.rd(0x71a6);observed.push(last);}}
};
for(let expected=2;expected<=10;expected++){
 m.keyboard.matrix[5]=16;const before=skips;
 for(let f=0;f<140;f++)m.frame();
 assert.equal(skips,before+1,'one skip while L held');assert.equal(m.rd(0x71a6),expected===10?1:expected);
 assert.equal(m.rd(0x7049),6);assert.equal(m.rd(s.cheat_mode),1);assert.equal(m.rd(0x7079),0,'safe rope intro');
 assert.deepEqual([m.rd(0x7300),m.rd(0x7304),m.rd(0x7305)],[91,94,116]);
 assert.deepEqual([m.rd(0x7017),m.rd(0x7018),m.rd(0x7019)],[0x12,0x34,0x56],'preserve score');
 m.keyboard.matrix[5]=0;for(let f=0;f<12;f++)m.frame();
}
// Leave a real generated bonus panel with L, restoring the normal start.
let bonusPhase=0;
m.keyboard.matrix[5]=0;
m.onInstr=pc=>{
 if(pc!==s.L_A5D1)return;
 if(bonusPhase===0){
  bonusPhase=1;m.wr(0x71a7,9);m.wr(0x71a8,10);m.wr(0x705f,0x20);m.wr(0x70ac,178);
  const c=m.cpu;c.sp-=2;m.wr(c.sp,pc&255);m.wr(c.sp+1,pc>>8);c.pc=s.L_A60B;return;
 }
 if(bonusPhase===1){assert(m.rd(0x705f)&32);m.keyboard.matrix[5]=16;bonusPhase=2;}
 if(bonusPhase===2&&m.rd(0x71a6)===2&&!(m.rd(0x705f)&4)&&m.rd(0x7079)===0)bonusPhase=3;
};
for(let f=0;f<300&&bonusPhase!==3;f++)m.frame();
assert.equal(bonusPhase,3,'L exits bonus and completes next-level rope intro');
assert.equal(m.rd(0x705f)&32,0);assert.equal(m.rd(s.cheat_mode),1);assert.equal(m.rd(0x7049),6);
m.keyboard.matrix[5]=0;for(let f=0;f<12;f++)m.frame();
// A genuine death, then respawn: infinite lives is not invulnerability.
let injected=false,dead=false,respawn=false;
m.onInstr=pc=>{
 if(pc!==s.L_A5D1)return;
 if(!injected){injected=true;const c=m.cpu;c.sp-=2;m.wr(c.sp,pc&255);m.wr(c.sp+1,pc>>8);c.regs[2]=c.regs[3]=0;c.pc=s.L_8DA2;return;}
 if(m.rd(0x7079)===8)dead=true;
 if(dead&&m.rd(0x7079)<8)respawn=true;
};
for(let f=0;f<350&&!respawn;f++)m.frame();
assert(dead&&respawn,'death animation and checkpoint still work');assert.equal(m.rd(0x7049),6);
// Warm menu must accept the trainer chord and also turn it off for a normal choice.
let warmNormalReady=false;
m.onInstr=pc=>{
 if(pc===s.L_A5D1&&warm&&m.rd(0x71a6)===2&&!(m.rd(0x705f)&4)&&m.rd(0x7079)===0)warmNormalReady=true;
 if(pc===s.go1)m.keyboard.matrix[7]=128;
 if(pc===s.title_warm_menu){warm=true;m.keyboard.matrix[7]=0;m.keyboard.matrix[1]=0;m.keyboard.matrix[2]=4;}
};
m.cpu.sp=s.GSTACK;m.cpu.pc=s.game_over;
for(let f=0;f<650&&!warmNormalReady;f++)m.frame();
assert(warmNormalReady&&m.rd(0x71a6)===2);assert.equal(m.rd(s.cheat_mode),0,'normal warm restart disables trainer');
m.keyboard.matrix[2]=0;for(let f=0;f<12;f++)m.frame();
let warmTrainer=false,warmTrainerReady=false;
m.onInstr=pc=>{
 if(pc===s.L_A5D1&&warmTrainer&&m.rd(0x71a6)===1&&!(m.rd(0x705f)&4)&&m.rd(0x7079)===0)warmTrainerReady=true;
 if(pc===s.go1)m.keyboard.matrix[7]=128;
 if(pc===s.title_warm_menu){warmTrainer=true;m.keyboard.matrix[7]=0;m.keyboard.matrix[2]=0;m.keyboard.matrix[1]=40;}
};
m.cpu.sp=s.GSTACK;m.cpu.pc=s.game_over;
for(let f=0;f<650&&!warmTrainerReady;f++)m.frame();
assert(warmTrainerReady&&m.rd(0x71a6)===1,JSON.stringify({warmTrainer,warmTrainerReady,pc:m.cpu.pc.toString(16),sp:m.cpu.sp.toString(16),level:m.rd(0x71a6),mode:m.rd(s.cheat_mode),state:m.rd(0x7079),flags:m.rd(0x705f),kb1:m.rd(s.kbmat+1),kb2:m.rd(s.kbmat+2),keys:Array.from(m.keyboard.matrix)}));assert.equal(m.rd(s.cheat_mode),1,'warm F1+F3 enables trainer');
for(let i=0;i<s.nt_motion_end-s.nt_jump_curve;i++)assert.equal(m.rd(s.nt_jump_curve+i),m.img[s.nt_motion_source+i],'installed helpers survive level skips/death/menus');
if(s.NES_CHEAT_PACKED)for(let a=s.cheat_code_begin;a<s.cheat_code_end;a++)assert.equal(m.rd(a),m.img[a],'packed trainer survives level skips/death/menus');
console.log(JSON.stringify({B,menuCases,lifeCases,levelSkips:skips,wrap:'9 -> 1',heldLRepeats:false,bonusSkip:true,deathRespawn:true,normalModeUnaffected:true,warmRestart:true,warmTrainer:true}));
