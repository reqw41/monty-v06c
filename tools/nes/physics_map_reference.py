#!/usr/bin/env python3
"""NES movement cases from the decoded geometry of all 99 rooms, nine levels."""
import json,math
from pathlib import Path
import physics_reference as p
ROOT=Path(__file__).resolve().parents[2]
seen={};occurrences=[]
for level in range(9):
 for index in range(99):
  floor=math.isqrt(index)
  c=p.r.room(index,floor,level,True);field=bytes(c.mem[0x300:0x600])
  def at(x,y):return field[(y-6)*32+x] if 0<=x<32 and 6<=y<30 else 23
  for x in range(1,30):
   for y in range(6,30):
    kind='ladder' if at(x,y)==17 and at(x+1,y)==18 else 'rope' if at(x,y) in (12,13) else None
    if not kind:continue
    match=lambda row:at(x,row)==17 and at(x+1,row)==18 if kind=='ladder' else at(x,row) in (12,13)
    if match(y-1):continue
    end=y
    while end<29 and match(end+1):end+=1
    key=(kind,x,y,end,field[max(0,y-8)*32:min(24,end-4)*32])
    occurrence=dict(level=level+1,index=index,kind=kind,x=x,top=y,bottom=end)
    occurrences.append(occurrence)
    if key not in seen:seen[key]=(occurrence,field)
 print('decoded level',level+1,'unique climb neighborhoods',len(seen),flush=True)
p.cases.clear()
for i,(run,field) in enumerate(seen.values()):
 x,top,end=run['x'],run['top'],run['bottom'];kind=run['kind']
 terrain=[(j//32+6,j%32,t) for j,t in enumerate(field) if t!=23]
 px=x*8-(4 if kind=='rope' else 0);state=64 if kind=='rope' else 8
 for name,row,key in [('middle-up',(top+end)//2,8),('middle-down',(top+end)//2,4),('top-up',top,8),('bottom-down',end,4)]:
  py=row*8-16
  if not 38<=py<=207:continue
  steps=min(40,max(1,2*(py-37))) if key==8 else min(40,max(1,(213-py)))
  p.case('map-'+str(i)+'-'+name,terrain,x=px,y=py,state=state,keys=[key]*steps)
  p.cases[-1]['location']=run
 if i%20==0:print('executed',i,'neighborhoods',len(p.cases),'traces',flush=True)
out=ROOT/'build/nes-physics-audit/map-reference.json'
out.write_text(json.dumps(dict(rooms=99,levels=9,occurrences=occurrences,unique=len(seen),cases=p.cases))+'\n')
print('NES map reference complete',len(p.cases),'traces',sum(len(q['trace']) for q in p.cases),'steps',flush=True)
