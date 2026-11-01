#!/usr/bin/env python3
"""Прыжки к стенам в реальных комнатах NES: старт на полу рядом со стеной, все выравнивания x, прыжок в сторону стены."""
import json,math,random
from pathlib import Path
import physics_reference as p
ROOT=Path(__file__).resolve().parents[2]
p.cases.clear()
rnd=random.Random(11)
for level in (0,3,6):
 for index in range(99):
  c=p.r.room(index,math.isqrt(index),level,True);field=bytes(c.mem[0x300:0x600])
  at=lambda x,y:field[(y-6)*32+x] if 0<=x<32 and 6<=y<30 else 23
  terrain=[(j//32+6,j%32,t) for j,t in enumerate(field) if t!=23]
  spots=[]
  for row in range(9,29):
   for col in range(2,30):
    if at(col,row) not in (0,1) or at(col,row-1)!=23:continue
    for direction,dx in ((1,1),(2,-1)):
     # стена на уровне туловища в пределах 3 клеток по ходу
     for dist in range(1,4):
      cc=col+dx*dist
      if any(at(cc,row-k)==0 for k in (1,2,3)):
       spots.append((col,row,direction,dist));break
  rnd.shuffle(spots)
  for col,row,direction,dist in spots[:6]:
   y=row*8-25
   if not 40<=y<=190:continue
   off=rnd.randint(0,7)
   x=col*8+off
   if any(at(cc,rr)==0 for rr in range(y//8,(y+22)//8+1) for cc in range((x-3)//8,(x+18)//8+1)):continue
   for kind,keys in (('tap',[0,0,0,0,128|direction]+[0]*16),('hold',[0,0,0,0]+[128|direction]*18),('walkjump',[0,0,0,0]+[direction]*rnd.randint(0,5)+[128|direction]+[direction]*8)):
    p.case('wj-L%d-r%d-c%d-%d-o%d-%s'%(level+1,index,col,direction,off,kind),terrain,x=x,y=y,state=0,keys=keys,direction=direction)
out=ROOT/'build/nes-physics-audit/walljump-reference.json'
out.write_text(json.dumps(dict(cases=p.cases))+'\n');print('walljump reference',len(p.cases),'cases')
