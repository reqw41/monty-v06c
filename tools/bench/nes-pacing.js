// Cost estimates, atomic queue boundaries, age priority and cosmetic cadence.
'use strict';
const assert=require('assert/strict'),path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B),m=E.mk(B+'/monty.bin');
assert(s.NES_FRAME_PACING);for(let f=0;f<560;f++){if(f===10)m.keyboard.matrix[2]=2;if(f===100)m.keyboard.matrix[2]=0;m.frame();}
const boot=m.memory.bytes.slice();
function call(name,a=0,b=0){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;c.regs[7]=a;c.regs[0]=b;c.regs[1]=173;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<2000000,name+' hung');if(m.onInstr)m.onInstr(c.pc);c.instruction();}assert.equal(c.sp,0x73c0);return c.regs[7];}
let estimates=0;
for(const k of [0,2,3,4,5])for(let cols=1;cols<=3;cols++)for(let rows=1;rows<=(k?16:23);rows++){
 const a=s.spr_rec+16*k;m.wr(a+7,9);m.wr(a+8,9+cols-1);m.wr(a+11,rows);m.wr(s.frames,119);
 assert.equal(call('pace_charge',0,k),(rows*cols*(k?1:2)+(k?20:32))>>1);
 assert.equal(m.cpu.regs[0],k);assert.equal(m.cpu.regs[1],173);if(k>=2)assert.equal(m.rd(s.pace_enemy_stamp+k-2),119);estimates++;
}
// Same cost ceiling, different rectangles. All actions of an overlap group
// remain together; stopping is allowed only before a new restore/repaint.
const queue=[1,0,1,2,2,0,2,2,3,2,3,0,1,3,2,3,3,3,1,4,2,4,3,4,0];
const actions=[];m.onInstr=pc=>{if([s.draw1,s.restore1,s.cells_rect].includes(pc)){actions.push([pc===s.draw1?3:pc===s.restore1?1:2,m.cpu.regs[0]]);const c=m.cpu;c.pc=m.rd(c.sp)|(m.rd(c.sp+1)<<8);c.sp+=2;}};
queue.forEach((v,i)=>m.wr(s.cr_list+i,v));m.wr(s.cr_read,s.cr_list&255);m.wr(s.cr_read+1,s.cr_list>>8);m.wr(s.ex_any,1);m.wr(s.crit_pend,0);
for(const k of [0,2,3,4]){m.wr(s.spr_rec+16*k+7,9);m.wr(s.spr_rec+16*k+8,11);m.wr(s.spr_rec+16*k+11,k?16:23);}
call('crit');assert(m.rd(s.crit_pend));assert.deepEqual(actions.filter(a=>a[0]===3),[[3,2],[3,0]],'overlap group must finish before deferral');assert.equal(m.rd(s.cr_read)|(m.rd(s.cr_read+1)<<8),s.cr_list+12);
m.onInstr=null;let priorities=0;
for(const frame of [5,120,250])for(const age of [0,3,4,12]){m.wr(s.frames,frame);m.wr(s.pace_enemy_stamp,(frame-age)&255);m.wr(s.ubr+8,19);const c=m.cpu;c.regs[2]=44;c.regs[3]=55;assert.equal(call('pace_priority',2),age>=4?1:19);assert.equal(c.regs[2],44);assert.equal(c.regs[3],55);priorities++;}
assert.equal(call('pace_priority',0),0);
// Actual visual phase sequence, including low-byte wrap. Logical belt and
// platform hazard state are never modified by this independent clock.
let phases=[],firePhases=[];m.wr(s.bg_turn,248);m.wr(s.belt_frame,0);m.wr(s.fire_frame,0);m.wr(0x7096,2);m.wr(0x7000,0x63);
for(let f=248;f<=278;f++){m.wr(s.frames,f&255);const old=m.rd(s.belt_frame),oldFire=m.rd(s.fire_frame);call('pace_belt_tick');if(old!==m.rd(s.belt_frame))phases.push([f,m.rd(s.belt_frame)]);if(oldFire!==m.rd(s.fire_frame))firePhases.push([f,m.rd(s.fire_frame)]);assert.equal(m.rd(0x7096),2);assert.equal(m.rd(0x7000),0x63);
 const held=[m.rd(s.fire_frame),m.rd(s.belt_frame)];call('pace_belt_tick');assert.deepEqual([m.rd(s.fire_frame),m.rd(s.belt_frame)],held,'extra logic calls cannot advance the same physical tick');}
assert.deepEqual(phases,[[254,3],[260,2],[266,1],[272,0],[278,3]]);
if(s.NES_ANIM_CLOCK){
 assert.deepEqual(firePhases,[[254,1],[260,2],[266,3],[272,0],[278,1]]);
 for(const raw of [0,8,16,40]){const held=m.rd(s.fire_frame);m.wr(0x73f9,raw);call('L_A92F');assert.equal(m.rd(0x7085),raw,'original logical fire state');assert.equal(m.rd(0x73f9),raw,'original phase selector');assert.equal(m.rd(s.fire_frame),held,'logical steps must not overwrite the physical fire clock');}
 m.memory.bytes.set(boot);m.wr(0x71a7,1);m.wr(0x71a8,9);m.wr(0x705f,0);m.wr(s.nes_q_idle,1);call('L_A067');
 for(let k=0;k<6;k++)m.wr(0x7303+4*k,0);
 m.wr(s.fire_frame,0);m.wr(s.belt_frame,0);call('room_redraw');
 // Select the fire-first turn of the existing oldest-submission scheduler.
 m.wr(s.fire_frame,1);m.wr(s.belt_frame,1);m.wr(s.pace_fire_stamp,0);m.wr(s.pace_belt_stamp,1);m.wr(s.frames,120);m.wr(s.video_dirty,s.DIRTY_FIRE|s.DIRTY_BELT);call('disp_prep');
 assert.equal(m.rd(s.fire_shown),1,'fire submitted');assert.equal(m.rd(s.belt_shown),1,'belt submitted in the same preparation');
}
console.log(JSON.stringify({B,estimates,priorities,atomicGroup:true,phasePeriodFrames:6,allFourPhases:true,sharedFireClock:!!s.NES_ANIM_CLOCK,batchedFireAndBelt:!!s.NES_ANIM_CLOCK,logicalBeltAndHazards:'unchanged'}));
