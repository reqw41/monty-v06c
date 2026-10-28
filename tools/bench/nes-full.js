// Full-field decoder and bounds, executed as real i8080 code.
const fs=require('fs'),assert=require('assert/strict'),path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile'),B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');
const rooms=JSON.parse(fs.readFileSync('build/nes_full/rooms.json')).records;
function call(name,{hl=0,de=0,a=0,c=0}={}){const cpu=m.cpu;cpu.iff=false;cpu.iff_pending=0;cpu.sp=0x73BE;cpu.pc=s[name];cpu.regs[4]=hl>>8;cpu.regs[5]=hl&255;cpu.regs[2]=de>>8;cpu.regs[3]=de&255;cpu.regs[7]=a;cpu.regs[1]=c;m.wr(cpu.sp,s.unit_trap&255);m.wr(cpu.sp+1,s.unit_trap>>8);let clocks=0;for(let n=0;cpu.pc!==s.unit_trap;n++){assert(n<1000000,name+' did not return at '+cpu.pc.toString(16));cpu.instruction();clocks+=cpu.vcycles;}return clocks;}
assert.equal(s.SCREEN_HEIGHT,240);assert.equal(s.SCREEN_ROWS,30);m.wr(s.nes_q_idle,1);
let cases=0,maximum=0;
for(const room of rooms){const pointer=m.rd(s.nf_rooms+2*room.index)|(m.rd(s.nf_rooms+2*room.index+1)<<8);m.wr(s.FIELD_VNT-1,0xA5);m.wr(s.FIELD_VNT+768,0x5A);for(let a=s.FIELD_VNT;a<s.FIELD_VNT+768;a++)m.wr(a,0xEE);maximum=Math.max(maximum,call('nf_unpack',{hl:s.FIELD_VNT,de:pointer}));const got=[...Array(768)].map((_,i)=>m.rd(s.FIELD_VNT+i));assert.deepEqual(got,room.native,'room '+room.index);assert.equal(m.rd(s.FIELD_VNT-1),0xA5);assert.equal(m.rd(s.FIELD_VNT+768),0x5A);cases++;}
for(let row=0;row<30;row++)for(let col=0;col<32;col++){call('nf_row_addr',{a:row,c:col});assert.equal(m.cpu.hl(),s.VNT+32*row+col);call('vnt_row',{hl:s.VNT+32*row+col});assert.equal(m.cpu.regs[7],row);}
// The pyramid has exactly 99 legal normal rooms. Rejected edges must leave
// the packed room stream unread, rather than treating an index of 255 as data.
let legal=0;
for(let r=0;r<10;r++)for(let c=0;c<21;c++){
 m.wr(0x71A7,r);m.wr(0x71A8,c);call('nf_valid_room');
 const valid=r<9&&c>=8-r&&c<=10+r;
 assert.equal(!!(m.cpu.store_flags()&1),valid,'room validity '+[r,c]);if(valid)legal++;
}
assert.equal(legal,99);
for(const [r,c] of [[0,7],[0,11],[255,9],[8,19]]){
 const before=[...Array(768)].map((_,i)=>m.rd(s.FIELD_VNT+i));
 m.wr(0x71A7,r);m.wr(0x71A8,c);call('L_A067');
 assert.deepEqual([...Array(768)].map((_,i)=>m.rd(s.FIELD_VNT+i)),before,'invalid room decoded');
}
for(const [x,y,wantX,wantY] of [[0,30,4,31],[242,225,239,222],[112,100,112,100]]){
 m.wr(s.nf_room_row,0);m.wr(s.nf_room_col,8);m.wr(0x71A7,0);m.wr(0x71A8,7);
 for(const p of [0x7300,0x7304]){m.wr(p,y);m.wr(p+1,x);}call('nf_room_edge');
 assert.equal(m.rd(0x71A8),8);assert.equal(m.rd(0x7304),wantY);assert.equal(m.rd(0x7301),wantX);
}
// HUD is presentation only: dangerous-looking glyph IDs cannot enter physics.
for(let i=0;i<192;i++){
 m.wr(s.VNT+i,[0x38,0xE0,0x70,0x88,8][i%5]);
 call('nf_read_tile',{hl:s.VNT+i});assert.equal(m.cpu.regs[7],0,'HUD collision at '+i);
}
for(const [tile,want] of [[0,0],[8,8],[11,8],[0xC8,0x88],[0xC9,0x89],[0x95,0x90],[0xCC,0x95],[0xCD,0x95],[0xD7,8],[0x70,0x70]]){
 m.wr(s.FIELD_VNT,tile);call('nf_read_tile',{hl:s.FIELD_VNT});assert.equal(m.cpu.regs[7],want,'field semantic '+tile);assert.equal(m.cpu.hl(),s.FIELD_VNT);
}
console.log(JSON.stringify({B,rooms:cases,decodedCells:768*cases,bounds:'clean',rowAddresses:960,hudCollisionCells:192,maxDecoderClocks:maximum}));
