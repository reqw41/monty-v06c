// Display latency against completed logic, respecting the 72E0 layer order.
// Coordinates in spr_rec refer to the ordered game object, not always 7300.
module.exports=function motion(m,s) {
 let steps=0,game=null,last=null,shown=null,frame=0,lastPaint=0,paints=0,stale=0,painting=null,committed=null,clippedFrames=0;
 const history=[],states={},examples=[],bump=(h,k)=>{h[k]=(h[k]||0)+1;};
 const pose=()=>{const a=0x7300+4*m.rd(0x72E0);return {x:m.rd(a+1),y:s.jn_shown!==undefined?Math.max(m.rd(0x7300),m.rd(0x7304)):m.rd(a),state:m.rd(0x7079),step:steps,epoch:s.jn_epoch===undefined?null:m.rd(s.jn_epoch),room:m.rd(0x71A7)+','+m.rd(0x71A8)};};
 const remember=q=>{const last=history.at(-1);if(last&&last.step===q.step&&last.x===q.x&&last.y===q.y&&last.room===q.room)return;history.push(q);if(history.length>64)history.shift();};
 return {reset(){game=null;last=null;shown=null;committed=null;history.length=0;stale=0;},instruction(pc){if(pc===s.room_redraw){game=null;last=null;shown=null;committed=null;history.length=0;stale=0;}if(pc===s.L_A5D1){remember(pose());steps++;}
   if(pc===s.frame_wait){game=pose();remember(game);}
   // Successful coordinate comparison is independent evidence that the already
   // committed picture still represents this newer game pose, without repaint.
   if(pc===s.jn_motion_valid&&committed&&!painting){const q=pose();if(q.x===committed.x&&q.y===committed.y)remember(q);}
   if(painting&&pc===painting.pc&&m.cpu.sp===painting.sp+2){paints++;lastPaint=m.frames;committed={x:m.rd(s.spr_rec+2),y:s.jn_shown!==undefined?(s.SCREEN_TOP??0xDF)-m.rd(s.spr_rec+9)-m.rd(s.jn_shown_skip)+s.joe_nes_rows-17:m.rd(s.spr_rec+1),epoch:s.jn_last_epoch===undefined?null:m.rd(s.jn_last_epoch),room:game?game.room:''};painting=null;}
   if(pc===s.spr_put&&m.rd(s.sp_k)===0){const sp=m.cpu.sp;painting={sp,pc:m.rd(sp)|(m.rd(sp+1)<<8)};}
 },frame(){frame++;
   if(!game||steps<200||game.state>=8||!committed||(m.rd(s.video_dirty)&s.DIRTY_ROOM)){last=null;shown=null;return;}
   // In the full field the head can be clipped by the six-row HUD during
   // a room crossing. Count those frames explicitly; a full-pose deadline
   // starts once the entire natural-height cell is inside the field again.
   if(s.SCREEN_HEIGHT===240&&game.y<s.HUD_ROWS*8+s.joe_nes_rows-17){clippedFrames++;last=null;shown=null;return;}
   const now={...committed};
   const z=states[game.state]||(states[game.state]={frames:0,dx:{},dy:{},lagSteps:{},staleFrames:{},paints:0});z.frames++;z.paints+=paints;paints=0;
   const moving=last&&last.room===game.room&&(last.x!==game.x||last.y!==game.y);
   if(shown&&shown.room===now.room){bump(z.dx,Math.abs(now.x-shown.x));bump(z.dy,Math.abs(now.y-shown.y));}
   if(moving){const p=history.slice().reverse().find(q=>q.room===game.room&&q.x===now.x&&q.y===now.y);const sampled=s.jn_last_epoch===undefined?Infinity:((game.epoch-committed.epoch)&255),matched=p?game.step-p.step:Infinity,age=Math.min(sampled,matched);bump(z.lagSteps,!Number.isFinite(age)?'unmatched':age>128?'ahead':age);if(age>2&&age<128&&examples.length<8)examples.push({frame:m.frames,game,shown:now,sampled,matched,dirty:m.rd(s.video_dirty),pending:m.rd(s.crit_pend),source:[...Array(8)].map((_,i)=>m.rd(0x7300+i)),record:[...Array(16)].map((_,i)=>m.rd(s.spr_rec+i))});stale=shown&&shown.x===now.x&&shown.y===now.y&&(game.x!==now.x||game.y!==now.y)?stale+1:0;bump(z.staleFrames,stale);}
   last={...game};shown=now;
 },result(){return {steps,frames:frame,clippedFrames,states,examples};}};
};
