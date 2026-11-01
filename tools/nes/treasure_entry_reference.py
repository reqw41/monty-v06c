#!/usr/bin/env python3
"""Execute NES platform jumps and first bonus panels, including actual rope grabs.

The isolated CPU has no main loop/NMI. On a requested room change, execute
its normal room setup/decode and $963D/$9766 generation before resuming hero.
No rope, input, position or physics instruction is patched in the NES image.
"""
import json
from pathlib import Path
from assets import ROM
from cpu import CPU
ROOT=Path(__file__).resolve().parents[2]
r=ROM((ROOT/'orig/nes/monty.nes').read_bytes())
layouts=json.loads((ROOT/'build/nes-treasure/reference.json').read_text())
ground=[];cases=[]
for side,x,key in [('left',52,129),('right',188,130)]:
 c=r.room(90,9,0,True);m=c.mem
 for a,v in {0x9b:0,0x10:x,0x16:168,0x790:0,0x7ca:255,0x7cb:255,
             0x7c9:1,0x7fd:255,0x40:1 if side=='left' else 2,0x46:0,0x79e:0}.items():m[a]=v
 m[0xe]=0x38;m[0xf]=0xd7;c.a=0;c.call(0xc355);c.call(0x99eb)
 trace=[]
 for step in range(50):
  m[0]=key if step==0 else 0;m[0xa6]=step;c.call(0x97f6)
  if m[0x790]&32:break
  trace.append([m[0x10],m[0x16],m[0x790]])
 assert len(trace)==38 and trace[-1][:2]==([128,215] if side=='left' else [112,215])
 ground.append(dict(side=side,trace=trace))
 saved=bytes(m);ppu=bytes(c.ppu)
 for layout in layouts:
  c=CPU(r.prg);c.mem[:]=saved;c.ppu[:]=ppu;m=c.mem
  m[0x799]=layout['level']-1;m[0xa9:0xab]=layout['seed'].to_bytes(2,'little')
  m[5:7]=m[0x79c:0x79e];m[0xf3]=0
  for address in (0xbd6a,0xbe5e,0xbe8c,0x963d,0x9766):c.call(address)
  assert list(m[0x300:0x600])==[({0:23,0x95:13,0x98:0xd0,0xd8:0xd1,0x99:0xd2,0xd9:0xd3})[t] for t in layout['cells']]
  for step in range(4):
   m[0]=0;m[0xa6]=step;c.call(0x97f6)
   if not m[0x790]&32:break
  assert [m[0x10],m[0x16],m[0x790]]==([128,37,1] if side=='left' else [112,37,1])
  start=[m[0x10],m[0x16],m[0x790]];trace=[];caught=None
  for step in range(65):
   m[0]=0;m[0xa6]=step;c.call(0x97f6)
   if m[0x790]&32:break
   q=[m[0x10],m[0x16],m[0x790]];trace.append(q)
   if q[2]==64 and caught is None:caught=step
   if caught is not None and step-caught>=8:break
  cases.append(dict(side=side,level=layout['level'],seed=layout['seed'],start=start,trace=trace,caught=caught))
output=ROOT/'build/nes-treasure/platform-entry-reference.json'
output.write_text(json.dumps(dict(ground=ground,bonus=cases))+'\n')
print('NES platform approaches:',len(ground),'ground traces;',len(cases),'first-panel traces;',sum(q['caught'] is not None for q in cases),'rope grabs')
for side in ('left','right'):
 q=[q for q in cases if q['side']==side];print(side, 'grabbed:',sum(a['caught'] is not None for a in q),'/',len(q),'(not every random field intersects the flight)')
