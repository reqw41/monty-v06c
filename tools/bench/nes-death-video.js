// Observe completed raster poses during both death routes, not just the selector.
const assert=require('node:assert/strict'),path=require('node:path');
process.chdir(path.resolve(__dirname,'../..'));
const E=require('../vec_emu'),{symbols}=require('./logic-profile');
const B=process.env.B||'build/native',s=symbols(B),m=E.mk(B+'/monty.bin'),checker=require('./framecheck')(m,s);
m.onInstr=pc=>checker.instruction(pc);
for(let f=0;f<320;f++){if(f===10)m.keyboard.matrix[2]|=2;if(f===100)m.keyboard.matrix[2]&=~2;m.frame();}
function scene(state,fire,frames){
 m.wr(0x7049,6);m.wr(0x7079,state);m.wr(0x70a9,112);m.wr(s.jn_fire,fire);
 for(const [p,y,col] of [[0x7300,100,6],[0x7304,103,11]]){m.wr(p,y);m.wr(p+1,120);m.wr(p+3,col);}
 const seen=new Set(),sample=[];
 for(let f=0;f<frames;f++){m.frame();const pose=m.rd(s.jn_shown);seen.add(pose);if(!sample.length||sample.at(-1)!==pose)sample.push(pose);}
 return {seen,sample};
}
const impact=scene(9,0,85);for(const pose of [5,6,18])assert(impact.seen.has(pose),'missing impact pose '+pose+' '+impact.sample);
const fire=scene(10,1,55);for(const pose of [20,21,22,18])assert(fire.seen.has(pose),'missing fire pose '+pose+' '+fire.sample);
const check=checker.result();assert.equal(check.bad,0,'death raster mismatch');assert(check.checks>0,'no raster checks');
console.log(JSON.stringify({B,impact:impact.sample,fire:fire.sample,check}));
