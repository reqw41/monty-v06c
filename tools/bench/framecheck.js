// Every completed crit, including a deferred remainder. No global pending-work skip.
// Follow tile/color/phase submission at drawing entry points, independently decode MSX pixels.
// Every cell is checked, including pending cells against the background actually submitted.
const REF=require('./video-ref'),joeRef=require('./joe-ref');
module.exports=function(m,s,options={}) {
 const cells=s.NT_CELLS||768,rows=s.SCREEN_ROWS||24,height=s.SCREEN_HEIGHT||192,top=s.SCREEN_TOP??0xDF;
 const oldTile=new Uint8Array(cells),oldColor=new Uint8Array(cells),oldBelt=new Uint8Array(cells),oldDark=new Uint8Array(cells);
 let started=false,critical=[],checks=0,bad=0;const examples=[];
 const ad=(c,y)=>c*256+top-y-(height===240?(y<48?8:16):0);
 function check(){
  const mask=Array.from({length:3},()=>new Uint8Array(8192)),bits=mask.map(()=>new Uint8Array(8192));
  for(let k=5;k>=0;k--){
   if(s.jn_shown!==undefined&&k<2){if(k===0){const burst=s.joe_burst_grey!==undefined&&m.rd(0x7079)>=8&&[20,21,22].includes(m.rd(s.jn_shown));joeRef(m,s,(x,y,ci)=>{const a=ad(x>>3,y),bit=128>>(x&7);for(let p=s.NES_JOE_BLEND_MODE?1:0;p<3;p++){mask[p][a]|=bit;if(ci&(4>>p))bits[p][a]|=bit;else bits[p][a]&=~bit;}if(burst&&(ci&1)){mask[0][a]|=bit;bits[0][a]|=bit;}});}/* серый дым смерти: 8000 под белыми точками (joe_burst_grey) */continue;}
   const a=s.spr_rec+16*k;if(!m.rd(a))continue;
   const top=(m.rd(a+1)+1)&255,x0=m.rd(a+2),nm=m.rd(a+3)&252,col=m.rd(a+4)&15,ci=m.rd(s.cmap+col),hero=col===6||col===11,enemyInk=s.en_mark!==undefined?(m.rd(a+14)===0x82?4:1):(s.NES_ORANGE_SPIDERS||s.NES_GREEN_SPIDERS)&&[0x2c,0x30].includes(nm)?(s.NES_SHARED_WHITE?4:2):(s.NES_SHARED_WHITE?1:4); // en_mark: плоскость из записи (+14: 82h — 8000, 02h — C000)
   for(let y=0;y<16&&top+y<height;y++){if(s.SCREEN_HEIGHT===240&&top+y<48)continue;for(let half=0;half<2;half++){const b=REF.sprite(nm,half,y);
    for(let bx=0;bx<8;bx++)if(b&(128>>bx)){const x=x0+8*half+bx;if(x>255)continue;const a=ad(x>>3,top+y),bit=128>>(x&7);
     for(let p=0;p<3;p++)if(hero||!!(enemyInk&(4>>p))){mask[p][a]|=bit;if((hero?ci:enemyInk)&(4>>p))bits[p][a]|=bit;else bits[p][a]&=~bit;}
    }
   }
  }}
  const editing=m.rd(s.video_edit),dirty=m.rd(s.video_dirty),room=dirty&s.DIRTY_ROOM,published=m.rd(s.video_enabled)&&!(dirty&(s.DIRTY_ROOM|s.DIRTY_COLOR));
  let errors=0;
  for(let i=0;i<cells;i++){
   const pending=s.SCREEN_HEIGHT===240&&i<192?0:m.rd(s.PND+i)&1;

   const t=oldTile[i],col=oldColor[i],fg=m.rd(s.cmap+((col>>4)||1)),bg=m.rd(s.cmap+((col&15)||1));
   const phases=REF.isAnimated(s,t)?4:1,c=i%32,r=i>>5;let ok=false;
   for(let f=0;f<phases&&!ok;f++){const bytes=REF.cell(m,s,t,f,oldBelt[i],{color:col,dark:!!oldDark[i]});if(s.NES_SCORE_TWO_TONE&&r===3&&((c>=18&&c<30)||(s.NES_LEVEL_TWO_TONE&&c>=14&&c<16))){bytes.fill(0,0,8);if(s.NES_INK_SWAP23)bytes.fill(0,16,24);}ok=true;
    for(let p=0;p<3&&ok;p++){const mode=((fg>>(2-p))&1)|(((bg>>(2-p))&1)<<1);
     for(let y=0;y<8;y++){const a=ad(c,8*r+y),b=bytes[p*8+y],want=(b&~mask[p][a])|bits[p][a];
      if(m.rd(0x8000+0x2000*p+a)!==want){ok=false;break;}
     }
    }
   }
   if(!ok){errors++;if(examples.length<12)examples.push({frame:m.frames,cell:[r,c],tile:t,current:m.rd(s.VNT+i),pending,critPending:m.rd(s.crit_pend),editing,room,dirty,enabled:m.rd(s.video_enabled),belt:oldBelt[i],currentBelt:m.rd(s.belt_shown),color:col,currentColor:m.rd(s.room_colors+(t>>3)),shownColor:m.rd(s.shown_colors+(t>>3)),state:m.rd(0x7079),records:[...Array(6)].map((_,k)=>[...Array(16)].map((_,j)=>m.rd(s.spr_rec+16*k+j)))});}
  }
  checks++;if(errors)bad++;
 }
 return {instruction(pc){
   if(pc===s.boot){started=false;critical.length=0;oldTile.fill(0);oldColor.fill(0);oldBelt.fill(0);}
   if(pc===s.da_blit||pc===s.fl_write){const hl=m.cpu.hl(),c=(hl>>8)&31,raw=top-(hl&255),logical=height===240?(raw<56?raw-8:raw-16):raw,r=logical/8;
    if(Number.isInteger(r)&&r>=0&&r<rows){const i=32*r+c,t=m.rd(s.rr_t);oldTile[i]=t;oldBelt[i]=m.rd(s.belt_shown);oldDark[i]=m.rd(s.room_colors+1)===0x11;
     if(pc===s.da_blit||!m.rd(s.dc_pt))oldColor[i]=m.rd(s.room_colors+(t>>3));}
   }
   if(pc===s.L_A5D1)started=true;
   for(let i=critical.length-1;i>=0;i--){const q=critical[i];if(pc===q.pc&&m.cpu.sp===q.sp+2){critical.splice(i,1);if(started&&!options.manual)check();}}
   if(pc===s.crit){const sp=m.cpu.sp;critical.push({sp,pc:m.rd(sp)|(m.rd(sp+1)<<8)});}},checkNow:check,result(){return {checks,bad,examples};}};
};
