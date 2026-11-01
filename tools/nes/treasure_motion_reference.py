#!/usr/bin/env python3
"""Original 6502 hero motion in an empty bonus field and on vertical ropes."""
import json
from pathlib import Path
from assets import ROM
from cpu import CPU
ROOT = Path(__file__).resolve().parents[2]
r = ROM((ROOT/'orig/nes/monty.nes').read_bytes())
cases = []
for column in range(2, 30):
 for rope in (False, True):
  c = CPU(r.prg); m = c.mem
  m[0x300:0x600] = bytes([23])*768
  for address, value in {0x9b:0, 0x79a:10, 0x7ce:0, 0x79e:3, 0:0,
                        0x10:column*8-4, 0x16:37, 0x790:1, 0x7ca:255,
                        0x7fd:255, 0x40:1, 0x7c9:1}.items():
   m[address] = value
  c.call(0x99eb)
  if rope:
   for row in range(12, 18): m[0x300+(row-6)*32+column] = 13
  trace = []
  for step in range(35):
   m[0] = 0; m[0xa6] = step; c.call(0x97f6)
   trace.append([m[0x10], m[0x16], m[0x790]])
  assert trace[-1][1:] == ([73,64] if rope else [142,1])
  cases.append(dict(column=column, rope=rope, trace=trace))
p = ROOT/'build/nes-treasure/motion-reference.json'; p.parent.mkdir(parents=True, exist_ok=True)
p.write_text(json.dumps(cases)+'\n')
print('Original NES bonus motion:', len(cases), 'cases, 35 steps each')
# Real rope inputs from a middle position, including both rope ends.
controls = []
for name, key in [('hold',0), ('up',8), ('down',4), ('left',2), ('right',1)]:
 c = CPU(r.prg); m = c.mem; m[0x300:0x600] = bytes([23])*768
 for a,v in {0x9b:0,0x79a:10,0x7ce:0,0x79e:3,0x10:116,0x16:100,
             0x790:64,0x7ca:255,0x7fd:255,0x40:1,0x7c9:1,0x784:4}.items(): m[a]=v
 m[0x0e]=0x38; m[0x0f]=0xd7; c.a=5; c.call(0xc355)
 for row in range(12,18): m[0x300+(row-6)*32+15]=13
 trace=[]
 for step in range(80):
  m[0]=key; m[0xa6]=step; c.call(0x97f6)
  trace.append([m[0x10],m[0x16],m[0x790]])
 controls.append(dict(name=name,trace=trace))
(ROOT/'build/nes-treasure/control-reference.json').write_text(json.dumps(controls)+'\n')
print('Original NES rope controls:', len(controls), 'cases, 80 steps each')
# Full sideways rope jump: press/release, both directions, heights and recatches.
jumps=[]
for y in (73,100,117):
 for direction,key in [('left',130),('right',129)]:
  for held in (False,True):
   for distance in range(5):
    c=CPU(r.prg);m=c.mem;m[0x300:0x600]=bytes([23])*768
    for a,v in {0x9b:0,0x79a:10,0x7ce:0,0x79e:3,0x10:116,0x16:y,
                0x790:64,0x7ca:255,0x7fd:255,0x40:1,0x7c9:1,0x784:4}.items():m[a]=v
    m[0x0e]=0x38;m[0x0f]=0xd7;c.a=5;c.call(0xc355)
    for row in range(12,18):m[0x300+(row-6)*32+15]=13
    target=15+distance*(-1 if direction=='left' else 1) if distance else None
    if target is not None:
     for row in range(9,25):m[0x300+(row-6)*32+target]=13
    c.call(0x9ea5)  # same jump counter/bounds reset as an actual rope grab
    trace=[]
    for step in range(45):
     m[0]=key if held or step==0 else 0;m[0xa6]=step;c.call(0x97f6)
     trace.append([m[0x10],m[0x16],m[0x790]])
    jumps.append(dict(y=y,direction=direction,held=held,target=target,trace=trace))
(ROOT/'build/nes-treasure/jump-reference.json').write_text(json.dumps(jumps)+'\n')
print('Original NES rope jumps:',len(jumps),'cases, 45 steps each')
