#!/usr/bin/env python3
"""Прыжок в стены из тонких плиток (01), потолки разной высоты и ширины, прыжок вверх/по диагонали (эталон — исходный код 6502)."""
import json
from pathlib import Path
import physics_reference as p
ROOT=Path(__file__).resolve().parents[2]
p.cases.clear()
floor=[(18,c,0) for c in range(1,31)]
for tile in (0,1,0x3c,0x41,0x35,0x0f,0x10,0x0c):
 for direction in (1,2):
  # вертикальная стенка из tile
  for bottom in (14,17):
   for d in range(-2,22,3):
    col=18
    wall=[(r,col,tile) for r in range(bottom-3,bottom+1)]
    x=col*8-16-d if direction==1 else (col+1)*8+d
    for kind,keys in (('tap',[0,0,0,0,128|direction]+[0]*14),('hold',[0,0,0,0]+[128|direction]*16)):
     p.case('w3-t%02x-%d-b%d-d%d-%s'%(tile,direction,bottom,d,kind),floor+wall,x=x,y=119,state=0,keys=keys,direction=direction)
  # потолок: ряд плиток над головой на разной высоте, прыжок вверх и по диагонали
  for ceil_row in (11,12,13,14,15):
   for width in (1,3,12):
    for k in (128,128|direction):
     cols=range(14,14+width)
     ceil=[(ceil_row,c,tile) for c in cols]
     p.case('w3-ceil-t%02x-%d-r%d-w%d-k%d'%(tile,direction,ceil_row,width,k),floor+ceil,x=14*8+4+(0 if direction==1 else 8),y=119,state=0,keys=[0,0,0,0,k]+[0]*16,direction=direction)
out=ROOT/'build/nes-physics-audit/wall3-reference.json'
out.write_text(json.dumps(dict(cases=p.cases))+'\n');print('wall3 reference',len(p.cases),'cases')
