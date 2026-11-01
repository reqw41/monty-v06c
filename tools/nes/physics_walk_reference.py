#!/usr/bin/env python3
"""Случайная ходьба и прыжки в реальных комнатах NES (99 комнат), исходный код 6502 как эталон.
Сравнение с нативной сборкой: B=... REF=build/nes-physics-audit/walk-reference.json VERIFY=1 node tools/bench/nes-physics-audit.js"""
import json,math,random,sys
from pathlib import Path
import physics_reference as p
ROOT=Path(__file__).resolve().parents[2]
N=int(sys.argv[1]) if len(sys.argv)>1 else 6   # стартов на комнату
LEVELS=[0,3,6]
rnd=random.Random(20261101)
p.cases.clear()
def keys():
 out=[0,0,0,0];
 while len(out)<70:
  kind=rnd.choice([0,1,2,129,130,128,1,2,129,130])
  out+=[kind]+[{129:0,130:0,128:0}.get(kind,kind)]*rnd.randint(0,14)
 return out[:70]
for level in LEVELS:
 for index in range(99):
  c=p.r.room(index,math.isqrt(index),level,True);field=bytes(c.mem[0x300:0x600])
  def at(x,y):return field[(y-6)*32+x] if 0<=x<32 and 6<=y<30 else 23
  spots=[]
  for row in range(8,29):
   for col in range(1,31):
    # стоит на плитке 00 или 01 (пол), над ней два свободных ряда
    if at(col,row) in (0,1) and at(col,row-1)==23 and at(col,row-2)==23 and at(col,row-3)==23:spots.append((col,row))
  if not spots:continue
  terrain=[(j//32+6,j%32,t) for j,t in enumerate(field) if t!=23]
  for k in range(N):
   col,row=rnd.choice(spots);x=col*8+4
   y=row*8-25
   if any(at(cc,rr)==0 for rr in range(y//8,(y+22)//8+1) for cc in range((x-3)//8,(x+18)//8+1)):continue  # Джо не должен начинать внутри стены
   if not 50<=y<=185 or not 16<=x<=224:continue
   p.case('walk-L%d-r%d-%d'%(level+1,index,k),terrain,x=x,y=y,state=0,keys=keys(),direction=rnd.choice((1,2)))
  if index%33==0:print('level',level+1,'room',index,'cases',len(p.cases),flush=True)
out=ROOT/'build/nes-physics-audit/walk-reference.json'
out.write_text(json.dumps(dict(cases=p.cases))+'\n')
print('walk reference',len(p.cases),'traces',sum(len(q['trace']) for q in p.cases),'steps')
