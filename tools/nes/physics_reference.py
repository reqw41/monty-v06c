#!/usr/bin/env python3
"""Run the unmodified NES hero on controlled terrain and input sequences."""
import json
from pathlib import Path
from assets import ROM
from cpu import CPU
ROOT=Path(__file__).resolve().parents[2]
r=ROM((ROOT/'orig/nes/monty.nes').read_bytes())
cases=[]
def case(name,terrain,x=116,y=119,state=0,keys=None,bonus=False,direction=1):
 c=CPU(r.prg);m=c.mem;m[0x300:0x600]=bytes([23])*768
 for row,col,tile in terrain:
  m[0x300+(row-6)*32+col]=tile
 for a,v in {0x9b:0,0x79a:10 if bonus else 5,0x79b:27,0x7ce:0,0x79e:0,0x10:x,0x16:y,
             0x790:state,0x7ca:255,0x7cb:255,0x7c9:1,0x7fd:255,0x40:direction,0x46:0,
             0x785:1 if state==1 else 0,0x7a7:y if state==1 else 0,0x7be:6,0x794:1,0x791:0,0x1c:255,0x04:255}.items():m[a]=v
 m[0xe]=0x38;m[0xf]=0xd7;c.a=5 if state==64 else 4 if state==8 else 0;c.call(0xc355)
 if state==64:c.call(0x9ea5)
 else:c.call(0x99eb)
 if state==1:m[0x785]=1;m[0x7a7]=y
 trace=[]
 for n,key in enumerate(keys or [0]*40):
  m[0]=key;m[0xa6]=n;c.call(0x97f6)
  c.call(0xc3f1);c.call(0xc500)  # actual actor-frame and facing commit
  trace.append([m[0x10],m[0x16],m[0x790],m[0x7be],m[0x783],m[0x7a8]])
 cases.append(dict(name=name,terrain=terrain,x=x,y=y,state=state,keys=keys or [0]*40,bonus=bonus,direction=direction,trace=trace))
floor=[(18,c,0) for c in range(2,30)]
for name,keys in [('idle',[0]*40),('walk-right',[1]*40),('walk-left',[2]*40),('jump-right',[129]+[0]*39),('jump-left',[130]+[0]*39),('jump-up',[128]+[0]*39),('jump-held',[129]*40),('jump-reverse',[129]+[2]*39)]:case(name,floor,keys=keys)
for height in range(0,66):case('fall-'+str(height),floor,y=119-height,state=1)
for kind,tile in [('solid',0),('thin',1),('fire',0x18),('crumble',0x35),('belt-left',0x3c),('belt-right',0x3f)]:
 for x in (112,116,120):case(kind+'-floor-'+str(x),[(18,c,tile) for c in range(10,22)],x=x,y=103,state=1)
for height in (4,8,12,16,24):
 for direction in (1,2):case('wall-'+str(height)+'-'+str(direction),floor+[(row,17 if direction==1 else 12,0) for row in range(10,18-height//8)],x=116,keys=[128|direction]+[0]*39)
for row in (12,13,14):case('ceiling-'+str(row),floor+[(row,c,0) for c in range(10,22)],keys=[129]+[0]*39)
for tile in (0,1):
 for offset in range(8):case('edge-'+str(tile)+'-'+str(offset),[(18,16,tile)],x=116+offset,keys=[1]*16)
for bonus in (False,True):
 terrain=[(row,15,13) for row in range(10,20)]
 for name,key in [('hold',0),('up',8),('down',4),('left',2),('right',1),('jump-left',130),('jump-right',129)]:case(('bonus-' if bonus else '')+'rope-'+name,terrain,y=100,state=64,keys=[key]*40,bonus=bonus)
for name,key in [('hold',0),('up',8),('down',4),('left',2),('right',1),('jump-left',130),('jump-right',129)]:
 case('ladder-'+name,[(row,15,17) for row in range(10,20)]+[(row,16,18) for row in range(10,20)],x=120,y=100,state=8,keys=[key]*40)
for key in (1,2):
 wall=floor+[(row,17 if key==1 else 12,0) for row in range(10,18)]
 case('ground-wall-'+str(key),wall,x=116,keys=[key]*40)
 case('ground-wall-reverse-'+str(key),wall,x=116,keys=[key]*16+[3-key]*24)
# Entry windows and two complete ends of a real two-tile ladder.
ladder=[(row,15,17) for row in range(11,18)]+[(row,16,18) for row in range(11,18)]
ladder += [(10,15,15),(10,16,16)]+floor
for x in range(110,137,2):
 case('ladder-entry-up-'+str(x),ladder,x=x,y=119,keys=[8]*48)
 case('ladder-entry-down-'+str(x),ladder,x=x,y=55,keys=[4]*48)
for x in range(110,137,2):
 case('ladder-entry-left-up-'+str(x),ladder,x=x,y=119,keys=[8]*48,direction=2)
 case('ladder-entry-left-down-'+str(x),ladder,x=x,y=55,keys=[4]*48,direction=2)
for name,key in [('hold',0),('left',2),('right',1),('up',8),('down',4)]:
 case('pole-'+name,[(row,15,14) for row in range(10,20)],y=80,state=1,keys=[key]*45)
# Pause/resume, held Fire, both vertical keys, and actual rope endpoints.
for bonus in (False,True):
 ropes=[(row,15,13) for row in range(12,18)]
 for pause in range(4):
  case(('bonus-' if bonus else '')+'rope-up-phase-'+str(pause),ropes,y=100,state=64,keys=[0]*pause+[8]*100,bonus=bonus)
 for key in (4,8,12):
  case(('bonus-' if bonus else '')+'rope-long-'+str(key),ropes,y=100,state=64,keys=[key]*100,bonus=bonus)
 case(('bonus-' if bonus else '')+'rope-fire-wait-left',ropes,y=100,state=64,keys=[128]*4+[130]*45,bonus=bonus)
 case(('bonus-' if bonus else '')+'rope-fire-wait-right',ropes,y=100,state=64,keys=[128]*4+[129]*45,bonus=bonus)
case('ladder-both-vertical',[(row,15,17) for row in range(10,20)]+[(row,16,18) for row in range(10,20)],x=120,y=100,state=8,keys=[12]*40)
for direction in (1,2):
 case('walk-midstride-turn-'+str(direction),floor+[(row,17 if direction==2 else 12,0) for row in range(10,18)],keys=[direction]*6+[3-direction]*30)
# Reported free-rope cap: walk in from the right ledge, release, then descend.
field=r.room(5,2,0,True).mem[0x300:0x600]
room5=[(j//32+6,j%32,t) for j,t in enumerate(field) if t!=23]
for parity in (0,1):
 for walk in range(14,23):
  case('room5-cap-approach-'+str(parity)+'-'+str(walk),room5,x=232+parity,y=87,keys=[2]*walk+[0]*8+[4]*30)
case('upper-room-jump-block',[(8,col,1) for col in range(5,26)],y=39,keys=[128]+[0]*45)
out=ROOT/'build/nes-physics-audit/reference.json';out.parent.mkdir(exist_ok=True);out.write_text(json.dumps(cases)+'\n')
print('Unmodified NES reference:',len(cases),'scenarios',sum(len(q['trace']) for q in cases),'steps')
