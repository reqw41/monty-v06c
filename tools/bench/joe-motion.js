// Display latency against completed logic, respecting the 72E0 layer order.
// Coordinates in spr_rec refer to the ordered game object, not always 7300.
module.exports=function motion(m,s) {
 let steps=0,game=null,last=null,shown=null,frame=0,lastPaint=0,paints=0,stale=0;
 const history=[],states={},bump=(h,k)=>{h[k]=(h[k]||0)+1;};
 const pose=()=>{const a=0x7300+4*m.rd(0x72E0);return {x:m.rd(a+1),y:m.rd(a),state:m.rd(0x7079),step:steps,room:m.rd(0x71A7)+','+m.rd(0x71A8)};};
 return {instruction(pc){if(pc===s.L_A5D1)steps++;
   if(pc===s.frame_wait){game=pose();history.push(game);if(history.length>64)history.shift();}
   if(pc===s.spr_put&&m.rd(s.sp_k)===0){paints++;lastPaint=m.frames;}
 },frame(){frame++;
   if(!game||steps<200||game.state>=8||!m.rd(s.spr_rec)){last=null;return;}
   const now={x:m.rd(s.spr_rec+2),y:m.rd(s.spr_rec+1),room:game.room};
   const z=states[game.state]||(states[game.state]={frames:0,dx:{},dy:{},lagSteps:{},staleFrames:{},paints:0});z.frames++;z.paints+=paints;paints=0;
   const moving=last&&last.room===game.room&&(last.x!==game.x||last.y!==game.y);
   if(shown&&shown.room===now.room){bump(z.dx,Math.abs(now.x-shown.x));bump(z.dy,Math.abs(now.y-shown.y));}
   if(moving){const p=history.slice().reverse().find(q=>q.room===game.room&&q.x===now.x&&q.y===now.y);bump(z.lagSteps,p?game.step-p.step:'unmatched');stale=shown&&shown.x===now.x&&shown.y===now.y&&(game.x!==now.x||game.y!==now.y)?stale+1:0;bump(z.staleFrames,stale);}
   last={...game};shown=now;
 },result(){return {steps,frames:frame,states};}};
};
