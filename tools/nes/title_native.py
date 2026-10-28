#!/usr/bin/env python3
"""NES logo and CHR credits over the full-size first room."""
from pathlib import Path
import json
from PIL import Image, ImageDraw
from assets import ROM, RGB
from catalog import decode_rle
from msx import encode, decode

ROOT=Path(__file__).resolve().parents[2]

def main():
    r=ROM((ROOT/'orig/nes/monty.nes').read_bytes())
    nt,_=decode_rle(r,0xd9e9);at,_=decode_rle(r,0xdb12)
    assert len(nt)==960 and len(at)==64
    colors=[0x0f,0x27,0x06,0x17,0x1c,0x16,0x10,0x20]
    palettes=[[r.b(a+i) for i in range(4)] for a in (0xd46b,0xd47f,0xd483)]+[[0x0f]*4]
    # Start with the actual first NES room, including its full 256x240 field.
    # All five room colours occur in the original title palette.
    room=r.background(r.room(2,1).ppu).convert('RGB')
    rgb_index={RGB[v]:i for i,v in enumerate(colors)}
    pixel=Image.new('L',(256,240));p=pixel.load()
    for y in range(240):
        for x in range(256):
            p[x,y]=rgb_index[room.getpixel((x,y))]
    # Keep the original NES logo unscaled. It fits in the room's empty HUD.
    for y in range(40,70):
        for x in range(256):
            tx,ty=x//8,y//8
            pi=(at[(ty//4)*8+tx//4]>>((ty%4//2)*4+(tx%4//2)*2))&3
            v=r.tiles[256+nt[ty*32+tx]][y%8][x%8]
            if v:p[x,y-36]=colors.index(palettes[pi][v])
    # A framed black panel keeps credits and selector legible over the room.
    draw=ImageDraw.Draw(pixel)
    draw.rectangle((23,78,244,163),fill=0,outline=4,width=1)
    draw.line((32,135,235,135),fill=3,width=1)
    alphabet={chr(ord('A')+i):0x6c+i for i in range(26)}
    alphabet.update({str(i):0x62+i for i in range(10)})
    alphabet['©']=0x87
    credits=['© PARKER BROTHERS 1984','VECTOR 06C VERSION BY','BORIS LIKHACHEV']
    for y,line in zip((88,103,118),credits):
        x0=(256-8*len(line))//2
        for i,ch in enumerate(line):
            if ch==' ':continue
            tile=r.tiles[256+alphabet[ch]]
            for yy in range(8):
                for xx in range(8):
                    if tile[yy][xx]:p[x0+i*8+xx,y+yy]=6
    asm=['; First NES room, original NES logo, and custom CHR credits.']
    for bit,base in ((4,0x8000),(2,0xa000),(1,0xc000)):
        for c in range(32):
            data=[sum(128>>x for x in range(8) if p[c*8+x,y]&bit) for y in range(240)]
            asm.append(' ORG 0x%04X+SCREEN_TOP-239'%(base+256*c))
            for start in (0,120):asm.append(' db '+','.join(map(str,data[::-1][start:start+120])))
    # Palette bytes live in the source image and are copied before title display.
    asm+=[' ORG 0xF900','title_palette: db '+','.join(str(encode(RGB[v])) for v in colors for _ in range(2))]
    (ROOT/'src/native/gen/title.asm').write_text('\n'.join(asm)+'\n')
    # The selector is an added menu line; draw it with the exact 7x7 glyphs
    # used by the NES credits above. Comma extends the NES period by one row.
    glyphs=[('S',0x7e),('E',0x70),('L',0x77),('C',0x6e),('T',0x7f),('V',0x81),
            ('1',0x63),('2',0x64),('3',0x65),('.',0x86)]
    def rows(tile):
        return [sum(128>>x for x,v in enumerate(row) if v) for row in r.tiles[256+tile]]
    font=['; NES title-credit CHR glyphs for the level selector.',
          f'NES_TITLE_CREDITS_INK equ {encode(RGB[palettes[2][2]])}','font_tab:']
    for char,tile in glyphs:
        font.append(' db "'+char+'",'+','.join(map(str,rows(tile))))
    comma=rows(0x86);comma[7]=0x80
    font.append(' db ",",'+','.join(map(str,comma)))
    font.append(' db 0,0,0,0,0,0,0,0,0')
    (ROOT/'src/native/gen/font_nes.asm').write_text('\n'.join(font)+'\n')
    out=ROOT/'build/nes_title';out.mkdir(parents=True,exist_ok=True)
    rgb=Image.new('RGB',pixel.size);rgb.putdata([decode(encode(RGB[colors[v]])) for v in pixel.getdata()]);rgb.save(out/'native.png')
    (out/'native.idx').write_bytes(pixel.tobytes())
    # Independent MAME snapshot confirms both source streams, including HUD-free
    # attribute quadrants. Optional so clean builds need only the local ROM.
    ref=out/'title_90.ppu'
    if ref.exists():
        ppu=ref.read_bytes();assert nt[:512]==ppu[0x2000:0x2200] and at[:32]==ppu[0x23c0:0x23e0]
    (out/'title.json').write_text(json.dumps(dict(name_rle='D9E9',attribute_rle='DB12',mame_verified=ref.exists(),scaled=False,palette=colors,room=2,credits=credits),indent=2)+'\n')

if __name__=='__main__':main()
