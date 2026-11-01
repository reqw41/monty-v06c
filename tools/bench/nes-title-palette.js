// Cold and warm title must use the same complete palette, including power-up exits.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B);
const m=E.mk(B+'/monty.bin'),expected=Array.from({length:16},(_,i)=>m.img[s.title_palette+i]);
const expectHW=expected.map(E.palColor);let cold=0,warm=0,started=false,returned=false,triggered=false,steps=0;
function check(phase){assert.deepEqual(Array.from({length:16},(_,i)=>m.rd(s.pal+i)),expected,phase+' shadow palette');assert.deepEqual(m.palette(),expectHW,phase+' hardware palette');}
for(let f=0;f<180;f++){m.frame();if(f>30){check('cold');cold++;}}
const coldScreen=Array.from({length:0x6000},(_,i)=>m.rd(0x8000+i));
m.onInstr=pc=>{
 if(pc===s.L_A5D1){steps++;started=true;m.keyboard.matrix[2]=0;if(steps===80&&!triggered){triggered=true;m.wr(s.nes_amulet_ticks,255);m.wr(s.nes_amulet_ticks+1,1);m.wr(s.nf_snake_count,1);m.cpu.sp=s.GSTACK;m.cpu.pc=s.game_over;}}
 if(pc===s.go1)m.keyboard.matrix[7]=128;
 if(pc===s.title_warm_menu){returned=true;m.keyboard.matrix[2]=0;m.keyboard.matrix[7]=0;}
};
m.keyboard.matrix[2]=2;
for(let f=0;f<800&&warm<180;f++){
 m.frame();if(returned){if(warm>2){check('warm');assert.deepEqual(Array.from({length:0x6000},(_,i)=>m.rd(0x8000+i)),coldScreen,'cold/warm title pixels');}warm++;}
}
assert(started&&triggered&&returned&&warm===180,'restart with live protection reached warm title');
console.log(JSON.stringify({B,coldFrames:cold,warmFrames:warm,palette:expected,powerUpAtGameOver:true,hardwareMatches:true}));
