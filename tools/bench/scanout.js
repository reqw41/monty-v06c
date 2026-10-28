// Actual raster fetches, not an end-of-frame VRAM screenshot. Headless Vector06js.
const fs=require('fs'),path=require('path');process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),REF=require('./video-ref'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin');
let steps=0,fc=0;const raster=new Uint8Array(256*192),frames=[],examples=[];
const P=m.ctx.PixelFiller.prototype,get=P.getColorIndex;
P.getColorIndex=function(rp,border){const v=get.call(this,rp,border),x=(rp-128)>>1,y=this.raster_line-72;if(!border&&x>=0&&x<256&&y>=0&&y<192)raster[y*256+x]=(v>>1)&7;return v;};
m.onInstr=pc=>{if(pc===s.L_A5D1){steps++;m.wr(0x7049,6);}};
function bgAllowsBlue(x,y){const r=y>>3,c=x>>3,t=m.rd(s.VNT+32*r+c),md=REF.modes(m,s,t),bit=128>>(x&7);
 for(let f=0;f<(REF.animated.has(t)?4:1);f++){const pat=REF.pattern(t,f,m.rd(s.belt_shown))[y&7];let idx=0;for(let p=0;p<3;p++)idx=(idx<<1)|(([0,pat,pat^255,255][(md>>(4-2*p))&3]&bit)?1:0);if(idx===2)return true;}return false;}
for(;fc<900;fc++){if(fc===10)m.keyboard.matrix[2]|=2;if(fc===100)m.keyboard.matrix[2]&=~2;if(fc>400){if((fc-400)%60<3)m.keyboard.matrix[7]|=128;else m.keyboard.matrix[7]&=~128;}m.frame();
 if(fc<420)continue;let blue=0,vramBlue=0;
 for(let y=25;y<100;y++)for(let x=112;x<152;x++)if(!bgAllowsBlue(x,y)){const a=(x>>3)*256+0xDF-y,b=128>>(x&7),v=((m.rd(0x8000+a)&b)?4:0)|((m.rd(0xA000+a)&b)?2:0)|((m.rd(0xC000+a)&b)?1:0);if(v===2)vramBlue++;if(raster[y*256+x]===2){blue++;if(examples.length<12)examples.push({fc,x,y,vram:v});}}
 const ink=[];for(let y=25;y<100;y++)for(let x=112;x<152;x++)if(raster[y*256+x]===3)ink.push(y);
 frames.push({fc,steps,state:m.rd(0x7079),blue,vramBlue,joePixels:ink.length,joeTop:ink.length?Math.min(...ink):null,joeBottom:ink.length?Math.max(...ink):null});
 if(process.env.OUT&&fc>=+(process.env.FROM||458)&&fc<+(process.env.TO||488)){fs.mkdirSync(process.env.OUT,{recursive:true});fs.writeFileSync(`${process.env.OUT}/raster_${fc}.idx`,raster);fs.writeFileSync(`${process.env.OUT}/palette_${fc}.json`,JSON.stringify([...Array(8)].map((_,i)=>m.rd(s.pal+2*i))));}
}
console.log(JSON.stringify({B,blueFrames:frames.filter(f=>f.blue).length,bluePixels:frames.reduce((a,f)=>a+f.blue,0),vramBlueFrames:frames.filter(f=>f.vramBlue).length,examples,frames}));
