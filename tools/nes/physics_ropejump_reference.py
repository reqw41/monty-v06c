#!/usr/bin/env python3
"""Прыжок к верёвке с пола с разных расстояний (эталон — исходный код 6502)."""
import json
from pathlib import Path
import physics_reference as p
ROOT=Path(__file__).resolve().parents[2]
p.cases.clear()
floor=[(18,c,0) for c in range(2,30)]
for tile in (13,):
 for ropecol in (15,):
  rope=[(r,ropecol,tile) for r in range(8,18)]
  for direction in (1,2):
   for d in range(0,40):
    x=(ropecol*8-20-d) if direction==1 else (ropecol*8+8+d)
    keys=[0,0,0,0,128|direction]+[0]*14
    p.case('rope-d%d-x%d'%(direction,d),floor+rope,x=x,y=119,state=0,keys=keys,direction=direction)
    keys2=[0,0,0,0,128|direction]+[direction]*6+[0]*8
    p.case('rope-hold-d%d-x%d'%(direction,d),floor+rope,x=x,y=119,state=0,keys=keys2,direction=direction)
out=ROOT/'build/nes-physics-audit/ropejump-reference.json'
out.write_text(json.dumps(dict(cases=p.cases))+'\n');print('rope jump reference',len(p.cases),'cases')
