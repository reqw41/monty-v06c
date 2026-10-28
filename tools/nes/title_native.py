#!/usr/bin/env python3
"""Original NES logo with requested Vector-06C credits in NES CHR."""
from pathlib import Path
import json
from PIL import Image
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
    pixel=Image.new('L',(256,192));p=pixel.load()
    # Keep the original logo. The level selector occupies the empty lower part.
    for y in range(128):
        for x in range(256):
            tx,ty=x//8,y//8
            pi=(at[(ty//4)*8+tx//4]>>((ty%4//2)*4+(tx%4//2)*2))&3
            v=r.tiles[256+nt[ty*32+tx]][y%8][x%8]
            p[x,y]=colors.index(palettes[pi][v] if v else 0x0f)
    # Replace only the original credits; leave the black title layout intact.
    for y in range(92,128):
        for x in range(256):p[x,y]=0
    alphabet={chr(ord('A')+i):0x6c+i for i in range(26)}
    alphabet.update({str(i):0x62+i for i in range(10)})
    brackets={'(':[0x18,0x30,0x60,0x60,0x60,0x30,0x18,0],
              ')':[0x30,0x18,0x0c,0x0c,0x0c,0x18,0x30,0]}
    credits=['(C) PARKER BROTHER 1984','VECTOR 06C VERSION BY','BORIS LIKHACHEV']
    for y,line in zip((96,107,118),credits):
        x0=(256-8*len(line))//2
        for i,ch in enumerate(line):
            if ch==' ':continue
            rows=brackets[ch] if ch in brackets else [sum(128>>x for x,v in enumerate(row) if v) for row in r.tiles[256+alphabet[ch]]]
            for yy,bits in enumerate(rows):
                for xx in range(8):
                    if bits&(128>>xx):p[x0+i*8+xx,y+yy]=6
    asm=['; Original NES title, RLE $D9E9/$DB12 and CHR bank 1.']
    for bit,base in ((4,0x8000),(2,0xa000),(1,0xc000)):
        for c in range(32):
            data=[sum(128>>x for x in range(8) if p[c*8+x,y]&bit) for y in range(128)]
            if any(data):
                asm+=[' ORG 0x%04X+SCREEN_TOP-127'%(base+256*c),' db '+','.join(map(str,data[::-1]))]
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
    # Independent MAME snapshot confirms both source streams, including HUD-free
    # attribute quadrants. Optional so clean builds need only the local ROM.
    ref=out/'title_90.ppu'
    if ref.exists():
        ppu=ref.read_bytes();assert nt[:512]==ppu[0x2000:0x2200] and at[:32]==ppu[0x23c0:0x23e0]
    (out/'title.json').write_text(json.dumps(dict(name_rle='D9E9',attribute_rle='DB12',mame_verified=ref.exists(),scaled=False,palette=colors,credits=credits),indent=2)+'\n')

if __name__=='__main__':main()
