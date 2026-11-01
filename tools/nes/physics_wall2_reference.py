#!/usr/bin/env python3
"""Прыжок и ходьба к стенам разной формы: высота, зазор от пола, толщина, момент нажатия (эталон — исходный код 6502)."""
import json,itertools,random
from pathlib import Path
import physics_reference as p
ROOT=Path(__file__).resolve().parents[2]
p.cases.clear()
floor=[(18,c,0) for c in range(1,31)]
rnd=random.Random(7)
n=0
for direction in (1,2):
 for bottom in (11,12,13,14,15,16,17):          # нижний ряд стены (17 — стоит на полу)
  for height in (1,2,4):
   for thick in (1,2):
    for d in range(-2,26,3):
     for kind in ('tap','hold','late'):
      col=18
      cols=range(col,col+thick) if direction==1 else range(col,col+thick)
      wall=[(r,c,0) for r in range(bottom-height+1,bottom+1) for c in cols]
      if direction==1: x=col*8-16-d
      else: x=(col+thick)*8+d
      if not 8<=x<=232:continue
      k=128|direction
      if kind=='tap':keys=[0,0,0,0,k]+[0]*14
      elif kind=='hold':keys=[0,0,0,0]+[k]*16
      else:keys=[0,0,0,0,128]+[0,0]+[direction]*12
      p.case('w2-%d-b%d-h%d-t%d-d%d-%s'%(direction,bottom,height,thick,d,kind),floor+wall,x=x,y=119,state=0,keys=keys,direction=direction)
      n+=1
out=ROOT/'build/nes-physics-audit/wall2-reference.json'
out.write_text(json.dumps(dict(cases=p.cases))+'\n');print('wall2 reference',len(p.cases),'cases')
