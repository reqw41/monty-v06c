"""ROM formats and pixel rendering. No game graphics embedded in source."""
from PIL import Image, ImageDraw
from cpu import CPU

# FCEUX src/palettes/palettes.h default (P64 expansion of 6-bit components).
# Frozen 2026-10-27. https://github.com/TASEmulators/fceux/blob/master/src/palettes/palettes.h
RGB6='''1d1d1d 090623 00002a 110027 23001d 2a0004 290000 1f0200 100b00 001100 001400 000f05 060f17 000000 000000 000000
2f2f2f 001c3b 080e3b 20003c 2f002f 390016 360a00 321303 221c00 002500 002a00 00240e 002022 000000 000000 000000
3f3f3f 0f2f3f 17253f 33223f 3d1e3f 3f1d2d 3f1d18 3f260e 3c2f0f 203404 133712 163e26 003a36 1e1e1e 000000 000000
3f3f3f 2a393f 31353f 35323f 3f313f 3f3136 3f2f2c 3f362a 3f3928 383f28 2a3c2f 2c3f33 273f3c 313131 000000 000000'''
RGB=[tuple((v<<2)|(v>>4) for v in bytes.fromhex(t)) for t in RGB6.split()]
JOE_NAMES=['idle','walk','death_tumble','jump_fall','ladder','rope_a','rope_b','ladder_top','death_disappear','invisible','rope_c','death_burst']
GROUPS={'joe':(0xd738,12),'snake':(0xd77c,1),'skull':(0xd868,1),'spider':(0xd908,1),'bat':(0xd990,1)}

def hx(n):return f'${n:04X}'
def signed(n):return n if n<128 else n-256

class ROM:
    def __init__(self,data):
        if len(data)!=40976 or data[:4]!=b'NES\x1a' or data[4:6]!=bytes([2,1]) or data[6]!=1 or data[7]!=8 or data[8]&15:
            raise ValueError('Expected untrained NROM 32K PRG / 8K CHR ROM')
        self.data=data;self.prg=data[16:32784];self.chr=data[32784:]
        self.tiles=[[[((self.chr[t*16+y]>>(7-x))&1)|(((self.chr[t*16+y+8]>>(7-x))&1)<<1) for x in range(8)] for y in range(8)] for t in range(512)]
    def b(self,a):return self.prg[a-0x8000]
    def w(self,a):return self.b(a)|(self.b(a+1)<<8)
    def tile(self,t,pal,transparent=False,attr=0):
        im=Image.new('RGBA',(8,8));p=im.load()
        for y in range(8):
            for x in range(8):
                v=self.tiles[t][7-y if attr&128 else y][7-x if attr&64 else x]
                p[x,y]=(*pal[v],0 if transparent and v==0 else 255)
        return im
    def meta(self,a,direction=1):
        result=[];p=a
        while self.b(p)!=255:
            if p-a>128:raise ValueError(f'Bad metasprite {a:04X}')
            y,t,at,x=[self.b(p+i) for i in range(4)]
            if direction!=1:x=(8-x)&255;at^=64
            result.append(dict(tile=t,x=signed(x),y=signed(y),attribute=at,palette=at&3,flip_x=bool(at&64),flip_y=bool(at&128),behind_background=bool(at&32)))
            p+=4
        return result
    def render_meta(self,parts,palette):
        x0=min(p['x'] for p in parts);y0=min(p['y'] for p in parts)
        x1=max(p['x']+8 for p in parts);y1=max(p['y']+8 for p in parts)
        im=Image.new('RGBA',(x1-x0,y1-y0))
        # OAM priority: first sprite wins, so composite in reverse order.
        for p in parts[::-1]:
            pal=[RGB[palette[16+4*p['palette']+j]&63] for j in range(4)]
            im.alpha_composite(self.tile(p['tile'],pal,True,p['attribute']),(p['x']-x0,p['y']-y0))
        return im,[x0,y0,x1,y1]
    def room(self,index,floor,level=0,torch=False):
        c=CPU(self.prg);m=c.mem
        c.ppu[0x2000:0x20c0]=bytes([0x17])*0xc0
        m[0x792]=1;m[0x794]=1;m[0x796]=0x35;m[0x1d2]=0x2d
        m[0x799]=level;m[0x79a]=floor;m[0x79b]=index;m[0x7c9]=1;m[0x7fd]=255;m[0x7c0]=max(1,9-level)
        if torch:m[0xd3]=12  # inventory type; lookup $81E6 scans $D3..D7
        for p in (0xc461,0xbd5c,0xbaff):c.call(p)
        m[5:7]=m[0x79c:0x79e];m[0xf3]=0
        for p in (0xbd6a,0xbe5e,0xbe8c,0x92b1,0xac9a,0xaceb,0xac54):c.call(p)
        return c
    def background(self,ppu):
        im=Image.new('RGB',(256,240));p=im.load()
        for y in range(240):
            for x in range(256):
                tx=x//8;ty=y//8;t=ppu[0x2000+ty*32+tx]+256
                at=ppu[0x23c0+(ty//4)*8+tx//4];pi=(at>>((ty%4//2)*4+(tx%4//2)*2))&3
                v=self.tiles[t][y%8][x%8];p[x,y]=RGB[ppu[0x3f00+(pi*4+v if v else 0)]&63]
        return im

def sheet(entries,path,columns=8,cell=(96,120),scale=3):
    im=Image.new('RGB',(columns*cell[0],((len(entries)+columns-1)//columns)*cell[1]),'#20242c');d=ImageDraw.Draw(im)
    for i,(label,pic) in enumerate(entries):
        x=i%columns*cell[0];y=i//columns*cell[1]
        for j,line in enumerate(label.split('\n')):d.text((x+3,y+2+11*j),line,fill='white')
        p=pic.convert('RGBA');p=p.resize((p.width*scale,p.height*scale),Image.Resampling.NEAREST)
        im.paste(p,(x+3,y+cell[1]-p.height-3),p)
    im.save(path)
