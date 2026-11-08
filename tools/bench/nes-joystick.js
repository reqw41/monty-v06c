// Real PPI2 port 06h and direct-compatible 0Eh, independent of keyboard input.
'use strict';
const assert=require('node:assert/strict'),path=require('node:path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-blend80-sp-white-ladder',s=symbols(B);
const m=E.mk(B+'/monty.bin');for(let f=0;f<120;f++)m.frame();
assert.equal(m.io.CW2,0x83);assert.equal(m.io.PC2,0x9f);
function call(name){const c=m.cpu;c.iff=false;c.iff_pending=0;c.pc=s[name];c.sp=0x73be;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<10000,name+' hung');c.instruction();}}
const raw=n=>255^((n&15)|((n&16)?64:0)|((n&32)?128:0));
const dirs=n=>((n&1)?64:0)|((n&2)?16:0)|((n&4)?32:0)|((n&8)?128:0);
let cases=0;
function check(p,a,k,fire,number=8){m.io.PB2=p;m.JOY=a;m.wr(s.kbmat,k|5);m.wr(s.kbmat+7,17|(fire?128:0));m.wr(s.kbmat+2,number);call('joy_merge');const n=~(p&a)&255;
 assert.equal(m.rd(s.kbmat),k|5|dirs(n));assert.equal(m.rd(s.kbmat+7),17|((fire||(n&192))?128:0));assert.equal(m.rd(s.kbmat+2),number,'Fire is the space bit only: the title HUD menu starts on it');cases++;
}
for(let p=0;p<64;p++)for(let a=0;a<64;a++)check(raw(p),raw(a),0,false);
for(let k=0;k<16;k++)for(const fire of[false,true])for(let p=0;p<64;p++)check(raw(p),255,k<<4,fire);
for(let n=0;n<256;n++)check(255^64,255,0,false,n);
for(let noise=0;noise<4;noise++)check(255^(noise<<4),255,0,false);
const results=[];
for(const port of[6,14]){
 const q=E.mk(B+'/monty.bin');let steps=0;const set=n=>{if(port===6)q.io.PB2=raw(n);else q.JOY=raw(n);};
 q.onInstr=pc=>{if(pc===s.L_A5D1)steps++;};
 // The title starts on a fresh Fire press: the held one (splash, GAME OVER) is ignored.
 for(let f=0;f<650&&steps<80;f++){if(f===10)set(16);if(f===100)set(0);if(f===120)set(16);if(f===130)set(0);q.frame();}
 assert(steps>=80,'Fire starts level 1');assert.equal(q.rd(0x71a6),1);assert.equal(q.rd(s.cheat_mode),0);assert.equal(q.rd(0x7079),0);
 assert(q.keyboard.matrix.every(v=>v===0),'test must use no keyboard keys');
 const startX=q.rd(0x7305);set(1);for(let f=0;f<7;f++)q.frame();const rightX=q.rd(0x7305);assert(rightX>startX,'Right moves Joe');
 set(2);for(let f=0;f<7;f++)q.frame();assert(q.rd(0x7305)<rightX,'Left moves Joe');
 // Use the straight-rope fixture from the original-NES control comparison, away from both ends.
 set(0);for(let f=0;f<3;f++)q.frame();
 let placed=false;set(4);q.onInstr=pc=>{if(pc===s.L_A5D1&&!placed&&(q.rd(s.kbmat)&240)===32){placed=true;for(let i=192;i<960;i++)q.wr(s.VNT+i,0);for(let row=12;row<18;row++)q.wr(s.VNT+row*32+15,0x95);q.wr(0x7086,255);for(let a=0x7308;a<0x7329;a++)q.wr(a,0);for(const [a,v]of[[0x7300,104],[0x7304,107],[0x7301,116],[0x7305,116],[0x7079,4],[0x7076,0],[0x7077,0]])q.wr(a,v);q.wr(0x705f,32);q.wr(0x71a7,9);q.wr(0x70ac,178);q.wr(0x7075,128);}};
 for(let f=0;f<20&&!placed;f++)q.frame();assert(placed);q.onInstr=null;for(let f=0;f<8;f++)q.frame();const upY=q.rd(0x7304);assert.equal(q.rd(0x7079),4,'Up climbs the reference rope: '+JSON.stringify({x:q.rd(0x7305),y:q.rd(0x7304),input:q.rd(0x73ee),tiles:[0,1,2,3,4,5].map(i=>q.rd(0x7057+i))}));assert(upY<107);
 set(8);for(let f=0;f<8;f++)q.frame();assert(q.rd(0x7304)>upY,'Down descends');
 set(0);for(let f=0;f<30;f++)q.frame();
 const y=q.rd(0x7304),x=q.rd(0x7305);set(1|16);for(let f=0;f<5;f++)q.frame();assert([2,6].includes(q.rd(0x7079)),'Fire jumps');assert(q.rd(0x7304)<y);assert(q.rd(0x7305)>x,'diagonal jump');
 set(0);for(let f=0;f<12;f++)q.frame();let warm=false;steps=0;q.onInstr=pc=>{if(pc===s.title_warm_menu)warm=true;if(warm&&pc===s.L_A5D1)steps++;};
 q.cpu.sp=s.GSTACK;q.cpu.pc=s.game_over;
 for(let f=0;f<15;f++)q.frame();assert(!warm,'GAME OVER waits');
 set(32);for(let f=0;f<700&&!warm;f++)q.frame();set(0);for(let f=0;f<10;f++)q.frame();set(32);for(let f=0;f<10;f++)q.frame();set(0);for(let f=0;f<700&&steps<40;f++)q.frame();assert(warm&&steps>=40,'Fire2 passes GAME OVER and restarts');assert.equal(q.rd(0x71a6),1);
 let count=0;for(let i=0;i<s.PS_N*8;i++)if(q.rd(s.ps_tab+2*i)||q.rd(s.ps_tab+2*i+1))count++;assert.equal(count,s.PS_BLOCKS||32);
 results.push({port,startLevel:1,directions:4,diagonalJump:true,fire2Restart:true,cachedShifts:count});
}
const held=E.mk(B+'/monty.bin');held.io.PB2=255^64;let heldSteps=0;held.onInstr=pc=>{if(pc===s.L_A5D1)heldSteps++;};for(let f=0;f<300;f++)held.frame();assert.equal(heldSteps,0,'Fire held from boot does not start the game');held.io.PB2=255;for(let f=0;f<10;f++)held.frame();held.io.PB2=255^64;for(let f=0;f<10;f++)held.frame();held.io.PB2=255;for(let f=0;f<500&&heldSteps<40;f++)held.frame();assert(heldSteps>=40,'after release, Fire starts the game');
console.log(JSON.stringify({B,inputCases:cases,keyboardAndJoystick:true,heldFromBoot:true,results}));
