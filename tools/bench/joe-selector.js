// State-to-NES-pose regression. Pixel fixtures alone cannot detect a wrong pose.
// B=build/native node tools/bench/joe-selector.js
'use strict';
const path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin'),full=s.SCREEN_HEIGHT===240;
let cases=0;const poses=new Set();
function check(state,expected,fields={}) {
  m.wr(0x7079,state);
  for(const [address,value] of Object.entries(fields))m.wr(+address,value);
  const before=Buffer.from(Array.from({length:0x400},(_,i)=>m.rd(0x7000+i)));
  m.cpu.iff=false;m.cpu.sp=0x73BE;m.wr(0x73BE,s.unit_trap&255);m.wr(0x73BF,s.unit_trap>>8);m.cpu.pc=s.joe_select;
  for(let i=0;m.cpu.pc!==s.unit_trap;i++){if(i>1000)throw Error('Selector did not return');m.cpu.instruction();}
  const actual=m.cpu.regs[7];
  if(actual!==expected)throw Error(`State ${state}, ${JSON.stringify(fields)}: NES ${actual}, expected ${expected}`);
  // The display selector may write native visual state only; ignore the call stack.
  for(let a=0x7000;a<0x7400;a++)if(a<0x73BE||a>=0x73C0)if(m.rd(a)!==before[a-0x7000])throw Error('Selector changed game RAM '+a.toString(16));
  cases++;poses.add(actual);
}
for(const direction of [2,254]){
  m.wr(0x7078,direction);
  check(0,0);
  for(let phase=0;phase<4;phase++)check(1,1+phase,{[s.jn_walk]:phase});
  for(const state of [2,5,6,7])check(state,7);
  // Ladder: include swapped MSX layers and a stale rope/idle pose at entry.
  for(const name of [0x34,0x98,0x54,0xB8,0x58,0xBC])for(const previous of [0,10,19])for(const flags of [0,0x40])for(let phase=0;phase<8;phase++){
    check(3,8+((phase>>(full?2:1))&1),{[s.jn_tick]:phase,[s.spr_new+3]:name,[s.jn_frame]:previous,0x705F:flags,0x70AA:phase});
  }
  for(let phase=0;phase<8;phase++){
    check(4,8+((phase>>(full?2:1))&1),{[s.jn_tick]:phase,0x7058:0x88,0x70AA:phase});
    check(4,phase&(full?4:2)?19:10,{[s.jn_tick]:phase,0x7058:8,0x70AA:phase});
  }
  for(const tile of [0x90,0x95])check(4,full&&tile===0x90?(m.rd(s.jn_tick)&4?19:10):11,{0x7058:tile});
  if(full){for(let phase=0;phase<8;phase++)check(4,phase&4?19:10,{[s.jn_tick]:phase,0x7058:0x90,0x70AA:phase});check(5,11,{0x7058:0x95});m.wr(0x7058,0);}
  for(const tile of [0x98,0xD8])check(4,12,{0x7058:tile});
  for(let timer=0;timer<=112;timer++){
    check(8,13+Math.floor((112-timer)/24),{0x70A9:timer,[s.jn_fire]:0});
    check(8,20+Math.floor((112-timer)/40),{0x70A9:timer,[s.jn_fire]:1});
    check(10,5+((timer>>3)&1),{0x70A9:timer});
  }
  check(9,18);
}
console.log(JSON.stringify({B,cases,poses:[...poses].sort((a,b)=>a-b),gameRamChanges:0}));
