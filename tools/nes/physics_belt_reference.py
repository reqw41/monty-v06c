#!/usr/bin/env python3
"""Стоящий и идущий Джо на транспортёрных лентах NES рядом со стенами (эталон — исходный код 6502)."""
import json,math
from pathlib import Path
import physics_reference as p
ROOT=Path(__file__).resolve().parents[2]
p.cases.clear();n=0
for index in range(99):
 c=p.r.room(index,math.isqrt(index),0,True);field=bytes(c.mem[0x300:0x600])
 at=lambda x,y:field[(y-6)*32+x] if 0<=x<32 and 6<=y<30 else 23
 terrain=[(j//32+6,j%32,t) for j,t in enumerate(field) if t!=23]
 for row in range(8,29):
  cols=[col for col in range(32) if 0x3c<=at(col,row)<=0x41]
  if not cols:continue
  y=row*8-25
  if not 38<=y<=207:continue
  lo,hi=min(cols),max(cols)
  for col in {lo,(lo+hi)//2,hi}:
   for keys,name in (([0]*60,'idle'),([1]*60,'right'),([2]*60,'left')):
    p.case('belt-r%d-row%d-col%d-%s'%(index,row,col,name),terrain,x=col*8+4,y=y,state=0,keys=[0,0,0,0]+keys)
    n+=1
out=ROOT/'build/nes-physics-audit/belt-reference.json'
out.write_text(json.dumps(dict(cases=p.cases))+'\n');print('belt reference',len(p.cases),'cases')
