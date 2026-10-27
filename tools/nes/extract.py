#!/usr/bin/env python3
"""Extract the local Montezuma NROM assets. Requires Python 3.10+ and Pillow.

python3 tools/nes/extract.py orig/nes/monty.nes build/nes/
All extracted images/data stay in the requested (normally ignored) output folder.
"""
import argparse, hashlib, json, math
from collections import Counter,defaultdict
from pathlib import Path
from PIL import Image,ImageDraw
from assets import ROM,RGB,GROUPS,JOE_NAMES,hx,sheet

ROOT=Path(__file__).resolve().parents[2]
ANIMATIONS=[
 dict(name='fire_lower',table=0xc599,count=4,update='8C22',cadence='once per completed background-update round'),
 dict(name='fire_upper',table=0xc59d,count=4,update='8D40',cadence='once per completed background-update round'),
 dict(name='conveyor_left',table=0xc5a1,count=4,update='BB98 / 8DAF',cadence='phase every 4 game frames'),
 dict(name='conveyor_middle',table=0xc5a5,count=4,update='BB98 / 8E1C',cadence='phase every 4 game frames'),
 dict(name='conveyor_right',table=0xc5a9,count=4,update='BB98 / 8DCE',cadence='phase every 4 game frames'),
 dict(name='laser_horizontal',table=0xc5ad,count=4,update='BC83 / 8C53',cadence='phase every 5 game frames while enabled; off tile 17'),
 dict(name='laser_vertical',table=0xc5b1,count=8,update='BC46 / 8D71,8D90',cadence='phase every 2 game frames while enabled; off tile 17'),
 dict(name='torch_left',table=0xc5bd,count=4,update='BB73 / 8DED',cadence='phase every 8 game frames'),
 dict(name='torch_right',table=0xc5b9,count=4,update='BB73 / 8DED',cadence='phase every 8 game frames'),
]
ITEMS=[('key_white',5,0xd28b),('key_blue',6,0xd28f),('key_red',7,0xd293),('amulet',9,0xd297),('torch',12,0xd29b),('sword',10,0xd29f),('jewel',11,0xd2a3)]
POSES=[('34/98','idle right',0,0,1),('40/A4','idle left',0,0,2),('40/A8','walk left phase 3',1,3,2),('4C/B0','jump right',3,0,1),('50/B4','jump left',3,0,2),('54/B8','chain phase 0',5,0,1),('58/BC','chain phase 1',6,0,1),('5C/C0','ladder phase 0',4,0,1),('60/C4','ladder phase 1',4,1,1),('64/C8','fall / treasure descent',3,0,1),('6C/A0','walk right phase 1',1,1,1),('7C/AC','walk left phase 1',1,1,2),('34/9C','walk right phase 3',1,3,1),('D8/D4','death phase 0',8,1,1),('E0/DC','death phase 1',8,3,1)]


def dump(path,value):
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')


def colors(pic):
    return sorted({tuple(p[:3]) for p in pic.getdata() if len(p)<4 or p[3]})


