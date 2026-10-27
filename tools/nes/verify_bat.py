#!/usr/bin/env python3
"""Execute original bat routines to check timing, entry points and flight details."""
import argparse,json
from pathlib import Path
from assets import ROM
from cpu import CPU

def run(rom,out):
 r=ROM(rom.read_bytes());checks={}
 def fresh():
  c=CPU(r.prg);c.mem[0x76:0x7c]=bytes([0,255,255,255,255,255]);c.mem[0x1c:0x22]=bytes([255])*6;return c
 c=fresh();m=c.mem;m[0x79a]=1;m[0x7c4]=63;m[0x7c5]=7
 for step in range(1,1601):
  c.call(0xbc24)
  assert (m[0x7c5]==0)==(step==1600)
 assert m[0x7c4]==255 and m[0x83]==0xbe and m[0x89]==0xb2
 checks['timer_calls_to_spawn']=1600
 for _ in range(256):c.call(0xbc24)
 assert m[0x7c4:0x7c6]==bytes([255,0])
 c=fresh();c.mem[0x79a]=10;c.mem[0x7c4:0x7c6]=bytes([63,7]);c.call(0xbc24);assert c.mem[0x7c4:0x7c6]==bytes([63,7])
 checks['treasure_floor_skips_timer']=True
 entries=[]
 for entry,xy in enumerate([(120,31),(8,31),(232,31),(120,31),(120,240)]):
  c=fresh();m=c.mem;m[0x79e]=entry;c.call(0xb1ff);assert (m[0x11],m[0x17])==xy
  assert m[0x8f]==4 and m[0x41]==1 and m[0x83]+256*m[0x89]==0xb2be
  entries.append(dict(entry=entry,xy=xy))
 checks['spawn_points']=entries
 # Exhaustive byte-difference cases, including the original $9F stale value.
 n=0
 for bx,by,tx,ty in [(100,100,100,100),(100,100,99,99),(100,100,130,70),(0,0,255,255),(255,255,0,0),(255,1,1,255)]:
  for scratch in [0,1,31,255]:
   c=fresh();m=c.mem;m[0x9b]=1;m[0x11]=bx;m[0x17]=by;m[0x7c7]=tx;m[0x7c8]=ty;m[0x7c6]=1;m[0x9f]=scratch
   dx=(tx-bx)&255;dy=(ty-by)&255
   wantx=bx if dx in (0,255) else (bx+(1 if tx>=bx else -1))&255
   wanty=by if dy in (0,255) else (by+(1 if ty>=by else -1))&255
   want_scratch=dx if dx in (0,255) else scratch
   want_c6=0 if dy in (0,255) and want_scratch in (0,255) else 1
   c.x=1;c.call(0xb355);assert (m[0x11],m[0x17],m[0x9f],m[0x7c6])==(wantx,wanty,want_scratch,want_c6);n+=1
 checks['approach_cases']=n
 for seed in [1,2,0x1234,0x8000,0xffff]:
  c=fresh();d=fresh();m=c.mem;m[0xa9]=seed&255;m[0xaa]=seed>>8;m[0x10]=116;m[0x16]=87
  d.mem[:2048]=m[:2048];rng=[]
  for _ in range(4):d.call(0x8000);rng.append(d.a)
  c.call(0xb2fb)
  assert m[0x7c7]==(116+((rng[0]&31) if rng[1]<127 else -(rng[0]&31)))&255
  assert m[0x7c8]==(87-(rng[2]&31))&255
  assert m[0xa9:0xab]==d.mem[0xa9:0xab]
 checks['random_target_four_calls_and_y_overwrite']=5
 scripts=[]
 for spawn,handler,ticks,xy in [(0xb268,0xb44a,75,(150,239)),(0xb293,0xb3d0,137,(241,174))]:
  c=fresh();c.call(spawn)
  for _ in range(ticks):c.call(handler)
  assert (c.mem[0x11],c.mem[0x17])==xy
  c.call(handler);assert c.mem[0x7cc]==255
  scripts.append(dict(spawn=f'{spawn:04X}',handler=f'{handler:04X}',moving_or_waiting_ticks=ticks,final_xy=xy))
 checks['special_scripts']=scripts
 out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(checks,indent=2)+'\n');print(json.dumps(checks,indent=2))
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('rom',type=Path);p.add_argument('output',type=Path);a=p.parse_args();run(a.rom,a.output)
