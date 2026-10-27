#!/usr/bin/env python3
"""Compare extracted metasprites to controller-only MAME OAM and visible pixels.

MAME frame_done includes the *next* vblank DMA; live_capture.lua retains the
previous callback's DMA for the screen it captures. No fitted XY offsets or
colours are used. RGB comes independently from MAME's PPU palette device.
"""
import argparse,csv,json,struct,zlib
from PIL import Image
from collections import defaultdict
from pathlib import Path
from assets import ROM,GROUPS,RGB

def verify(rom,assets,root):
 r=ROM(rom.read_bytes());catalog=json.loads((assets/'data/metasprites.json').read_text())['groups']
 lookup={}
 for group,g in catalog.items():
  for state in g['states']:
   for f in state['frames']:lookup[group,int(f['rom'][1:],16)]=(state['index'],f['index'],f['views'])
 canonical=json.loads((assets/'data/rooms.json').read_text())['rooms']['2']['palette']
 png_checks={};coverage=defaultdict(list);results=[]
 for profile in sorted(root.iterdir()):
  if not (profile/'complete.json').exists():continue
  pal=json.loads((profile/'palette.json').read_text())
  for capture in csv.DictReader((profile/'captures.tsv').open(),delimiter='\t'):
   base=profile/capture['base'];ram=base.with_suffix('.ram').read_bytes();oam=base.with_suffix('.oam').read_bytes();ppu=base.with_suffix('.ppu').read_bytes();mask=int(capture['mask'])
   raw_pixels=zlib.decompress(base.with_suffix('.pixels.z').read_bytes()) if base.with_suffix('.pixels.z').exists() else base.with_suffix('.pixels').read_bytes()
   pixels=struct.unpack('<61440I',raw_pixels);emphasis=(mask&0xe0)<<1
   # Rasterise actual OAM independently of metasprite assembly. Keep sprite
   # priority, flips, palette, scanline limit, clipping and background priority.
   actual={};owners={};scanlines=[[] for _ in range(240)]
   for i in range(64):
    y,t,a,x=oam[i*4:i*4+4];y+=1
    for yy in range(8):
     sy=y+yy
     if sy>=240:continue
     if i not in scanlines[sy]:scanlines[sy].append(i)
     if len(scanlines[sy])>8:continue
     for xx in range(8):
      sx=x+xx
      if sx>=256 or (sx<8 and not mask&4):continue
      v=r.tiles[t][7-yy if a&128 else yy][7-xx if a&64 else xx]
      pos=sy*256+sx
      if v and pos not in actual:
       actual[pos]=pal[(ppu[0x3f10+(a&3)*4+v]&63)+emphasis];owners[pos]=(i,a)
   for slot in range(6):
    start=ram[0x76+slot];count=ram[0x7c+slot]
    if start==255 or not count:continue
    ptr=ram[0x2e+slot]+256*ram[0x34+slot];group='joe' if slot==0 else next((g for g in GROUPS if g!='joe' and (g,ptr) in lookup),None)
    if (group,ptr) not in lookup:continue
    state,phase,views=lookup[group,ptr];direction=1 if ram[0x40+slot]==1 else 2;view=views[str(direction)]
    parts=view['parts'];x=ram[0x10+slot];y=ram[0x16+slot]
    expected=bytes(v for p in parts for v in ((y+p['y'])&255,p['tile'],p['attribute'],(x+p['x'])&255))
    got=oam[start*4:(start+count)*4];oam_errors=sum(a!=b for a,b in zip(expected,got))+abs(len(expected)-len(got))
    key=f'{group}:{state:02X}:{phase}:{direction}'
    if not oam_errors and key not in png_checks:
     pic=Image.open(assets/view['image']).convert('RGBA');x0,y0,x1,y1=view['cell_bounds'];ink={}
     for i in range(count-1,-1,-1):
      oy,t,a,ox=got[i*4:i*4+4]
      for yy in range(8):
       for xx in range(8):
        v=r.tiles[t][7-yy if a&128 else yy][7-xx if a&64 else xx]
        px=(ox-x)&255;py=(oy-y)&255
        px=px if px<128 else px-256;py=py if py<128 else py-256
        if v:ink[px+xx-x0,py+yy-y0]=(*RGB[canonical[16+(a&3)*4+v]],255)
     offsets=[]
     for i in range(count):
      oy,t,a,ox=got[i*4:i*4+4];dx=(ox-x)&255;dy=(oy-y)&255
      offsets.append((dx if dx<128 else dx-256,dy if dy<128 else dy-256))
     actual_box=[min(v[0] for v in offsets),min(v[1] for v in offsets),max(v[0]+8 for v in offsets),max(v[1]+8 for v in offsets)]
     png_errors=int(actual_box!=view['cell_bounds'] or pic.size!=(actual_box[2]-actual_box[0],actual_box[3]-actual_box[1]))

     for yy in range(pic.height):
      for xx in range(pic.width):
       actual_pixel=pic.getpixel((xx,yy));want=ink.get((xx,yy),(0,0,0,0))
       png_errors+=actual_pixel[3]!=want[3] or (want[3]!=0 and actual_pixel!=want)
     png_checks[key]=dict(image=view['image'],errors=png_errors)
    # Compare all visible foreground samples belonging to this actor, plus its
    # transparent pixels against the captured PPU background/other actors.
    x0,y0,x1,y1=view['cell_bounds'];screen_errors=foreground=background=0;examples=[]
    for sy in range(max(0,y+y0+1),min(240,y+y1+1)):
     for sx in range(max(0,x+x0),min(256,x+x1)):
      pos=sy*256+sx;tx,ty=sx//8,sy//8;t=ppu[0x2000+ty*32+tx]+256
      v=r.tiles[t][sy%8][sx%8] if mask&8 and (sx>=8 or mask&2) else 0
      at=ppu[0x23c0+(ty//4)*8+tx//4];pi=(at>>((ty%4//2)*4+(tx%4//2)*2))&3
      want=pal[(ppu[0x3f00+(pi*4+v if v else 0)]&63)+emphasis]
      if pos in actual and not (owners[pos][1]&32 and v):want=actual[pos]
      belongs=pos in owners and start<=owners[pos][0]<start+count
      if belongs:foreground+=1
      else:background+=1
      if want!=pixels[pos]:
       screen_errors+=1
       if len(examples)<3:examples.append([sx,sy,hex(want),hex(pixels[pos])])
    item=dict(profile=profile.name,frame=int(capture['frame']),slot=slot,key=key,selector_state=ram[0x1c+slot],next_phase=ram[0x58+slot],meta=f'{ptr:04X}',xy=[x,y],oam_errors=oam_errors,screen_errors=screen_errors,foreground_pixels=foreground,background_pixels=background,examples=examples)
    results.append(item)
    if oam_errors==0 and screen_errors==0:coverage[key].append(dict(profile=profile.name,frame=int(capture['frame']),foreground=foreground))
 summary=dict(png_checks=png_checks,captures=len({(v['profile'],v['frame']) for v in results}),actor_checks=len(results),exact_checks=sum(v['oam_errors']==v['screen_errors']==0 for v in results),coverage=dict(sorted(coverage.items())),failures=[v for v in results if v['oam_errors'] or v['screen_errors']],checks=results)
 missing=[]
 for group,g in catalog.items():
  for state in g['states']:
   for f in state['frames']:
    if not any(f'{group}:{state["index"]:02X}:{f["index"]}:{direction}' in coverage for direction in (1,2)):
     missing.append(f'{group}:{state["index"]:02X}:{f["index"]}')
 summary['missing_frame_references']=missing
 (assets/'data/live_verification.json').write_text(json.dumps(summary,indent=2)+'\n')
 rows=['| Состояние:фаза | Вправо — профиль / кадр | Влево — профиль / кадр |','|---|---|---|']
 pictures=[]
 from assets import sheet
 for state in catalog['joe']['states']:
  for f in state['frames']:
   cells=[]
   for direction in (1,2):
    key=f'joe:{state["index"]:02X}:{f["index"]}:{direction}'
    samples=coverage.get(key,[])
    cells.append(f'совпало: `{samples[0]["profile"]}` / {samples[0]["frame"]}' if samples else 'не наблюдалось')
    if samples:
     sample=samples[0];v=next(v for v in results if v['key']==key and v['profile']==sample['profile'] and v['frame']==sample['frame'])
     x,y=v['xy'];x0,y0,x1,y1=f['views'][str(direction)]['cell_bounds']
     screen=Image.open(root/sample['profile']/f'frame_{sample["frame"]:05d}.png')
     pic=screen.crop((x+x0,y+y0+1,x+x1,y+y1+1))
     pictures.append((f'{state["index"]:02X}:{f["index"]} '+('R' if direction==1 else 'L')+f' / f{sample["frame"]}\n'+sample['profile'],pic))
   rows.append(f'| `{state["index"]:02X}:{f["index"]}` | '+ ' | '.join(cells)+' |')
 flights={name:[dict(frame=v['frame'],xy=v['xy'],state=3,phase=0,direction=int(v['key'].rsplit(':',1)[1])) for v in results if v['profile']==name and v['slot']==0 and v['key'].startswith('joe:03:')] for name in ('jump_still','jump_running')}
 (assets/'data/live_flights.json').write_text(json.dumps(flights,indent=2)+'\n')
 (assets/'data/live_coverage.md').write_text('\n'.join(rows)+'\n')
 sheet(pictures,root/'joe_verified.png',6,(164,160),3)

 print(json.dumps({k:v for k,v in summary.items() if k not in ('checks','coverage','failures','png_checks')},indent=2));print('coverage',','.join(coverage));print('failures',len(summary['failures']))
 for item in summary['failures'][:12]:print(item)
 return summary
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('rom',type=Path);p.add_argument('assets',type=Path);p.add_argument('captures',type=Path);a=p.parse_args();result=verify(a.rom,a.assets,a.captures)
 if result['failures'] or result['missing_frame_references'] or any(v['errors'] for v in result['png_checks'].values()):raise SystemExit(1)
