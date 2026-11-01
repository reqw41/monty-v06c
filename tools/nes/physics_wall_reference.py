#!/usr/bin/env python3
"""Прыжок и ходьба к стене с разных расстояний (эталон — исходный код 6502)."""
import json
from pathlib import Path
import physics_reference as p
ROOT=Path(__file__).resolve().parents[2]
p.cases.clear()
floor=[(18,c,0) for c in range(2,30)]
for direction in (1,2):
 for d in range(0,13):
  for kind,key in (('jump',128|direction),('walk',direction),('jumpwalk',128|direction)):
   col=20 if direction==1 else 11
   wall=[(r,col,0) for r in range(10,18)]
   x=(col*8-16-d) if direction==1 else (col*8+8+d)
   keys=[0,0,0,0]+([key]+([direction]*10 if kind!='jump' else [0]*10))
   p.case('wall-d%d-x%d-%s'%(direction,d,kind),floor+wall,x=x,y=119,state=0,keys=keys,direction=direction)
for direction in (1,2):
 for d in range(0,24):
  for hold in (6,12):
   col=20 if direction==1 else 11
   wall=[(r,col,0) for r in range(10,18)]
   x=(col*8-16-d) if direction==1 else (col*8+8+d)
   keys=[0,0,0,0]+[direction]*(hold)+[128|direction]+[0]*10
   p.case('wall-d%d-x%d-stuck%d'%(direction,d,hold),floor+wall,x=x,y=119,state=0,keys=keys,direction=direction)
out=ROOT/'build/nes-physics-audit/wall-reference.json'
out.write_text(json.dumps(dict(cases=p.cases))+'\n');print('wall reference',len(p.cases),'cases')
