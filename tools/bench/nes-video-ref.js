// Independent full-field reference, decoding original NES CHR/OAM, never tile cache.
const fs=require('fs'),path=require('path'),root=path.resolve(__dirname,'../..');
const rom=fs.readFileSync(path.join(root,'orig/nes/monty.nes'));
const msx=fs.readFileSync(path.join(root,'build/monty_entry.bin'));
const data=JSON.parse(fs.readFileSync(path.join(root,'build/nes_full/graphics.json'))),chars=data.chars;
const meta=JSON.parse(fs.readFileSync(path.join(root,'build/nes/data/metasprites.json'))).groups.snake.states[0].frames;
const animated=new Set(data.animations),fg=[6,2,6,2,2,2,2,2,2,2,0,0,2,2,1,6,6,6,1,2,6,2,6,2,1,6,2,2,2,2,1,6];
const chr=(t,x,y)=>((rom[32784+16*t+y]>>(7-x))&1)|(((rom[32784+16*t+y+8]>>(7-x))&1)<<1);
const snakes={};
for(let phase=0;phase<2;phase++)for(const direction of [1,2]){const view=meta[phase].views[String(direction)],parts=view.parts,x0=Math.min(...parts.map(p=>p.x)),y0=Math.min(...parts.map(p=>p.y)),pic=Array.from({length:16},()=>new Uint8Array(16));for(const p of [...parts].reverse())for(let y=0;y<8;y++)for(let x=0;x<8;x++){const xx=p.x-x0+x,yy=p.y-y0+y,v=chr(p.tile,p.flip_x?7-x:x,p.flip_y?7-y:y);if(v&&xx>=0&&xx<16&&yy>=0&&yy<16)pic[yy][xx]=v;}snakes[`${phase}:${direction}`]=pic;}
const snakeParts={160:[1,0],161:[1,1],162:[1,2],163:[1,3],165:[2,0],164:[2,1],167:[2,2],166:[2,3]};
function pixels(t,phase,belt){let tile=chars[t];
 if(t===0xde||t===0x6f)tile=t===0xde?0x155:0x154;
 if(t>=4&&t<=6)tile=0x13c+3*phase+t-4;
 if(t>=0xb8&&t<=0xba)tile=0x13c+3*((4-phase)%4)+t-0xb8;
 if(t===0xa8||t===0xae)tile=0x123+2*phase+(t===0xae?1:0);
 if(t>=0xd2&&t<=0xd5)tile=0x118+(phase+t-0xd2)%4;
 if(t===0xe0)tile=0x12d+2*(belt&3);if(t===0xe8)tile=0x135+(belt&3);
 const out=Array.from({length:8},()=>new Uint8Array(8));
 for(let y=0;y<8;y++)for(let x=0;x<8;x++){const sn=snakeParts[t];out[y][x]=sn?snakes[`${phase&1}:${sn[0]}`][8*(sn[1]>>1)+y][8*(sn[1]&1)+x]:tile===undefined?0:(t===0xde||t===0x6f)?y===0?0:chr(tile,x,y-1):chr(tile,x,y);}
 return out;
}
function cell(m,s,t,phase,belt,options={}){const p=pixels(t,phase,belt),indices=Array.from({length:8},()=>new Uint8Array(8));let ink=fg[t>>3];
 if(ink===2)ink=7;
 if(s.STABLE_OBJECT_COLORS&&[12,13,19,23,26].includes(t>>3))ink=3;
 if(s.STABLE_OBJECT_COLORS&&[0xd8,0xd9].includes(t))ink=3;
 let objectMap=null;
 if(s.STABLE_OBJECT_COLORS){
  if([0x62,0x63,0xd0,0xd1,0xa8,0xae,0xa9,0xaf].includes(t))objectMap=[0,3,2,6];
  if([0x96,0x97,0x9a,0x9b,0xb0,0xb1,0xb2,0xb3,0xb4,0xb7,0xc0,0xc1,0xc2,0xc3,0xc5,0xc7].includes(t))objectMap=[0,1,3,6];
  if(s.fsm_grey&&(t===0x96||t===0x97))objectMap=[0,5,3,6]; // мечи: белое лезвие — серый слот 5
 }
 if(s.STABLE_OBJECT_COLORS&&t===0x9c)ink=3; // red-door foot, independent of jewel ink
 const col=options.color===undefined?m.rd(s.room_colors+(t>>3)):options.color,dark=options.dark===undefined?m.rd(s.room_colors+1)===0x11:options.dark;
 const terrain=t<0x18||t===0x38||(t>=0x88&&t<=0x95)||(t>=0xc8&&t<=0xcd)||(t>=0xd2&&t<=0xd7);
 if(t===0xca||t===0xcb)ink=7;if(t===0xcc||t===0xcd)ink=1;if(t===0xd6||t===0xd7)ink=6;
 if(t>=0xa0&&t<=0xa7)ink=s.NES_MONO_SNAKE?4:5;
 if(t>=0xd2&&t<=0xd5)ink=3;
 if(s.STABLE_OBJECT_COLORS&&[0x98,0x99,0xd8,0xd9].includes(t))ink=2; // becomes fixed skin index 3 after the 2/3 swap
 if(s.NES_TREASURE_GOLD&&m.rd(0x71a7)>=9&&m.rd(0x71a7)<255&&[0x98,0x99,0xd8,0xd9].includes(t))ink=4;
 if((t>=4&&t<=6)||(t>=0xb8&&t<=0xba))ink=2;
 if(s.LADDER_IN_JOE_PLANES&&[0x10,0x11,0x88,0x89].includes(t))ink=1;
 if(t===0xe0||t===0xe8)ink=col===0?0:t===0xe0&&s.NES_WHITE_CHAINS?1:col===0x40?m.rd(s.cmap+4):m.rd(s.cmap+10);
 for(let y=0;y<8;y++)for(let x=0;x<8;x++)indices[y][x]=t===0xe8?(col===0?0:(((msx[0x85ca+8*(belt&1)+y]>>(7-x))&1)*(y===2?1:(s.NES_GREY_PLATFORMS?5:6)))):t===0xde||t===0x6f?[0,3,1,1][p[y][x]]:dark&&terrain?0:(t===8||t===11||(t>=0xc8&&t<=0xcb))?[0,3,7,6][p[y][x]]:t===0x38?3:objectMap?objectMap[p[y][x]]:p[y][x]?ink:0;
 if(s.CONVEYOR_TWO_INKS&&((t>=4&&t<=6)||(t>=0xb8&&t<=0xba)))
  for(let y=0;y<8;y++)for(let x=0;x<8;x++)indices[y][x]=dark&&terrain?0:[0,2,0,1][p[y][x]];
 if(s.rope_image&&(t===0x95||t===0x90)&&!dark)for(let y=0;y<8;y++)for(let x=0;x<8;x++) // колонна: белое 1..4, серое 5..6, перекладина
  indices[y][x]=t===0x90&&y<2?1:x>=1&&x<=4?1:x>=5&&x<=6?5:0;
 if(s.NES_INK_SWAP23)for(let y=0;y<8;y++)for(let x=0;x<8;x++)if(indices[y][x]===2||indices[y][x]===3)indices[y][x]^=1;
 const out=[];for(const bit of [4,2,1])for(let y=0;y<8;y++)out.push(indices[y].reduce((a,v,x)=>a|((v&bit)?128>>x:0),0));return out;
}
module.exports={cell,animated,pixels};
