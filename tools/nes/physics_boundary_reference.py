#!/usr/bin/env python3
"""Original 6502 room-boundary decisions and native-entry anchor references."""
import json
from pathlib import Path
from assets import ROM
from cpu import CPU
ROOT=Path(__file__).resolve().parents[2]
r=ROM((ROOT/'orig/nes/monty.nes').read_bytes());cases=[]
for state in (0,1,2,8,64,128):
 for x in (0,1,2,3,237,238,239,240):
  for y in (20,35,36,37,38,212,213,214,215,216):
   c=CPU(r.prg);m=c.mem
   for a,v in {0x9b:0,0x10:x,0x16:y,0x790:state,0x79a:5,0x79b:27}.items():m[a]=v
   c.push(0x7f);c.push(0xfe);c.pc=0x9c50
   for _ in range(300):
    if c.pc in (0x7fff,0x9cf9):break
    c.step()
   else:raise AssertionError('boundary decision did not terminate')
   cases.append(dict(x=x,y=y,state=state,exit=c.pc==0x9cf9,target=[m[0x79b],m[0x79a]],side=m[0x79e]))
# Full original entry routine, including its pose/bounds setup.
entries=[]
for side in (1,2,3,4):
 c=r.room(27,5,0,True);m=c.mem
 for a,v in {0x9b:0,0x10:116,0x16:100,0x790:32,0x7a0:0,0x79e:side,
             0x7c9:1,0x7fd:255,0x7ca:255,0x7cb:255}.items():m[a]=v
 c.call(0x98cb)
 entries.append(dict(side=side,position=[m[0x10],m[0x16]],state=m[0x790]))
out=ROOT/'build/nes-physics-audit/boundary-reference.json';out.write_text(json.dumps(dict(cases=cases,entries=entries))+'\n')
print('Original NES boundaries:',len(cases),'decisions;',entries)
