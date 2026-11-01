#!/usr/bin/env python3
"""Execute the original NES treasure routines; export deterministic test cases."""
import json
from pathlib import Path
from assets import ROM, RGB
from cpu import CPU
ROOT=Path(__file__).resolve().parents[2]
r=ROM((ROOT/'orig/nes/monty.nes').read_bytes())
records=[]
for level in range(1,10):
 for seed in dict.fromkeys((1,0x101,0x1234,0x8000,0xabcd,0xffff)+tuple(range(1,257) if level==1 else ())):
  c=CPU(r.prg);c.mem[0xa9:0xab]=seed.to_bytes(2,'little');c.mem[0x799]=level-1
  c.ppu[0x20c0:0x23c0]=bytes([23])*768;c.mem[0x300:0x600]=bytes([23])*768
  ropes=[];original_step=c.step
  def step():
   if c.pc==0x9608:
    address=c.mem[0xa3]|(c.mem[0xa4]<<8)
    ropes.append(dict(column=address&31,row=(address-0x20c0)//32,length=c.y))
   original_step()
  c.step=step
  c.call(0x963d);rope_writes=list(c.writes);c.call(0x9766)
  assert 5<=len(ropes)<=7
  assert all(2<=q['column']<=29 and 3<=q['row']<=18 and q['length']>=3 and q['row']+q['length']<=24 for q in ropes)
  assert not any((address&31)<2 or (address&31)>29 for address,_ in rope_writes)
  mapping={23:0,13:0x95,0xd0:0x98,0xd1:0xd8,0xd2:0x99,0xd3:0xd9}
  records.append(dict(level=level,seed=seed,rng=int.from_bytes(c.mem[0xa9:0xab],'little'),
                      cells=[mapping[t] for t in c.ppu[0x20c0:0x23c0]],gems=c.mem[0x140],
                      rope_writes=rope_writes,ropes=ropes))
  if level==1 and seed==0x101:
   c.mem[0x79a]=10;c.mem[0x7ff]=255;c.mem[0x7fd]=255;c.call(0xac9a);c.call(0xaceb)
   out=ROOT/'build/nes-treasure';out.mkdir(parents=True,exist_ok=True)
   r.background(c.ppu).resize((512,480)).save(out/'nes-reference.png')
out=ROOT/'build/nes-treasure/reference.json';out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(records)+'\n');print('Original NES treasure cases:',len(records))
