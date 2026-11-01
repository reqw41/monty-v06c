#!/usr/bin/env python3
"""Original NES logo with requested Vector-06C credits in NES CHR."""
from pathlib import Path
import json
import subprocess
from PIL import Image
from assets import ROM, RGB
from catalog import decode_rle
from msx import encode, decode

ROOT=Path(__file__).resolve().parents[2]

def main():
    r=ROM((ROOT/'orig/nes/monty.nes').read_bytes())
    nt,_=decode_rle(r,0xd9e9);at,_=decode_rle(r,0xdb12)
    assert len(nt)==960 and len(at)==64
    # Match gameplay's Joe inks: white=1, clothes=2, skin=3. Reindex the
    # entire title, preserving every visible NES colour.
    colors=[0x0f,0x20,0x06,0x27,0x10,0x1c,0x17,0x16]
    palettes=[[r.b(a+i) for i in range(4)] for a in (0xd46b,0xd47f,0xd483)]+[[0x0f]*4]
    credit_ink=colors.index(palettes[2][2])
    pixel=Image.new('L',(256,240));p=pixel.load()
    # Keep the NES logo and lower tile scene, with room for our level selector.
    for y in list(range(128))+list(range(160,240)):
        for x in range(256):
            tx,ty=x//8,y//8
            pi=(at[(ty//4)*8+tx//4]>>((ty%4//2)*4+(tx%4//2)*2))&3
            v=r.tiles[256+nt[ty*32+tx]][y%8][x%8]
            p[x,y]=colors.index(palettes[pi][v] if v else 0x0f)
    # Keep the original 16-pixel shaft: a natural-width Joe must fit beside
    # the rope. Centre the eight-pixel rope artwork inside that opening.
    for ty in range(23,30):
        for yy in range(8):
            for xx in range(16):p[15*8+xx,ty*8+yy]=0
            for xx in range(8):
                p[15*8+4+xx,ty*8+yy]=1 if r.tiles[0x10c if ty==23 else 0x10d][yy][xx] else 0
    # Replace only the original credits; leave the black title layout intact.
    for y in range(90,128):
        for x in range(256):p[x,y]=0
    alphabet={chr(ord('A')+i):0x6c+i for i in range(26)}
    alphabet.update({str(i):0x62+i for i in range(10)})
    credits=['© UTOPIA SOFTWARE 1984','VECTOR 06C VERSION BY','BORIS LIKHACHEV 2026']
    # A 9x9 ring and a clean 3x5 C, aligned with the 7-row NES letters.
    mark_x=(256-(12+8*len('UTOPIA SOFTWARE 1984')))//2
    mark_y=95
    mark_rows=('..#####..','.#.....#.','#..###..#','#..#....#',
               '#..#....#','#..#....#','#..###..#','.#.....#.','..#####..')
    for yy,row in enumerate(mark_rows):
        for xx,value in enumerate(row):
            if value=='#':p[mark_x+xx,mark_y+yy]=credit_ink
    for y,line in ((96,'UTOPIA SOFTWARE 1984'),(107,credits[1]),(118,credits[2])):
        x0=mark_x+12 if y==96 else (256-8*len(line))//2
        for i,ch in enumerate(line):
            if ch==' ':continue
            rows=[sum(128>>x for x,v in enumerate(row) if v) for row in r.tiles[256+alphabet[ch]]]
            for yy,bits in enumerate(rows):
                for xx in range(8):
                    if bits&(128>>xx):p[x0+i*8+xx,y+yy]=credit_ink
    # Immutable roof positions: reading VRAM here would also see the Joe pose
    # that remains visible while the next image is prepared.
    roof=[255-next(y for y in range(160,240) if any(p[x,y] for x in range(c*8,min((c+width)*8,256))))+22
          for c in range(23,32) for width in (2,3)]
    (ROOT/'src/native/gen/title_roof.asm').write_text('; Static roof top L, columns 23..31: aligned / shifted 16-pixel Joe.\n'
                                                  'title_roof_rows: db '+','.join(map(str,roof))+'\n')
    asm=['; Original NES title, RLE $D9E9/$DB12 and CHR bank 1.']
    screen=bytearray(0x6000)
    for bit,base in ((4,0x8000),(2,0xa000),(1,0xc000)):
        for c in range(32):
            data=[sum(128>>x for x in range(8) if p[c*8+x,y]&bit) for y in range(240)]
            for y,value in enumerate(data):
                screen[base-0x8000+256*c+255-y]=value
            if any(data):
                asm+=[' ORG 0x%04X+SCREEN_TOP-239'%(base+256*c)]
                reverse=data[::-1]
                for i in range(0,len(reverse),24):asm+=[' db '+','.join(map(str,reverse[i:i+24]))]
    # Palette bytes live in the source image and are copied before title display.
    asm+=[' ORG 0xF900','title_palette: db '+','.join(str(encode(RGB[v])) for v in colors for _ in range(2))]
    (ROOT/'src/native/gen/title.asm').write_text('\n'.join(asm)+'\n')
    (ROOT/'src/native/gen/title_palette.asm').write_text('; Permanent shared cold/warm NES title palette.\n db '+','.join(str(encode(RGB[v])) for v in colors for _ in range(2))+'\n')
    # The selector is an added menu line; draw it with the exact 7x7 glyphs
    # used by the NES credits above. Comma extends the NES period by one row.
    glyphs=[('S',0x7e),('E',0x70),('L',0x77),('C',0x6e),('T',0x7f),('V',0x81),
            ('1',0x63),('2',0x64),('3',0x65),('.',0x86)]
    def rows(tile):
        return [sum(128>>x for x,v in enumerate(row) if v) for row in r.tiles[256+tile]]
    font=['; NES title-credit CHR glyphs for the level selector.',
          f'NES_TITLE_CREDITS_INK equ {encode(RGB[palettes[2][2]])}',
          f'NES_TITLE_TEXT_SLOT equ {credit_ink}','font_tab:']
    for char,tile in glyphs:
        font.append(' db "'+char+'",'+','.join(map(str,rows(tile))))
    comma=rows(0x86);comma[7]=0x80
    font.append(' db ",",'+','.join(map(str,comma)))
    font.append(' db 255 ; continue at font_extra')
    (ROOT/'src/native/gen/font_nes.asm').write_text('\n'.join(font)+'\n')
    extra=['; The five GAME OVER glyphs occupy permanent high RAM.',
           ' ORG 0xFDD0','font_extra:']
    for ch in 'GAMOR':
        extra.append(' db "'+ch+'",'+','.join(map(str,rows(alphabet[ch]))))
    extra.append(' db 0,0,0,0,0,0,0,0,0')
    extra.append(' ASSERT $ == 0xFE06')
    (ROOT/'src/native/gen/font_nes_extra.asm').write_text('\n'.join(extra)+'\n')
    out=ROOT/'build/nes_title';out.mkdir(parents=True,exist_ok=True)
    raw=out/'title_screen.raw';raw.write_bytes(screen)
    zx_src=ROOT/'tools/nes/zx0'
    zx_bin=out/'zx0'
    if not zx_bin.exists() or any(f.stat().st_mtime>zx_bin.stat().st_mtime for f in zx_src.glob('*.[ch]')):
        subprocess.run(['cc','-O2','-o',str(zx_bin),*[str(zx_src/n) for n in ('zx0.c','optimize.c','compress.c','memory.c')]],check=True)
    packed=out/'title_screen.zx0'
    subprocess.run([str(zx_bin),'-f',str(raw),str(packed)],check=True,capture_output=True)
    stream=packed.read_bytes()
    assert len(stream)<1536, f'title ZX0 stream grew to {len(stream)} bytes'
    cache=['; Forward ZX0 v2 title in permanent RAM, outside all screen planes.',
           f'TITLE_ZX0_BYTES equ {len(stream)}','title_packed:']
    for i in range(0,len(stream),24):
        cache.append(' db '+','.join(map(str,stream[i:i+24])))
    cache.append('title_packed_end:')
    (ROOT/'src/native/gen/title_packed.asm').write_text('\n'.join(cache)+'\n')
    rgb=Image.new('RGB',pixel.size);rgb.putdata([decode(encode(RGB[colors[v]])) for v in pixel.getdata()]);rgb.save(out/'native.png')
    (out/'native.idx').write_bytes(pixel.tobytes())
    # Independent MAME snapshot confirms both source streams, including HUD-free
    # attribute quadrants. Optional so clean builds need only the local ROM.
    ref=out/'title_90.ppu'
    if ref.exists():
        ppu=ref.read_bytes();assert nt[:512]==ppu[0x2000:0x2200] and at[:32]==ppu[0x23c0:0x23e0]
    (out/'title.json').write_text(json.dumps(dict(name_rle='D9E9',attribute_rle='DB12',mame_verified=ref.exists(),scaled=False,palette=colors,credits=credits,scene_rows=[20,29],rope_column=15,rope_rows=[23,29]),indent=2)+'\n')

if __name__=='__main__':main()
