#!/usr/bin/env python3
"""Прыжок на краю платформы: Джо идёт к краю и нажимает прыжок на каждом шаге N (эталон — исходный код 6502)."""
import json
from pathlib import Path
import physics_reference as p
ROOT=Path(__file__).resolve().parents[2]
p.cases.clear()
for tile in (0,1):
 for direction in (1,2):          # 1 вправо, 2 влево
  for start_off in (0,3,5):
   for n in range(0,40):
    cols=range(10,17) if direction==2 else range(16,23)   # платформа, у края которой уходим
    terrain=[(18,c,tile) for c in cols]
    x=(cols[0]*8+8+start_off) if direction==2 else (cols[-1]*8-8-start_off)
    keys=[direction]*n+[128|direction]+[0]*12
    p.case('ledge-t%d-d%d-o%d-n%d'%(tile,direction,start_off,n),terrain,x=x,y=119,state=0,keys=keys,direction=direction)
out=ROOT/'build/nes-physics-audit/ledge-reference.json'
out.write_text(json.dumps(dict(cases=p.cases))+'\n');print('ledge reference',len(p.cases),'cases')
