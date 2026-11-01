#!/usr/bin/env python3
"""Execute the original NES free-cap climb and both exits in reported room 12."""
import json
from pathlib import Path
from assets import ROM
ROOT=Path(__file__).resolve().parents[2]
r=ROM((ROOT/'orig/nes/monty.nes').read_bytes())
c=r.room(12,3,0,True);m=c.mem
for a,v in {0x9b:0,0x10:108,0x16:93,0x790:64,0x7ca:255,0x7cb:255,
            0x7fd:255,0x40:1,0x46:0,0x7ce:0,0x7c9:1}.items():m[a]=v
m[0xe]=0x38;m[0xf]=0xd7;c.a=5;c.call(0xc355);c.call(0x9ea5)
def step(key,n):
 m[0]=key;m[0xa6]=n;c.call(0x97f6)
 return [m[0x10],m[0x16],m[0x790]]
up=[step(8,n) for n in range(80)]
assert up[-1]==[108,63,0]
saved=bytes(m);ppu=bytes(c.ppu);jumps=[]
for key,side in [(129,'right'),(130,'left')]:
 m[:]=saved;c.ppu[:]=ppu;m[0x7ca]=m[0x7cb]=255
 trace=[step(key if n==0 else 0,n) for n in range(45)]
 assert trace[-1][1:]==[47,0]
 assert trace[-1][0]>=128 if side=='right' else trace[-1][0]<=96
 jumps.append(dict(side=side,trace=trace))
out=ROOT/'build/nes-rope-top';out.mkdir(exist_ok=True)
(out/'reference.json').write_text(json.dumps(dict(room=[2,10],index=12,up=up,jumps=jumps))+'\n')
print('Original NES room12: climb onto cap, both jumps land on upper platform.')
