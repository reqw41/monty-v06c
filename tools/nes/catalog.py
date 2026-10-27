"""Direct RLE streams, named background groups, and closed/open doors."""
import json
from PIL import Image
from assets import RGB,hx,sheet


def decode_rle(rom,address):
    """$B79E: alternating literal and repeat packets, FF ends either state."""
    p=address;literal=True;data=[]
    while p<0xfffa:
        n=rom.b(p);p+=1
        if n==255:return bytes(data),p
        if literal:
            data.extend(rom.b(p+i) for i in range(n));p+=n
        else:
            v=rom.b(p);p+=1;data.extend([v]*(n or 256))
        literal=not literal
        if len(data)>1024:raise ValueError(f'RLE overflow at {address:04X}')
    raise ValueError(f'Unterminated RLE {address:04X}')


def export_catalog(r,out,canonical,cpus):
    streams={}
    for name,table,size in [('room',0xc601,768),('attribute',0xc6c9,64)]:
        for i in range(99):
            p=r.w(table+2*i)
            data,end=decode_rle(r,p)
            assert len(data)==size,(name,i,len(data))
            streams[hx(p)]=dict(kind=name,rom=hx(p),file_offset=p-0x8000+16,encoded_hex=r.prg[p-0x8000:end-0x8000].hex(),decoded=list(data))
    (out/'data/rle_streams.json').write_text(json.dumps(streams,indent=2)+'\n')
    groups=dict(brick_wall_floor=[0,1,2,3],rope_chain=[0x0c,0x0d],ladder=[0x0f,0x10,0x11,0x12,0x13,0x14],platform=[0x15,0x16],empty=[0x17],fire_lower=list(range(0x18,0x1c)),fire_upper=list(range(0x1c,0x20)),torch_top=list(range(0x23,0x2b)),laser_vertical=list(range(0x2d,0x35)),laser_horizontal=list(range(0x35,0x39)),door_closed=[0x39,0x3a,0x3b],conveyor=list(range(0x3c,0x48)),door_open=list(range(0x56,0x62)))
    entries=[]
    for name,ts in groups.items():
        for t in ts:entries.append((f'{name}\n{t:02X} / CHR {256+t:03X}',r.tile(256+t,[RGB[v] for v in canonical[:4]])))
    sheet(entries,out/'tiles/terrain.png',8,(120,76),4)
    (out/'data/terrain.json').write_text(json.dumps(dict(bank=1,groups=groups,palette_note='terrain.png uses background palette 0; actual palette contexts are in background_usage.json'),indent=2)+'\n')
    doors=[];entries=[]
    for i,name in enumerate(('white','blue','red')):
        t=0x39+i;pi=0;idx=2
        for room,c in cpus.items():
            found=False
            for pos in range(0xc0,0x360):
                if all(c.ppu[0x2000+pos+32*j]==t for j in range(4)):
                    tx=pos%32;ty=pos//32;at=c.ppu[0x23c0+ty//4*8+tx//4];pi=(at>>((ty%4//2)*4+(tx%4//2)*2))&3;idx=room;found=True;break
            if found:break
        c=cpus[idx];pal=[RGB[c.ppu[0x3f00+pi*4+j]] for j in range(4)]
        a=0xc5c9+i*4;top=[r.b(a+j) for j in range(3)];body=r.b(a+3)
        for label,grid in [('closed',[[t]]*4),('open',[top]+[[body]*3]*3)]:
            im=Image.new('RGBA',(len(grid[0])*8,32))
            for y,row in enumerate(grid):
                for x,n in enumerate(row):im.paste(r.tile(256+n,pal),(x*8,y*8))
            im.save(out/f'tiles/door_{name}_{label}.png');entries.append((f'{name} {label}',im))
            doors.append(dict(name=name,state=label,tiles=grid,size=list(im.size),pattern_bank=1,palette_sample_room=idx,palette_index=pi,open_table=hx(a)))
    sheet(entries,out/'tiles/doors.png',6,(112,152),3)
    (out/'data/doors.json').write_text(json.dumps(doors,indent=2)+'\n')
