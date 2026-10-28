"""Optional MSX comparison and Vector proposals from existing local build/res.

The NES-only extraction is independent of these cached MSX resources. If absent,
mockups explicitly use a compressed NES layout and the manifest says so.
"""
import json,math
from pathlib import Path
from PIL import Image
from assets import RGB,sheet

ROOT=Path(__file__).resolve().parents[2]
MSX_RGB=[(0,0,0),(0,0,0),(33,200,66),(94,220,120),(84,85,237),(125,118,252),(212,82,77),(66,235,245),(252,85,84),(255,121,120),(212,193,84),(230,206,128),(33,176,59),(201,91,186),(204,204,204),(255,255,255)]

def encode(rgb):
    r,g,b=rgb;return round(b/85)*64+round(g*7/255)*8+round(r*7/255)
def decode(b):return (round((b&7)*255/7),round(((b>>3)&7)*255/7),round((b>>6)*255/3))
def nearest(rgb,pal,allowed):return min(allowed,key=lambda i:sum((rgb[k]-pal[i][k])**2 for k in range(3)))

def make_msx_deliverables(rom,out,groups,canonical,pics,mapping):
    required=['sprites.bin','tiles.bin','colors.bin','rooms_L1.json'];base=ROOT/'build/res';entry=ROOT/'build/monty_entry.bin'
    ready=all((base/f).is_file() for f in required) and entry.is_file()
    status=dict(available=ready,inputs=[str(base/f) for f in required]+[str(entry)],mockup_geometry='MSX 32x24, existing tile masks with NES brick and Joe' if ready else 'NES field compressed from 192 to 152 rows below blank 40-row HUD; illustrative only')
    if ready:
        sprites=(base/'sprites.bin').read_bytes();tiles=(base/'tiles.bin').read_bytes();col=(base/'colors.bin').read_bytes();rooms=json.loads((base/'rooms_L1.json').read_text());img=entry.read_bytes()
        def sprite(n,color):
            im=Image.new('RGBA',(16,16))
            for y in range(16):
                for x in range(16):
                    if sprites[(n&252)*8+(x//8)*16+y]>>(7-x%8)&1:im.putpixel((x,y),(*MSX_RGB[color],255))
            return im
        comparisons=[]
        for row in mapping['joe']:
            a,b=[int(v,16) for v in row['msx_layers'].split('/')];old=Image.new('RGBA',(16,19));old.alpha_composite(sprite(a,6),(0,0));old.alpha_composite(sprite(b,11),(0,3))
            new=pics[f'joe_{row["nes_state"]:02x}_{row["nes_frame"]:02d}_{"right" if row["direction"]==1 else "left"}']
            comparisons.extend([(f'MSX {row["msx_layers"]}\nst '+','.join(f'{n:X}' for n in row['msx_states']),old),(f'NES {row["nes_state"]:02X}:{row["nes_frame"]} '+('R' if row['direction']==1 else 'L'),new)])
        sheet(comparisons,out/'mockups/msx_joe_mapping.png',6,(128,152),3)
        enemy=[]
        for row in mapping['enemies']:
            if row['msx']=='2C/30':
                for n,f in [(44,0),(48,4)]:enemy.extend([(f'MSX {n:02X}',sprite(n,15)),(f'NES spider {f}',pics[f'spider_00_{f:02d}_right'])])
            elif row['msx'] in ('68','78'):
                enemy.extend([(f'MSX {row["msx"]} death',sprite(int(row['msx'],16),15)),(f'NES Joe {row["nes_state"]:02X}',pics[f'joe_{row["nes_state"]:02x}_00_right'])])
            else:
                enemy.extend([(f'MSX {row["msx"]}',sprite(int(row['msx'],16),15)),(f'NES skull {row["nes_frame"]}',pics[f'skull_00_{row["nes_frame"]:02d}_right'])])
        sheet(enemy,out/'mockups/msx_enemy_mapping.png',6,(128,140),3)
        tile_entries=[]
        for t in range(256):
            im=Image.new('RGB',(8,8));cl=col[t//8]
            for y in range(8):
                for x in range(8):im.putpixel((x,y),MSX_RGB[(cl>>4) if tiles[t*8+y]>>(7-x)&1 else cl&15])
            tile_entries.append((f'{t:02X}',im))
        sheet(tile_entries,out/'tiles/msx_reference.png',16,(40,48),4)
    proposals=[]
    for idx in (2,5):
        for nc in (2,3):
            accent=rom.b(0xc5d5+(1 if idx==2 else 2)) if nc==2 else 0x26
            nes_palette=[0x0f,0x27,accent,0x06,0x20,0x20,0x1c,0x20]
            vector=[encode(RGB[n]) for n in nes_palette];pal=[decode(v) for v in vector]
            screen=Image.new('L',(256,192),0);px=screen.load()
            if ready:
                o=rooms[str(idx)];nt=[8]*160+list(bytes.fromhex(o['nt']));floor=o['row'];cc=bytearray(col);cc[1:8]=img[0x93c0+floor*7:0x93c0+floor*7+7]
                for y in range(40,192):
                    for x in range(256):
                        t=nt[y//8*32+x//8];b=tiles[t*8+y%8];old=MSX_RGB[(cc[t//8]>>4) if b>>(7-x%8)&1 else cc[t//8]&15]
                        if t==8:  # NES brick in the same 8x8 MSX geometry.
                            v=rom.tiles[256][y%8][x%8];px[x,y]=[0,3,2,6][v]
                        else:px[x,y]=0 if old==(0,0,0) else 6 if t in (16,17) else nearest(old,pal,[1,2,3,6])
                for kind,pos,K,ts in o['objs']:
                    if kind!='враг':continue
                    p1=pos&255;name='spider' if ts==0x86 else 'skull';en=pics[f'{name}_00_00_right']
                    ex=img[0xa4a5+(p1>>4)];ey=img[0xa496+(p1&15)]-(2 if ts==0x86 else 0)
                    for y in range(en.height):
                        for x in range(en.width):
                            if en.getpixel((x,y))[3] and 0<=ex+x<256 and 0<=ey+y<192:px[ex+x,ey+y]=px[ex+x,ey+y]|4
            else:
                ppu=rom.room(idx,1 if idx==2 else 2).ppu;bg=rom.background(ppu).crop((0,48,256,240)).resize((256,152),Image.Resampling.NEAREST)
                for y in range(152):
                    for x in range(256):px[x,y+40]=nearest(bg.getpixel((x,y)),pal,[0,1,2,3,6])
            for height in (22,19):
                v=screen.copy();vp=v.load();hero=pics['joe_00_00_right'];hero=hero.crop(hero.getbbox());hero=hero.resize((hero.width,height),Image.Resampling.NEAREST)
                ox,feet=(120,73) if idx==2 else (32,101);oy=feet-height
                for y in range(hero.height):
                    for x in range(hero.width):
                        p=hero.getpixel((x,y))
                        if p[3]:vp[ox+x,oy+y]=1 if p[:3]==RGB[0x27] or (nc==2 and p[:3]==RGB[0x26]) else 2 if p[:3]==RGB[0x26] else 3
                image=Image.new('RGB',v.size);image.putdata([pal[i] for i in v.getdata()]);name=f'room_{idx:02d}_{nc}colors_{height}rows'
                image.save(out/f'mockups/{name}.png');v.save(out/f'mockups/{name}_indices.png')
                proposals.append(dict(name=name,room=idx,msx_coordinates=[0,10] if idx==2 else [1,9],joe_colors=nc,joe_size=[hero.width,height],palette_BBGGGRRR=vector,palette_RGB=pal,nes_palette=nes_palette,geometry=status['mockup_geometry'],enemy_compositing='destination index OR 4; current renderer constraint is preserved',max_index=max(v.getdata())))
    floor_palettes=[]
    for floor in range(1,10):
        nes=[0x0f,0x27,rom.b(0xc5d5+floor%9),0x06,0x20,0x20,0x1c,0x20]
        floor_palettes.append(dict(nes_floor=floor,nes_colors=nes,palette_BBGGGRRR=[encode(RGB[n]) for n in nes],note='two-colour Joe; simplified room palette, OR-4 enemy overlap can change hue'))
    (out/'data/vector_floor_palettes.json').write_text(json.dumps(floor_palettes,indent=2)+'\n')
    overview=[]
    for p in proposals:overview.append((p['name'],Image.open(out/f'mockups/{p["name"]}.png')))
    sheet(overview,out/'mockups/overview.png',4,(264,218),1)
    (out/'data/vector_proposals.json').write_text(json.dumps(proposals,ensure_ascii=False,indent=2)+'\n')
    return status


def add_semantic_contexts(mapping):
    """MSX selector $92DC and tables $9378..$93A6; context beats silhouette."""
    contexts={
      '34/98':([0,1,6,7],'9378', [0,2], 'idle 00:0; while walking use NES 01:0/2'),
      '40/A4':([0,1,6,7],'9380', [0,2], 'idle 00:0; while walking use NES 01:0/2'),
      '40/A8':([1],'9380',[3],'NES walking phase 3'),
      '4C/B0':([2],'9388',[0],'jump, even though the silhouette resembles a wide step'),
      '50/B4':([2],'938A',[0],'jump'),
      '54/B8':([3],'938E',[0,2],'two-column ladder 88/89, top 10/11: NES 04:0, climbing up or down'),
      '58/BC':([3],'938E',[1,3],'two-column ladder 88/89, top 10/11: NES 04:1, climbing up or down'),
      '5C/C0':([4],'9396',[0,2],'ladder NES 04:0; rope/pole use NES 05/06/0A by context'),
      '60/C4':([4],'9396',[1,3],'ladder NES 04:1; rope/pole use NES 05/06/0A by context'),
      '64/C8':([5],'938C',[0],'fall / treasure-room descent; NES 03:0'),
      '6C/A0':([1],'9378',[1],'NES walking phase 1'),
      '7C/AC':([1],'9380',[1],'NES walking phase 1'),
      '34/9C':([1],'9378',[3],'NES walking phase 3'),
      'D8/D4':([8],'93A6',[0,1],'death: NES 08 progress for enemy; 0B:1 for fire burst'),
      'E0/DC':([8],'93A6',[2,3],'death: NES 08 progress for enemy; 0B:2 for fire burst'),
    }
    for row in mapping['joe']:
        states,table,phases,note=contexts[row['msx_layers']]
        row.update(msx_states=states,msx_selector='92DC (death: 8B7F)',msx_table=table,msx_phases=phases,policy=note,status='semantic context; different drawings and phase counts')
        if row['msx_layers'] in ('54/B8','58/BC'):
            row.update(nes_state=4,nes_frame=int(row['msx_layers']=='58/BC'))
    mapping['phase_policy']={
      'walk':'MSX four ticks select three unique poses per direction (six total); retain four NES phases, including phase 2, with an independent visual counter or the existing four-phase logical counter.',
      'death':'Use cause and elapsed effect time, not only the MSX layer pair: enemy 08 has five phases; fire 0B has three; lethal fall 02 has two. Map normalised progress or run a separate NES visual counter.',
      'ladder':'Four MSX selector phases repeat two pictures; NES 04 has two pictures. Use phase & 1. Rope/pole states need a separate context.',
      'idle':'MSX reuses walking pose zero for states 0/6/7; NES has a dedicated idle 00. States 6/7 retain motion context when appropriate.'}
