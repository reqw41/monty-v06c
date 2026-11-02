#!/usr/bin/env python3
"""Stable NES pickup/door inks, in unused legacy Joe restore destinations."""
from pathlib import Path
import json
from assets import ROM
ROOT=Path(__file__).resolve().parents[2]
def main():
 r=ROM((ROOT/'orig/nes/monty.nes').read_bytes())
 # Existing full_raw includes every ordinary 1bpp mask. Reuse it unchanged.
 text=(ROOT/'src/native/gen/video_full.asm').read_text().split('full_raw:\n')[1].split('video_raw_end:')[0]
 old=[bytes(map(int,l.strip()[3:].split(','))) for l in text.splitlines() if l.strip().startswith('db ')]
 assert all(len(x)==8 for x in old)
 assert len(old)<0xc0, "ordinary mask references collide with extra mask tags"
 new=[]
 def ptr(mask):
  if mask in old:return old.index(mask)
  if mask not in new:new.append(mask)
  n=new.index(mask);assert n<24
  return 0xc0+(n//12)*16+n%12
 entries={}
 for t,nt in [(0xd0,0x104),(0xd1,0x105),(0x62,0x106),(0x63,0x107),(0xa9,0x12b),(0xaf,0x12c)]:entries[t]=(nt,[0,2,3,6])
 for t,nt in [(0x9a,0x10a),(0x9b,0x10b)]:entries[t]=(nt,[0,5,2,6])  # низ лезвия меча — серый слот 5, как 96/97
 for t,nt in [(0xc0,0x139),(0xc7,0x139),(0xc1,0x156),(0xc2,0x157),(0xc3,0x158),(0xc5,0x159),(0xb0,0x13a),(0xb7,0x13a),(0xb1,0x15a),(0xb2,0x15b),(0xb3,0x15c),(0xb4,0x15d)]:entries[t]=(nt,[0,1,2,6])
 for key,nt in [(0xf0,0x123),(0xf4,0x124)]:
  for phase in range(4):
   tile=nt+2*phase
   entries[key+phase]=(tile,[0,2,3,6])
 records=[]
 for key,(nt,mapping) in sorted(entries.items()):
  planes=[bytes(sum(128>>x for x in range(8) if mapping[r.tiles[nt][y][x]]&bit) for y in range(8)) for bit in (4,2,1)]
  records.append([key,*map(ptr,planes)])
 assert len(records)*4+1<=0x71
 out=['; Generated from original NES CHR. No extra per-frame colour conversion.', 'STABLE_OBJECT_COLORS equ 1',' ORG 0xFB30','object_masks_0:']
 for p in new[:12]:out.append(' db '+','.join(map(str,p)))
 out+=[' ASSERT $ <= 0xFB97',' ORG 0xFD30','object_masks_1:']
 for p in new[12:]:out.append(' db '+','.join(map(str,p)))
 out+=[' ASSERT $ <= 0xFD95',' ORG 0xFC30','object_color_records:']
 for record in records:out.append(' db '+','.join(map(str,record)))
 out+=[' db 255','object_color_records_end:',' ASSERT $ <= 0xFCA1']
 (ROOT/'src/native/gen/object_colors.asm').write_text('\n'.join(out)+'\n')
 d=ROOT/'build/nes_full';d.mkdir(exist_ok=True)
 (d/'object_colors.json').write_text(json.dumps(dict(new_mask_bytes=8*len(new),records=records,record_bytes=4*len(records)+1,mappings=dict(items=[0,2,3,6],doors_sword=[0,1,2,6])),indent=2)+'\n')
 print('Stable object colours:',len(new),'new masks,',len(records),'records;',8*len(new)+4*len(records)+1,'bytes')
if __name__=='__main__':main()
