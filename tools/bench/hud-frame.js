// Static NES HUD frame (rows 1..5 of the six HUD rows): drawn once by the title,
// never by the game. Cells outside the frame are 0. Mirrors tools/nes/title_native.py.
const frame=new Uint8Array(192);
for(const c of [...Array(11)].map((_,i)=>i+1).concat([...Array(13)].map((_,i)=>i+18))){frame[32+c]=0xfa;frame[160+c]=0xfb;}
for(let y=1;y<6;y++)for(const [x,t] of [[0,0xf8],[12,0xf9],[17,0xf9],[31,0xf8]])frame[y*32+x]=t;
frame[32+17]=0xfd;frame[160+17]=0xfc;
module.exports=frame;
