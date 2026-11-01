#!/usr/bin/env python3
"""Execute original NES room 27: first jumps and a full right-to-left crossing."""
import json
from pathlib import Path
from assets import ROM
ROOT=Path(__file__).resolve().parents[2]
r=ROM((ROOT/'orig/nes/monty.nes').read_bytes())
def setup():
 c=r.room(27,5,0,True);m=c.mem
 for a,v in {0x9b:0,0x10:232,0x16:87,0x790:0,0x7ca:255,0x7cb:255,
             0x7c9:1,0x7fd:255,0x40:2,0x46:0,0x79e:0,0x1c:255}.items():m[a]=v
 m[0xe]=0x38;m[0xf]=0xd7;c.a=0;c.call(0xc355);c.call(0x99eb)
 return c
def step(c,key,n):
 c.mem[0]=key;c.mem[0xa6]=n;c.call(0x97f6);c.call(0xc3f1);c.call(0xc500)
 return [c.mem[0x10],c.mem[0x16],c.mem[0x790]]
cases=[]
for name,key in [('walk',2),('jump',130)]:
 c=setup();trace=[step(c,key if name=='walk' or n==0 else 0,n) for n in range(40)]
 cases.append(dict(name=name,trace=trace))
c=setup();crossing=[]
for attempt in range(8):
 step(c,0,0);start=[c.mem[0x10],c.mem[0x16]];trace=[]
 for n in range(70):
  trace.append(step(c,130 if n==0 else 0,n))
  if trace[-1][2]==0:break
 crossing.append(dict(start=start,trace=trace))
 if trace[-1][0]<=32 and trace[-1][1]<=88:break
assert crossing[-1]['trace'][-1]==[6,87,0]
out=ROOT/'build/nes-platforms';out.mkdir(exist_ok=True)
(out/'reference.json').write_text(json.dumps(dict(room=[4,7],index=27,cases=cases,crossing=crossing))+'\n')
print('Original NES room27: 19-pixel jump; crossed to left ledge in',len(crossing),'jumps.')
