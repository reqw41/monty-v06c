// Controlled display preview across the room's rope and decorations.
// Coordinates/poses are forced for illustration, not a gameplay speed test.
const fs=require('fs'),path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/nes-native',out=process.env.OUT||'build/blend-preview';
const s=symbols(B),m=E.mk(B+'/monty.bin');let steps=0,phase=0,painting=null;
fs.mkdirSync(out,{recursive:true});
function capture(){
 const pixels=Buffer.alloc(256*256);
 for(let y=0;y<256;y++)for(let x=0;x<256;x++){
  const a=(x>>3)*256+255-y,b=128>>(x&7);
  pixels[y*256+x]=(m.rd(0x8000+a)&b?4:0)|(m.rd(0xA000+a)&b?2:0)|(m.rd(0xC000+a)&b?1:0);
 }
 const p=path.join(out,String(phase).padStart(3,'0'));
 fs.writeFileSync(p+'.idx',pixels);
 fs.writeFileSync(p+'.json',JSON.stringify({palette:Array.from({length:8},(_,i)=>m.rd(s.pal+2*i)),B,phase,forced:true}));
 phase++;
}
m.onInstr=pc=>{
 if(pc===s.L_A5D1){steps++;m.wr(0x7049,6);}
 if(steps<250)return;
 if(pc===s.spr_plan){const y=120,x=104+phase;m.wr(0x7300,y);m.wr(0x7304,y+3);m.wr(0x7301,x);m.wr(0x7305,x);m.wr(0x7303,6);m.wr(0x7307,11);}
 if(pc===s.joe_select){m.cpu.regs[7]=phase%4;m.wr(s.jn_dir,0);const sp=m.cpu.sp;m.cpu.pc=m.rd(sp)|(m.rd(sp+1)<<8);m.cpu.sp=sp+2;}
 if(painting&&pc===painting.pc&&m.cpu.sp===painting.sp+2){capture();painting=null;}
 if(pc===s.joe_put){const sp=m.cpu.sp;painting={sp,pc:m.rd(sp)|(m.rd(sp+1)<<8)};}
};
for(let f=0;phase<28&&f<3000;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
if(phase!==28)throw Error('Incomplete preview '+phase);
console.log(JSON.stringify({B,out,frames:phase}));