def pair_stats(pic):
    # Compare indices/RGBA, including transparent pixels; ignore completely blank rows.
    good=total=0
    p=pic.load()
    for y in range(pic.height):
        for x in range(0,pic.width-1,2):
            a,b=p[x,y],p[x+1,y]
            if isinstance(a,tuple) and len(a)==4 and not(a[3] or b[3]):continue
            if isinstance(a,int) and a==b==0:continue
            total+=1;good+=a==b
    return dict(equal=good,tested=total,ratio=good/total if total else None)


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('rom',type=Path);ap.add_argument('output',type=Path);args=ap.parse_args()
    r=ROM(args.rom.read_bytes());out=args.output;out.mkdir(parents=True,exist_ok=True)
    for d in ('chr','sprites','rooms','tiles','mockups','data'):(out/d).mkdir(exist_ok=True)
    sha=hashlib.sha256(r.data).hexdigest()
    metadata=dict(sha256=sha,bytes=len(r.data),header=r.data[:16].hex(),mapper=0,nes2=True,prg_file_offset=16,prg_bytes=32768,chr_file_offset=32784,chr_bytes=8192,mirroring='vertical',cpu_address_to_file_offset='address - 0x8000 + 16',rgb_source='FCEUX src/palettes/palettes.h, default P64 palette, frozen 2026-10-27',rgb_source_url='https://github.com/TASEmulators/fceux/blob/master/src/palettes/palettes.h',rgb=RGB)
    dump(out/'data/rom.json',metadata)
    tiles=[]
    for t,pix in enumerate(r.tiles):
        im=Image.new('L',(8,8));im.putdata([v for row in pix for v in row])
        tiles.append(dict(index=t,bank=t//256,bank_index=t%256,ppu_address=hx(t*16),file_offset=32784+t*16,pixels=pix,horizontal_pairs=pair_stats(im)))
    dump(out/'data/tiles.json',tiles)
    gray=[(0,0,0),(85,85,85),(170,170,170),(255,255,255)]
    sheet([(f'{t:03X}',r.tile(t,gray)) for t in range(512)],out/'chr/gray.png',16,(40,48),4)

    print('Decoding 99 rooms with original 6502 routines...',flush=True)
    rooms={};cpus={};room_pals=[]
    for index in range(99):
        floor=math.isqrt(index+1);row=floor-1;col=index-row*(row+2)+8-row
        c=r.room(index,floor);cpus[index]=c;p=list(c.ppu[0x3f00:0x3f20])
        # Read via the PPU address map to include palette aliases.
        p=[c.ppu[c.pa(0x3f00+i)] for i in range(32)]
        rooms[str(index)]=dict(index=index,msx_row=row,msx_column=col,nes_floor=floor,room_pointer=hx(r.w(0xc601+2*index)),attribute_pointer=hx(r.w(0xc6c9+2*index)),object_pointer=hx(r.w(0xc791+2*index)),nametable=list(c.ppu[0x20c0:0x23c0]),attributes=list(c.ppu[0x23c0:0x2400]),palette=p,ram_animation_counts=list(c.mem[0x1c6:0x1d2]))
        r.background(c.ppu).save(out/f'rooms/room_{index:02d}.png')
        room_pals.append((f'{index:02d} ({row},{col})',r.background(c.ppu).crop((0,48,256,240))))
    # The 100th pointer entry exists but is outside the normal 99-room pyramid.
    dump(out/'data/rooms.json',dict(format='32x24 playfield at PPU $20C0; complete attribute table at $23C0',room_table=hx(0xc601),attribute_table=hx(0xc6c9),object_table=hx(0xc791),extra_slot_99=dict(room=hx(r.w(0xc601+198)),attributes=hx(r.w(0xc6c9+198)),objects=hx(r.w(0xc791+198))),rooms=rooms))
    atlas=Image.new('RGB',(19*130,9*98),'#20242c')
    for o in rooms.values():
        im=r.background(cpus[o['index']].ppu).crop((0,48,256,240)).resize((128,96),Image.Resampling.NEAREST)
        atlas.paste(im,((o['msx_column'])*130,o['msx_row']*98))
    atlas.save(out/'rooms/pyramid.png')
    canonical=rooms['2']['palette']
    for kind,offset in (('background',0),('sprite',16)):
        for pi in range(4):
            pal=[RGB[canonical[offset+4*pi+j]&63] for j in range(4)]
            sheet([(f'{t:03X}',r.tile(t,pal)) for t in range(512)],out/f'chr/{kind}_{pi}.png',16,(40,48),4)
    palette_tables={hx(a):[r.b(a+i) for i in range(4)] for a in list(range(0xd45f,0xd487,4))+[0xc863,0xc867]}
    variants=[]
    for index,c in cpus.items():
        saved=bytes(c.mem)
        for level in range(9):
            for torch in (False,True):
                c.mem[:]=saved;c.mem[0x799]=level;c.mem[0x7c0]=max(1,9-level);c.mem[0xd3]=12 if torch else 0
                c.call(0xac9a);c.call(0xaceb);c.call(0xac54)
                pal=[c.ppu[c.pa(0x3f00+i)] for i in range(32)]
                variants.append(dict(room=index,floor=rooms[str(index)]['nes_floor'],level_internal=level,torch=torch,palette=pal))
        c.mem[:]=saved
        # Restore canonical PPU as the loop above modifies it.
        c.ppu[0x3f00:0x3f20]=bytes(rooms[str(index)]['palette'])
    floor_accents=[r.b(0xc5d5+(floor%9)) for floor in range(1,10)]
    dump(out/'data/palettes.json',dict(rgb=RGB,tables=palette_tables,accent_table=hx(0xc5d5),accent_formula='(NES floor + internal level) % 9',floor_accents_level0=floor_accents,variants=variants))
    palim=Image.new('RGB',(16*40,10*32),'#20242c');d=ImageDraw.Draw(palim)
    for i,c in enumerate(RGB):
        x=i%16*40;y=i//16*32;d.rectangle((x,y,x+39,y+31),fill=c);d.text((x+2,y+2),f'{i:02X}',fill='black' if sum(c)>420 else 'white')
    for pi in range(8):
        for j in range(4):
            x=(pi%4)*160+j*40;y=144+(pi//4)*64
            d.rectangle((x,y,x+39,y+39),fill=RGB[canonical[pi*4+j]&63]);d.text((x+2,y+40),f'{canonical[pi*4+j]:02X}',fill='white')
    palim.save(out/'palettes.png')
    floorim=Image.new('RGB',(640,9*48),'#20242c');d=ImageDraw.Draw(floorim)
    for floor in range(1,10):
        sample=next(v for v in variants if v['floor']==floor and v['level_internal']==0 and not v['torch'])
        d.text((3,(floor-1)*48+4),f'F{floor} / L1',fill='white')
        for j,n in enumerate(sample['palette'][:16]):
            x=88+j*34;y=(floor-1)*48;d.rectangle((x,y,x+33,y+27),fill=RGB[n]);d.text((x,y+28),f'{n:02X}',fill='white')
    floorim.save(out/'floors.png')

    groups={};sprite_pictures={};summary=[]
    for group,(table,count) in GROUPS.items():
        entries=[];states=[]
        for state in range(count):
            a=r.w(table+2*state);n=r.b(a);header=[r.b(a+i) for i in range(6)];frames=[]
            for f in range(n):
                ptr=r.w(a+6+f*2);views={}
                for direction in (1,2):
                    parts=r.meta(ptr,direction);pic,box=r.render_meta(parts,canonical)
                    ident=f'{group}_{state:02x}_{f:02d}_{"right" if direction==1 else "left"}'
                    pic.save(out/f'sprites/{ident}.png');sprite_pictures[ident]=pic
                    bbox=pic.getbbox();views[str(direction)]=dict(image=f'sprites/{ident}.png',parts=parts,cell_bounds=box,cell_size=list(pic.size),ink_bounds=list(bbox) if bbox else None,ink_size=[bbox[2]-bbox[0],bbox[3]-bbox[1]] if bbox else [0,0],rgb_colors=colors(pic),horizontal_pairs=pair_stats(pic))
                    entries.append((f'{state:02X}:{f} {"R" if direction==1 else "L"}\n{JOE_NAMES[state] if group=="joe" else group}\n{pic.width}x{pic.height} / ink {views[str(direction)]["ink_size"]}',pic))
                frames.append(dict(index=f,rom=hx(ptr),views=views))
            obj=dict(index=state,name=JOE_NAMES[state] if group=='joe' else group,rom=hx(a),frame_count=n,frame_ticks=header[1],collision_bytes=header[2:6],frames=frames);states.append(obj)
            summary.append(dict(group=group,state=state,name=obj['name'],frames=n,ticks=header[1],sizes=[v['views']['1']['ink_size'] for v in frames]))
        groups[group]=dict(pointer_table=hx(table),states=states)
        sheet(entries,out/f'sprites/{group}_sheet.png',8,(112,148),3)
    dump(out/'data/metasprites.json',dict(pattern_bank=0,oam_record='dy,tile,attributes,dx; FF terminator',mirror='direction != 1: dx = 8-dx; attributes XOR 40',groups=groups))
    dump(out/'data/sprite_summary.json',summary)

    animations=[];anim_entries=[]
    for a in ANIMATIONS:
        a=dict(a);a['tiles']=[r.b(a['table']+i) for i in range(a.pop('count'))];a['table']=hx(a['table']);animations.append(a)
        for i,t in enumerate(a['tiles']):anim_entries.append((f'{a["name"]}\n{i}: {t:02X}',r.tile(t+256,[RGB[n] for n in canonical[:4]])))
    sheet(anim_entries,out/'tiles/animations.png',8,(112,76),4)
    dump(out/'data/animations.json',animations)
    item_entries=[];items=[]
    for name,kind,a in ITEMS:
        ts=[r.b(a+i) for i in range(4)];occurrences=[]
        for idx,c in cpus.items():
            for pos in range(0xc0,0x3a0):
                if pos%32==31:continue
                if [c.ppu[0x2000+pos+k] for k in (0,1,32,33)]==ts:
                    x=(pos%32)*8;y=(pos//32)*8;occurrences.append(dict(room=idx,x=x,y=y))
        if occurrences:
            o=occurrences[0];pic=r.background(cpus[o['room']].ppu).crop((o['x'],o['y'],o['x']+16,o['y']+16))
        else:
            pic=Image.new('RGB',(16,16))
            for j,t in enumerate(ts):pic.paste(r.tile(256+t,[RGB[v] for v in canonical[:4]]),(j%2*8,j//2*8))
        pic.save(out/f'tiles/{name}.png');item_entries.append((f'{name}\n{a:04X}',pic))
        items.append(dict(name=name,object_type=kind,rom=hx(a),width=16,height=16,tiles=[dict(tile=t+256,x=j%2*8,y=j//2*8) for j,t in enumerate(ts)],occurrences=occurrences))
    sheet(item_entries,out/'tiles/items.png',7,(112,104),4)
    dump(out/'data/items.json',items)
    # Complete background catalogue with actual observed palette contexts.
    usage=defaultdict(list)
    for idx,c in cpus.items():
        for pos in range(0xc0,0x3c0):
            tx=pos%32;ty=pos//32;at=c.ppu[0x23c0+ty//4*8+tx//4];pi=(at>>((ty%4//2)*4+(tx%4//2)*2))&3
            key=(c.ppu[0x2000+pos]+256,tuple(c.ppu[0x3f00+4*pi:0x3f04+4*pi]))
            if idx not in usage[key]:usage[key].append(idx)
    records=[];entries=[]
    for (t,pal),indices in sorted(usage.items()):
        records.append(dict(tile=t,palette=list(pal),rooms=indices));entries.append((f'{t:03X} '+','.join(f'{p:02X}' for p in pal),r.tile(t,[RGB[v] for v in pal])))
    sheet(entries,out/'tiles/observed.png',8,(112,60),4)
    dump(out/'data/background_usage.json',records)

    from catalog import export_catalog
    export_catalog(r,out,canonical,cpus)

    mapping=dict(joe=[dict(msx_layers=p,meaning=name,nes_state=s,nes_frame=f,direction=di,status='proposed semantic correspondence; not pixel identity') for p,name,s,f,di in POSES],enemies=[dict(msx=f'{n:02X}',nes_group='skull',nes_frame=(i*12)//8,status='proposed phase correspondence (8 MSX vs 12 NES)') for i,n in enumerate(range(12,44,4))]+[dict(msx='2C/30',nes_group='spider',nes_frames=list(range(8))),dict(msx='68',nes_group='joe',nes_state=8,note='MSX death/respawn frame; ps_names includes it but it is not an ordinary enemy'),dict(msx='78',nes_group='joe',nes_state=2,note='MSX falling-death single white sprite, src/model/hero.js 8B6E')],items=[dict(msx=f'{k:02X}',nes=n) for k,n in [(0x20,'jewel'),(0x21,'torch'),(0x22,'sword'),(0x23,'amulet'),(0x24,'key_blue'),(0x25,'key_red'),(0x26,'key_white'),(0x27,'snake left'),(0x28,'snake right')]],extra_nes=['bat'],geometry='NES 32x24 playfield below 6 HUD rows; MSX 32x19 below 5 HUD rows. Room IDs and topology correspond; raster layout needs adaptation.')
    from msx import add_semantic_contexts
    add_semantic_contexts(mapping)
    dump(out/'data/mapping.json',mapping)
    # All four rendering choices, native-size and 19-row, two and three colours.
    comparisons=[]
    for state in range(12):
        for frame in groups['joe']['states'][state]['frames']:
            src=sprite_pictures[f'joe_{state:02x}_{frame["index"]:02d}_right'];bbox=src.getbbox()
            if not bbox:continue
            src=src.crop(bbox)
            for nc in (2,3):
                pic=src.copy()
                if nc==2:
                    pic.putdata([(*RGB[0x27],p[3]) if p[3] and p[:3]==RGB[0x26] else p for p in pic.getdata()])
                for height in (src.height,19):
                    q=pic if height==src.height else pic.resize((pic.width,19),Image.Resampling.NEAREST)
                    comparisons.append((f'{state:02X}:{frame["index"]} {nc}col\n{q.width}x{q.height}',q))
    sheet(comparisons,out/'mockups/joe_choices.png',8,(112,144),3)
    from msx import make_msx_deliverables
    optional=make_msx_deliverables(r,out,groups,canonical,sprite_pictures,mapping)
    dump(out/'data/manifest.json',dict(rom_sha256=sha,tiles=512,rooms=99,metasprite_states=sum(len(g['states']) for g in groups.values()),frame_references=sum(s['frame_count'] for g in groups.values() for s in g['states']),sprite_pngs=len(sprite_pictures),palette_cases=len(variants),msx_comparison=optional,files=[str(p.relative_to(out)) for p in sorted(out.rglob('*.png')) if 'reference' not in p.parts]))
    print(f'Extracted 512 tiles, 99 rooms, {len(sprite_pictures)} sprite views, {len(variants)} palette cases into {out}',flush=True)

if __name__=='__main__':main()
