// Original NES object records -> native room, pickups, doors and enemy coordinates.
const fs=require('fs'),assert=require('assert/strict'),path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/nes-full',s=symbols(B),m=E.mk(B+'/monty.bin');
const rooms=JSON.parse(fs.readFileSync('build/nes_full/rooms.json')).records,cart=fs.readFileSync('build/monty_entry.bin');
function call(name,{a=0,hl=0}={}){const c=m.cpu;c.iff=false;c.iff_pending=0;c.sp=0x73BE;c.pc=s[name];c.regs[7]=a;c.regs[4]=hl>>8;c.regs[5]=hl&255;m.wr(c.sp,s.unit_trap&255);m.wr(c.sp+1,s.unit_trap>>8);for(let n=0;c.pc!==s.unit_trap;n++){assert(n<1000000,name+' hung');c.instruction();}}
const word=(a,v)=>{m.wr(a,v&255);m.wr(a+1,v>>8);};const readword=a=>m.rd(a)|(m.rd(a+1)<<8);
const sets={5:0x62,6:0x58,7:0x5d,9:0x53,10:0x4e,11:0x44,12:0x49},deco={17:8,18:11,19:0xe0,20:0x88,21:0x89,22:0x10,23:0x11,24:0};
const closed={14:[0xc0,0xc7],15:[0xb0,0xb7],16:[0xbb,0x9c]},open={14:[0xc1,0xc2,0xc3,0xc5],15:[0xb1,0xb2,0xb3,0xb4],16:[0xbc,0xbd,0xbe,0xbf]};
let cases=0,doors=0,npcs=0,lookups=0;
for(const level of [1,2,3,9])for(const taken of [false,true])for(const room of rooms){
 const expected=room.native.slice(),row=Math.floor(Math.sqrt(room.index+1))-1,col=room.index-row*(row+2)+8-row;
 m.wr(0x71A6,level);m.wr(0x71A7,row);m.wr(0x71A8,col);m.wr(0x7049,6);m.wr(0x70B3,0);m.wr(s.nes_q_idle,1);
 for(let i=0;i<198;i++)m.wr(0x70c0+i,taken?255:0);
 for(let i=0;i<7;i++)m.wr(0x71b2+i,255);
 const order=[0,1,2,3,4,5];order.forEach((v,i)=>m.wr(0x72e0+i,v));
 const hero=[75,120,52,6,78,120,152,11];hero.forEach((v,i)=>m.wr(0x7300+i,v));for(let a=0x7308;a<0x7329;a++)m.wr(a,0);for(let k=2;k<6;k++){m.wr(0x7300+4*k,208);m.wr(0x7303+4*k,15);}
 const place=(pos,tiles,offsets)=>tiles.forEach((v,i)=>{assert(pos+offsets[i]>=192&&pos+offsets[i]<960);expected[pos+offsets[i]-192]=v;});
 let number=0,enemy=0;const positions=[];
 for(const rec of room.objects){
  const type=rec[0],visibility=rec.at(-1),visible=(visibility&15)<=level-1&&level-1<(visibility>>4);
  if(type>=17){if(visible)place((rec[1]|rec[2]<<8)-0x2000,[deco[type]],[0]);continue;}
  number++;if(!visible)continue;
  const pos=type<=4?rec[2]*32+rec[1]:(rec[1]|rec[2]<<8)-0x2000;
  if(taken){if(type>=14){const q=open[type];place(pos-1,[...q.slice(0,3),...Array(9).fill(q[3])],[0,1,2,32,33,34,64,65,66,96,97,98]);doors++;}continue;}
  if(type>=14){const q=closed[type];place(pos,[q[0],q[0],q[0],q[1]],[0,32,64,96]);positions.push([number,pos]);doors++;}
  else if(type>=5){const offset=sets[type];assert.notEqual(offset,undefined);place(pos,[...cart.subarray(0x9fd2+offset,0x9fd6+offset)],[0,1,32,33]);positions.push([number,pos]);}
  else if(type===1){const offset=hero[1]>=rec[1]*8-1?0x7c:0x81;place(pos,[...cart.subarray(0x9fd2+offset,0x9fd6+offset)],[0,1,32,33]);positions.push([number,pos]);}
  else{enemy++;positions.push([number,0xff00+4*enemy]);}
 }
 call('L_A067');
 assert.deepEqual([...Array(768)].map((_,i)=>m.rd(s.FIELD_VNT+i)),expected,`field room ${room.index} L${level} taken=${taken}`);
 assert.deepEqual(order.map((_,i)=>m.rd(0x72e0+i)),order,'sprite order overwritten');assert.deepEqual(hero.map((_,i)=>m.rd(0x7300+i)),hero,'hero overwritten');
 assert.equal(m.rd(0x707a),enemy,'enemy count');
 for(let k=2+enemy;k<6;k++)assert.equal(m.rd(0x7303+4*k),0,'stale actor colour');
 for(const [number,pos] of positions)assert.equal(readword(0x72c0+2*number),pos,`object ${number}, room ${room.index}`);
 // A moving enemy marker may share the low position byte with an item.
 // Every static object's full coordinate must still find its own flag slot.
 if(!taken&&level<=3)for(const [number,pos] of positions)if(pos<0xff00){
  word(0x71b0,pos);call('L_90C8');
  assert.equal(m.rd(0x71a2),number,`object lookup ${number}, room ${room.index}, level ${level}`);
  lookups++;
 }
 let k=0;
 for(const rec of room.objects)if(!taken&&[2,3,4].includes(rec[0])&&(rec.at(-1)&15)<=level-1&&level-1<(rec.at(-1)>>4)){
  k++;const p=0x7304+4*k;assert.equal(m.rd(p),rec[2]*8-1,'enemy Y');assert.equal(m.rd(p+1),rec[1]*8,'enemy X');npcs++;
 }
 cases++;
}
console.log(JSON.stringify({B,rooms:cases,npcCoordinates:npcs,doorStates:doors,objectLookups:lookups,objectOrder:'preserved',fieldCells:cases*768}));
