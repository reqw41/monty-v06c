// Real bonus entry, physical timer, collected jewels and next-level landing.
const path=require('path'),fs=require('fs'),assert=require('assert/strict');process.chdir(path.resolve(__dirname,'../..'));const root=process.cwd(),E=require(root+'/tools/vec_emu'),{symbols}=require(root+'/tools/bench/logic-profile'),B=process.env.B||'build/nes-treasure',s=symbols(B),m=E.mk(B+'/monty.bin');
let entry=false,built=0,steps=0,f=0,start,timerStarted,expired,captured=false,advanced=false,landed=false;
const timerWrites=[];
m.onWrite=(a,v)=>{if(a!==0x70ac)return;
 if(v===178&&(m.rd(0x705f)&0x20)){timerStarted=f;timerWrites.length=0;}
 if(timerStarted!==undefined&&expired===undefined)timerWrites.push({frame:f,value:v});
};
m.onInstr=pc=>{
 if(pc===s.L_A5D1){steps++;if(!entry&&steps>80){entry=true;m.wr(0x71a7,8);m.wr(0x71a8,10);m.wr(0x705f,0);m.wr(0x7079,6);m.wr(0x7300,221);m.wr(0x7304,224);m.wr(0x7301,116);m.wr(0x7305,116);m.wr(0x7076,0);m.wr(0x7077,1);}}
 if(pc===s.nt_bonus_hud){built++;if(start===undefined)start=f;}
};
for(f=0;f<1600;f++){
 if(f===10)m.keyboard.matrix[2]=2;if(f===100)m.keyboard.matrix[2]=0;
 // After expiry, jump sideways from the rope; NES holds at its lower end.
 m.keyboard.matrix[0]=(expired!==undefined&&!advanced)?64:0;
 m.keyboard.matrix[7]=(expired!==undefined&&!advanced&&f-expired<12)?128:0;
 m.frame();
 if(process.env.OUT&&built&&f>start+45&&!captured&&!m.rd(s.crit_pend)&&!(m.rd(s.video_dirty)&s.DIRTY_ROOM)&&m.rd(s.video_enabled)){captured=true;const out=process.env.OUT;fs.mkdirSync(out,{recursive:true});
 let a=Buffer.alloc(65536);for(let y=0;y<256;y++)for(let x=0;x<256;x++){let p=(x>>3)*256+255-y,b=128>>(x&7);a[y*256+x]=[4,2,1].reduce((n,v,i)=>n+(m.rd(0x8000+0x2000*i+p)&b?v:0),0);}fs.writeFileSync(out+'/treasure.idx',a);fs.writeFileSync(out+'/treasure.json',JSON.stringify({palette:Array.from({length:8},(_,i)=>m.rd(s.pal+2*i))}));}
 if(process.env.MOVIE&&built&&f>=start+40&&!(f&1)){
  const out=process.env.MOVIE;fs.mkdirSync(out,{recursive:true});const pixels=Buffer.alloc(65536);
  for(let y=0;y<256;y++)for(let x=0;x<256;x++){const a=(x>>3)*256+255-y,b=128>>(x&7);pixels[y*256+x]=[4,2,1].reduce((v,k,p)=>v+(m.rd(0x8000+p*8192+a)&b?k:0),0);}
  const name=String(f-start).padStart(4,'0');fs.writeFileSync(path.join(out,name+'.idx'),pixels);
  fs.writeFileSync(path.join(out,name+'.json'),JSON.stringify({frame:f-start,level:m.rd(0x71a6),rgb:m.palette().filter((_,i)=>!(i&1)).map(v=>[v&255,(v>>>8)&255,(v>>>16)&255])}));
 }
 if(built&&m.rd(0x70ac)===1&&expired===undefined)expired=f;
 if(entry&&m.rd(0x71a6)===2){advanced=true;if(!(m.rd(0x705f)&4)&&m.rd(0x7079)===0){landed=true;break;}}
}
assert(entry&&built>1,'bonus entry and subsequent generated panels');
// Start at the actual timer load, before room generation and its HUD draw.
// Faster/slower drawing must not change the measured timer duration.
assert(expired-timerStarted>=705&&expired-timerStarted<=708,'NES timer duration in physical Vector frames');
assert.deepEqual(timerWrites.map(q=>q.value),Array.from({length:178},(_,i)=>178-i),'every physical timer tick');
for(let i=2;i<timerWrites.length;i++)assert.equal(timerWrites[i].frame-timerWrites[i-1].frame,4,'timer ticks every four physical frames');
assert(advanced&&landed,'bonus exit starts the next level and lands safely');
assert.equal(m.rd(0x7304),94);assert.equal(m.rd(0x7305),116);assert(m.rd(0x7049)>=6,'bonus must not kill Joe');
console.log(JSON.stringify({B,entry,built,timerFrames:expired-timerStarted,seconds:(expired-timerStarted)/50,firstHudDelay:start-timerStarted,timerTicks:timerWrites.length-1,nextLevel:m.rd(0x71a6),landing:[m.rd(0x7305),m.rd(0x7304)],lives:m.rd(0x7049),scoreBytes:[m.rd(0x7017),m.rd(0x7018),m.rd(0x7019)]}));
