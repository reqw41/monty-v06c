// Every completed crit, including a deferred remainder. No global pending-work skip.
// Follow tile/color/phase submission at drawing entry points, independently decode MSX pixels.
// Every cell is checked, including pending cells against the background actually submitted.
const REF=require('./video-ref');
module.exports=function(m,s) {
 const oldTile=new Uint8Array(768),oldColor=new Uint8Array(768),oldBelt=new Uint8Array(768);
 let started=false,critical=false,checks=0,bad=0;const examples=[];
 const ad=(c,y)=>c*256+0xDF-y;
 function check(){
  const mask=Array.from({length:3},()=>new Uint8Array(8192)),bits=mask.map(()=>new Uint8Array(8192));
  for(let k=5;k>=0;k--){const a=s.spr_rec+16*k;if(!m.rd(a))continue;
   const top=(m.rd(a+1)+1)&255,x0=m.rd(a+2),nm=m.rd(a+3)&252,col=m.rd(a+4)&15,ci=m.rd(s.cmap+col),hero=col===6||col===11;
   for(let y=0;y<16&&top+y<192;y++)for(let half=0;half<2;half++){const b=REF.sprite(nm,half,y);
    for(let bx=0;bx<8;bx++)if(b&(128>>bx)){const x=x0+8*half+bx;if(x>255)continue;const a=ad(x>>3,top+y),bit=128>>(x&7);
     for(let p=0;p<3;p++)if(hero||p===0){mask[p][a]|=bit;if((hero?ci:4)&(4>>p))bits[p][a]|=bit;else bits[p][a]&=~bit;}
    }
   }
  }
  const editing=m.rd(s.video_edit),dirty=m.rd(s.video_dirty),room=dirty&s.DIRTY_ROOM,published=m.rd(s.video_enabled)&&!(dirty&(s.DIRTY_ROOM|s.DIRTY_COLOR));
  let errors=0;
  for(let i=0;i<768;i++){
   const pending=m.rd(s.PND+i)&1;

   const t=oldTile[i],col=oldColor[i],fg=m.rd(s.cmap+((col>>4)||1)),bg=m.rd(s.cmap+((col&15)||1));
   const phases=REF.animated.has(t)?4:1,c=i%32,r=i>>5;let ok=false;
   for(let f=0;f<phases&&!ok;f++){const pat=REF.pattern(t,f,oldBelt[i]);ok=true;
    for(let p=0;p<3&&ok;p++){const mode=((fg>>(2-p))&1)|(((bg>>(2-p))&1)<<1);
     for(let y=0;y<8;y++){const a=ad(c,8*r+y),b=[0,pat[y],pat[y]^255,255][mode],want=(b&~mask[p][a])|bits[p][a];
      if(m.rd(0x8000+0x2000*p+a)!==want){ok=false;break;}
     }
    }
   }
   if(!ok){errors++;if(examples.length<12)examples.push({frame:m.frames,cell:[r,c],tile:t,current:m.rd(s.VNT+i),pending,critPending:m.rd(s.crit_pend),editing,room,dirty,enabled:m.rd(s.video_enabled),belt:oldBelt[i],currentBelt:m.rd(s.belt_shown),color:col,currentColor:m.rd(s.room_colors+(t>>3)),shownColor:m.rd(s.shown_colors+(t>>3)),state:m.rd(0x7079),records:[...Array(6)].map((_,k)=>[...Array(16)].map((_,j)=>m.rd(s.spr_rec+16*k+j)))});}
  }
  checks++;if(errors)bad++;
 }
 return {instruction(pc){
   if(pc===s.da_blit||pc===s.fl_write){const hl=m.cpu.hl(),c=(hl>>8)&31,r=(0xDF-(hl&255))/8;
    if(Number.isInteger(r)&&r>=0&&r<24){const i=32*r+c,t=m.rd(s.rr_t);oldTile[i]=t;oldBelt[i]=m.rd(s.belt_shown);
     if(pc===s.da_blit||!m.rd(s.dc_pt))oldColor[i]=m.rd(s.room_colors+(t>>3));}
   }
   if(pc===s.L_A5D1)started=true;if(pc===s.crit)critical=true;
   if(pc===s.isr0&&critical){critical=false;if(started)check();}},result(){return {checks,bad,examples};}};
};
