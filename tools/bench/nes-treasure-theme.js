// Bonus-only palette and cached ink, including retained-plane colour aliases.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]=2;if(f===100)m.keyboard.matrix[2]=0;m.frame();}
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');c.instruction();}}
const palette=()=>Array.from({length:8},(_,i)=>m.rd(s.pal+2*i));
function checkCode(){for(let i=0;i<s.nt_bonus_palette_end-s.nt_bonus_palette;i++)assert.equal(m.rd(s.nt_bonus_palette+i),m.img[s.nt_bonus_palette_source+i],'installed palette code survived sprite/cache writes');}
m.wr(s.video_enabled,1);m.wr(0x71a7,0);m.wr(0x705f,0);m.wr(s.nes_amulet_ticks,0);m.wr(s.nes_amulet_ticks+1,0);call('pal_build');const ordinary=palette();
assert.equal(ordinary[0],0);assert.equal(ordinary[4],32);assert.equal(m.rd(s.full_modes+19),5);checkCode();
for(const row of [9,10,18,25]){
 m.wr(0x71a7,row);m.wr(0x705f,0x20);m.wr(s.nes_amulet_ticks,255);m.wr(s.nes_amulet_ticks+1,1);call('pal_build');
 const bonus=palette();assert.deepEqual(bonus,[s.TREASURE_BLUE,255,4,103,s.TREASURE_GOLD,255,4,103]);
 assert.equal(m.rd(s.full_modes+19),0x10,'gold is one plane');assert.equal(m.rd(s.nes_snake_palette),0xc9);
 for(let ink=1;ink<=3;ink++)assert.equal(bonus[ink|4],ordinary[ink],'Joe RGB over gold, ink '+ink);
 for(let f=0;f<64;f++){m.wr(s.frames,f);call('nes_snake_palette');assert.deepEqual(palette(),bonus,'amulet must not animate the gold slot');}
 checkCode();
 m.wr(0x71a7,0);m.wr(0x705f,0);m.wr(s.nes_amulet_ticks,0);m.wr(s.nes_amulet_ticks+1,0);call('pal_build');
 assert.deepEqual(palette(),ordinary,'ordinary palette restored after bonus');assert.equal(m.rd(s.full_modes+19),5);assert.equal(m.rd(s.nes_snake_palette),0x3a);
}
console.log(JSON.stringify({B,bonusRows:4,background:s.TREASURE_BLUE,gold:s.TREASURE_GOLD,goldPlane:'8000',joeRgbAliases:3,amuletPaletteChecks:256,ordinaryRestored:true,installedCode:'intact'}));
