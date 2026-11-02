// Independent reference: original NES CHR + OAM metadata. Never read the native ready image.
const fs=require('fs'),path=require('path'),root=path.resolve(__dirname,'../..');
const rom=fs.readFileSync(path.join(root,'orig/nes/monty.nes'));
const states=JSON.parse(fs.readFileSync(path.join(root,'build/nes/data/metasprites.json'))).groups.joe.states;
const frames=[],burst=[];
for(const state of states)for(const f of state.frames){
 const parts=f.views['1'].parts;let x0=0,y0=0,w=16,h=24;
 if(state.index===11){x0=Math.min(...parts.map(p=>p.x));y0=Math.min(...parts.map(p=>p.y));w=Math.max(...parts.map(p=>p.x+8))-x0;h=Math.max(...parts.map(p=>p.y+8))-y0;}
 let pic=Array.from({length:h},()=>new Uint8Array(w));
 for(const p of [...parts].reverse())for(let y=0;y<8;y++)for(let x=0;x<8;x++){
  const xx=p.x+x-x0,yy=p.y+y-y0,tx=p.flip_x?7-x:x,ty=p.flip_y?7-y:y,a=32784+16*p.tile+ty;
  const v=((rom[a]>>(7-tx))&1)|(((rom[a+8]>>(7-tx))&1)<<1);
  if(v&&xx>=0&&xx<w&&yy>=0&&yy<h)pic[yy][xx]=v;
 }
 if(state.index===11){const ink=[];for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(pic[y][x])ink.push([x,y]);
  const l=Math.min(...ink.map(p=>p[0])),r=Math.max(...ink.map(p=>p[0]))+1,t=Math.min(...ink.map(p=>p[1])),b=Math.max(...ink.map(p=>p[1]))+1;
  const nw=Math.min(16,r-l),nh=Math.min(23,b-t),out=Array.from({length:24},()=>new Uint8Array(16));
  for(let y=0;y<nh;y++)for(let x=0;x<nw;x++)out[24-nh+y][Math.floor((16-nw)/2)+x]=pic[t+Math.min(b-t-1,Math.floor((y+.5)*(b-t)/nh))][l+Math.min(r-l-1,Math.floor((x+.5)*(r-l)/nw))];pic=out;
 }
 frames.push(pic.slice(1,24).map(row=>Array.from({length:16},(_,x)=>row[x&~1])));
 if(state.index===11)burst.push(frames.length-1);
}
// Порт: дым вспышки белый (NES 3; на экране смерти — серый через 8000), каждая фаза включает предыдущую (joe_native.py).
for(let i=0;i<burst.length;i++){const f=frames[burst[i]],prev=i?frames[burst[i-1]]:null;
 for(let y=0;y<f.length;y++)for(let x=0;x<16;x++)f[y][x]=(f[y][x]||(prev&&prev[y][x]))?3:0;}
module.exports=function(m,s,put){if(!m.rd(s.spr_rec))return;
 const id=m.rd(s.jn_shown),pic=frames[id];if(!pic)throw Error('NES Joe frame '+id);
 const rows=s.joe_nes_rows||23;
 const mirror=m.rd(s.jn_shown_dir),skip=m.rd(s.jn_shown_skip),n=m.rd(s.spr_rec+11),top=(s.SCREEN_TOP??0xDF)-(s.SCREEN_HEIGHT===240?16:0)-m.rd(s.spr_rec+9),x0=m.rd(s.spr_rec+2)+(s.NES_LADDER_CENTERED&&[8,9].includes(id)?1:0);
 for(let y=0;y<n;y++)for(let x=0;x<16&&x0+x<256;x++){
  const v=pic[Math.min(22,Math.floor((skip+y+.5)*23/rows))][mirror?15-x:x];if(!v)continue;
  const ci=s.NES_JOE_COLORS===3?(s.NES_INK_SWAP23?[0,3,2,1]:[0,2,3,1])[v]:(s.NES_INK_SWAP23?[0,1,2,1]:[0,1,3,1])[v];put(x0+x,top+y,ci);
 }
};
