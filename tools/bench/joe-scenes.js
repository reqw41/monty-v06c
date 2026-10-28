// Keyboard-driven scenes in the entrance room, with every crit checked.
// Rope starts from a fixed valid pose on the existing pole, then uses normal physics.
// SCENE=walk|ladder|rope|jump B=... OUT=... N=1100 node tools/bench/joe-scenes.js
const fs=require('fs'),path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin'),scene=process.env.SCENE||'jump';
const motion=require('./joe-motion')(m,s),checker=require('./framecheck')(m,s);let steps=0,placed=false,settled=false;const states={};
const out=process.env.OUT;if(out)fs.mkdirSync(out,{recursive:true});
m.onInstr=pc=>{if(scene==='rope'&&placed&&!settled&&pc===s.spr_put&&m.rd(s.sp_k)===0&&m.rd(s.spr_new+1)<32){motion.reset();settled=true;}motion.instruction(pc);checker.instruction(pc);if(pc===s.L_A5D1){steps++;m.wr(0x7049,6);
 if(scene==='rope'&&!placed&&m.frames>=400){placed=true;motion.reset();m.wr(0x7300,8);m.wr(0x7304,11);m.wr(0x7301,124);m.wr(0x7305,124);m.wr(0x7079,4);m.wr(0x705F,m.rd(0x705F)&~0x24);}
if(m.frames>=400){const st=m.rd(0x7079);states[st]=(states[st]||0)+1;}}};
const key=(r,b,d)=>{if(d)m.keyboard.matrix[r]|=b;else m.keyboard.matrix[r]&=~b;};
for(let f=0;f<+(process.env.N||1100);f++){
 if(f===10)key(2,2,true);if(f===100)key(2,2,false);
 if(f>=400){const t=f-400;key(0,0x40,scene==='walk'&&Math.floor(t/100)%2===0);key(0,0x10,scene==='walk'&&Math.floor(t/100)%2===1);
 key(0,0x80,(scene==='ladder'&&t<250)||(scene==='rope'&&t<100));key(0,0x20,(scene==='ladder'&&t>=250)||(scene==='rope'&&t>=100&&t<300));
 key(7,0x80,(scene==='jump'&&t%60<3));}
 m.frame();motion.frame();
 if(out&&f>=400&&f<750){const pixels=new Uint8Array(256*192);for(let y=0;y<192;y++)for(let x=0;x<256;x++){const a=(x>>3)*256+0xDF-y,b=128>>(x&7);pixels[y*256+x]=((m.rd(0x8000+a)&b)?4:0)|((m.rd(0xA000+a)&b)?2:0)|((m.rd(0xC000+a)&b)?1:0);}fs.writeFileSync(`${out}/${scene}_${f}.idx`,pixels);fs.writeFileSync(`${out}/${scene}_${f}.json`,JSON.stringify({palette:[...Array(8)].map((_,i)=>m.rd(s.pal+2*i)),state:m.rd(0x7079),frame:s.jn_shown===undefined?null:m.rd(s.jn_shown)}));}
}
const check=checker.result();console.log(JSON.stringify({B,scene,states,motion:motion.result(),check}));if(check.bad||!check.checks)process.exitCode=1;
