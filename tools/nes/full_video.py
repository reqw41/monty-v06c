#!/usr/bin/env python3
"""NES CHR fitted to the full native map; no screenshot-derived masks."""
from pathlib import Path
import json
from assets import ROM, RGB
from msx import encode
ROOT=Path(__file__).resolve().parents[2]

def main():
 r=ROM((ROOT/'orig/nes/monty.nes').read_bytes());v0=(ROOT/'build/native/vram0.bin').read_bytes()
 chars={8:0x100,11:0x101,0xd6:0x102,0xd7:0x103,0x90:0x10c,0x95:0x10d,0xcc:0x10e,0xcd:0x10e,
        0x88:0x111,0x89:0x112,0x10:0x10f,0x11:0x110,0xc8:0x113,0xc9:0x114,0xca:0x115,0xcb:0x116}
 def block(native,nes):
  chars.update({t:0x100+nes+i for i,t in enumerate(native)})
 block([0x70,0x71,0x72,0x73],0x4c);block([0x78,0x79,0x7a,0x7b],0x50);block([0x68,0x69,0x6a,0x6b],0x48)
 block([0xd0,0xd1,0x62,0x63],4);block([0x96,0x97,0x9a,0x9b],8);block([0x98,0xd8,0x99,0xd9],0xd0)
 chars.update({0xa8:0x123,0xae:0x124,0xa9:0x12b,0xaf:0x12c,0xc0:0x139,0xc7:0x139,0xb0:0x13a,0xb7:0x13a,0xbb:0x13b,0x9c:0x13b})
 block([0xc1,0xc2,0xc3,0xc5],0x56);block([0xb1,0xb2,0xb3,0xb4],0x5a);block([0xbc,0xbd,0xbe,0xbf],0x5e)
 for n in range(10):
  for part in range(4):chars[(0xDA if n==8 else 0x18+4*n)+part]=(0x1f8 if n==0 else 0x1d0+4*n)+part
  chars[0x40+n]=0x160+n
 chars[0x4a]=0x183
 chars.update({0x6f:0x154,0x6e:0x155,0xf8:0x122,0xf9:0x1cd,0xfa:0x120,0xfb:0x121,0xfc:0x1ce,0xfd:0x1cf})
 masks={t:bytes(sum(128>>x for x in range(8) if r.tiles[chrid][y][x]) for y in range(8)) for t,chrid in chars.items()}
 masks[0x38]=bytes(8)
 # Both directions of the stationary snake, kept as a four-cell native hazard.
 meta=json.loads((ROOT/'build/nes/data/metasprites.json').read_text())['groups']['snake']['states'][0]['frames'][0]
 for direction,tiles in [(1,[0xa0,0xa1,0xa2,0xa3]),(2,[0xa5,0xa4,0xa7,0xa6])]:
  parts=r.meta(int(meta['rom'][1:],16),direction);x0=min(p['x'] for p in parts);y0=min(p['y'] for p in parts)
  pic=[[0]*16 for _ in range(16)]
  for p in parts[::-1]:
   for y in range(8):
    for x in range(8):
     xx=p['x']-x0+x;yy=p['y']-y0+y
     if 0<=xx<16 and 0<=yy<16:
      v=r.tiles[p['tile']][7-y if p['flip_y'] else y][7-x if p['flip_x'] else x]
      if v:pic[yy][xx]=v
  for part,t in enumerate(tiles):masks[t]=bytes(sum(128>>x for x in range(8) if pic[(part//2)*8+y][(part%2)*8+x]) for y in range(8))
 strips={}
 def ptr(b):return strips.setdefault(b,len(strips))
 base=[ptr(masks.get(t,bytes(8))) for t in range(256)]
 anim=[4,5,6,0xa8,0xae,0xd2,0xd3,0xd4,0xd5,0xb8,0xb9,0xba]
 frames=[]
 for t in anim:
  for phase in range(4):
   if t in (4,5,6):chrid=0x13c+3*phase+t-4
   elif t in (0xb8,0xb9,0xba):chrid=0x13c+3*((-phase)%4)+t-0xb8
   elif t in (0xa8,0xae):chrid=0x123+2*phase+(t==0xae)
   elif 0xd2<=t<=0xd5:chrid=0x118+(phase+t-0xd2)%4
   else:chrid=chars[t]
   frames.append(ptr(bytes(sum(128>>x for x in range(8) if r.tiles[chrid][y][x]) for y in range(8))))
 # Full NES laser masks replace the old MSX strip tables.
 lasers=[]
 for ids in ([0x12d,0x12f,0x131,0x133],[0x135,0x137]):
  lasers.append([ptr(bytes(sum(128>>x for x in range(8) if r.tiles[n][y][x]) for y in range(8))) for n in ids])
 assert len(strips)<256
 out=['; Generated NES CHR masks for the full 256x240 field.','anim_set: db '+','.join(map(str,anim))+',255','col0: db '+','.join(map(str,v0[0x2000:0x2020])),'raw_base:']
 for i in range(0,256,32):out.append(' db '+','.join(map(str,base[i:i+32])))
 out+=['raw_anim: db '+','.join(map(str,frames)),'full_laser_v: db '+','.join(map(str,lasers[0])),'full_laser_h: db '+','.join(map(str,lasers[1]))]
 transitions={};names=[]
 for old in range(4):
  for new in range(4):
   changed=tuple(t for i,t in enumerate(anim) if frames[4*i+old]!=frames[4*i+new]);names.append(transitions.setdefault(changed,f'nf_delta_{len(transitions)}'))
 inverse=list(strips)
 rowmask=lambda ids:sum(1<<y for y in range(8) if len({inverse[i][y] for i in ids})>1)
 out+=['full_anim_rowmask: db '+','.join(str(rowmask(frames[4*i:4*i+4])) for i in range(len(anim))), 'full_laser_rowmask: db '+','.join(str(rowmask(ids)) for ids in lasers)]
 out+=['fire_transitions: dw '+','.join(names)]
 for values,name in transitions.items():out.append(name+': db '+','.join(map(str,values+(255,))))
 out+=['video_low_end equ $',' ORG 0x6900','full_raw:']
 for data in strips:out.append(' db '+','.join(map(str,data)))
 out+=['video_raw_end equ $',' ORG video_low_end']
 (ROOT/'src/native/gen/video_full.asm').write_text('\n'.join(out)+'\n')
 # Bricks and hats preserve their separate inks; colour 2 is the floor accent.
 def image(t,mapping):return bytes(sum(128>>x for x in range(8) if mapping[r.tiles[t][y][x]]&bit) for bit in (4,2,1) for y in range(8))
 sty=['; Full-size NES bricks and 16x8 life hat.','style_bricks:',' db '+','.join(map(str,image(0x100,[0,3,2,6])+image(0x101,[0,3,2,6]))),'style_hat:',' db '+','.join(map(str,image(0x154,[0,3,2,6]))),'style_hat_right:',' db '+','.join(map(str,image(0x155,[0,3,2,6]))),'style_accents: db '+','.join(str(encode(RGB[r.b(0xc5d5+i)])) for i in range(9))]
 # The four-piece ornamental ladder cap uses all three NES ink values.
 sty[0]='; Full-size NES bricks, patterned ladder cap and 16x8 life hat.'
 sty[3:3]=['style_vase:',' db '+','.join(map(str,b''.join(image(t,[0,3,2,6]) for t in range(0x113,0x117))))]
 fg=[6,2,6,2,2,2,2,2,2,2,0,0,2,2,1,6,6,6,1,2,6,2,6,2,1,6,2,2,2,2,1,6]
 modes=[sum(((ci>>bit)&1)<<(2*bit) for bit in range(3)) for ci in fg]
 sty+=['full_modes: db '+','.join(map(str,modes))]
 (ROOT/'src/native/gen/style_full.asm').write_text('\n'.join(sty)+'\n')
 output=ROOT/'build/nes_full';output.mkdir(parents=True,exist_ok=True)
 (output/'graphics.json').write_text(json.dumps(dict(chars=chars,animations=anim,raw_strips=len(strips),raw_bytes=8*len(strips),floor_inks='black, white, accent, dark brown, cyan'),indent=2)+'\n')
 print(len(strips),'NES strips;',8*len(strips),'raw bytes')
if __name__=='__main__':main()
