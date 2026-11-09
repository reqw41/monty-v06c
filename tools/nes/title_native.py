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
import full_native
# The game's palette (style_pal, start-room accent 103 in slot 7). Title inks
# use the same slots; slot 4 (snake green in the game) holds Revenge's 17h.
GAME_PALETTE=[0,255,4,102,None,173,160,103]
SCENE_ROW0=20   # rows 20..29: a field fragment drawn by the game's tile builder
import os
RUS=os.environ.get('RUS')=='1'   # русская версия: титры и ИГРА ОКОНЧЕНА
# Кириллица в стиле букв NES (7x7, жирная); похожие буквы берутся из CHR NES.
CYR_LATIN={'А':'A','В':'B','Е':'E','К':'K','М':'M','Н':'H','О':'O','Р':'P','С':'C','Т':'T','Х':'X'}
CYR={'Б':['#######','###....','######.','###.###','###.###','###.###','######.'],
     'Г':['#######','#######','###....','###....','###....','###....','###....'],
     'Д':['.#####.','.##.##.','.##.##.','.##.##.','.##.##.','#######','##...##'],
     'И':['###..##','###.###','#######','#######','#######','###.###','##..###'],
     'Л':['..#####','.######','.##.###','.##.###','.##.###','###.###','##..###'],
     'Ц':['###.##.','###.##.','###.##.','###.##.','###.##.','#######','#######','.....##'],
     'Ч':['###.###','###.###','###.###','#######','.######','....###','....###'],
     'Ы':['##...##','##...##','####.##','##.#.##','##.#.##','##.#.##','####.##'],
     'Я':['#######','###.###','###.###','#######','..#####','.##.###','##..###']}
def cyr_rows(ch):
    rows=CYR[ch]+['']*(8-len(CYR[ch]))
    return [sum(128>>x for x,v in enumerate(row) if v=='#') for row in rows]

def main():
    r=ROM((ROOT/'orig/nes/monty.nes').read_bytes())
    nt,_=decode_rle(r,0xd9e9);at,_=decode_rle(r,0xdb12)
    assert len(nt)==960 and len(at)==64
    # Game slots: 0 black, 1 white, 2 red (06h), 3 Joe skin, 4 Revenge (17h),
    # 5 grey (10h), 6 cyan HUD frame (1Ch), 7 accent (27h).
    colors=[0x0f,0x20,0x06,None,0x17,0x10,0x1c,0x27]
    palettes=[[r.b(a+i) for i in range(4)] for a in (0xd46b,0xd47f,0xd483)]+[[0x0f]*4]
    credit_ink=colors.index(palettes[2][2])
    pixel=Image.new('L',(256,240));p=pixel.load()
    # Keep the NES logo and lower tile scene, with room for our level selector.
    for y in list(range(128))+list(range(160,240)):
        for x in range(256):
            tx,ty=x//8,y//8
            pi=(at[(ty//4)*8+tx//4]>>((ty%4//2)*4+(tx%4//2)*2))&3
            v=r.tiles[256+nt[ty*32+tx]][y%8][x%8]
            c=palettes[pi][v] if v else 0x0f
            p[x,y]=colors.index(c) if c in colors else 2   # scene reds only shape the roof
    # Lower scene: the NES title nametable as native field tiles, drawn at run
    # time by the game's own builder (title_scene_draw). As in the first room,
    # the shaft holds the game's rope (90h cap, 95h) in column 15; Joe hangs on
    # it at X116 (as in play), so column 14 is cleared to keep him off bricks.
    native=full_native.native_tiles()
    scene=[native[nt[ty*32+tx]] for ty in range(SCENE_ROW0,30) for tx in range(32)]
    for ty in range(23,30):
        row=(ty-SCENE_ROW0)*32
        scene[row+14]=0
        scene[row+15]=0x90 if ty==23 else 0x95
        scene[row+16]=0
    # Replace only the original credits; leave the black title layout intact.
    for y in range(90,128):
        for x in range(256):p[x,y]=0
    alphabet={chr(ord('A')+i):0x6c+i for i in range(26)}
    alphabet.update({str(i):0x62+i for i in range(10)})
    credits=['© UTOPIA SOFTWARE 1984','VECTOR 06C VERSION BY','BORIS LIKHACHEV 2026']
    if RUS:credits=['© UTOPIA SOFTWARE 1984','ВЕРСИЯ ДЛЯ ВЕКТОРА 06Ц','БОРИС ЛИХАЧЕВ 2026']
    def glyph(ch):
        if ch in CYR:return cyr_rows(ch)
        ch=CYR_LATIN.get(ch,ch)
        return [sum(128>>x for x,v in enumerate(row) if v) for row in r.tiles[256+alphabet[ch]]]
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
            rows=glyph(ch)
            for yy,bits in enumerate(rows):
                for xx in range(8):
                    if bits&(128>>xx):p[x0+i*8+xx,y+yy]=credit_ink
    # Static HUD: the game never redraws the frame, so the title carries it.
    # Make room: logo down 24 rows (below the HUD gap at 56..63), credits
    # down 8 (above the title jump path from y 133 and the menu at y 144).
    src=pixel.copy()
    for y in range(160):
        for x in range(256):p[x,y]=0
    for y0,y1,dy in ((0,90,24),(90,128,8)):
        for y in range(y0,y1):
            for x in range(256):
                if src.getpixel((x,y)):p[x,y+dy]=src.getpixel((x,y))
    hud_chr={0xf8:0x122,0xf9:0x1cd,0xfa:0x120,0xfb:0x121,0xfc:0x1ce,0xfd:0x1cf}  # full_video.py
    hud=[0]*192                                                                # full_native.py layout
    for c in list(range(1,12))+list(range(18,31)):hud[32+c]=0xfa;hud[160+c]=0xfb
    for y in range(1,6):
        for x,t in [(0,0xf8),(12,0xf9),(17,0xf9),(31,0xf8)]:hud[y*32+x]=t
    hud[32+17]=0xfd;hud[160+17]=0xfc
    for i,t in enumerate(hud):
        if t:
            for yy in range(8):
                for xx in range(8):
                    if r.tiles[hud_chr[t]][yy][xx]:p[(i%32)*8+xx,8+(i//32)*8+yy]=colors.index(0x1c)
    assert not any(p[x,y] for x in range(256) for y in list(range(8))+list(range(56,64))), 'HUD gaps must stay black'
    # Title Joe walks the scene with the hero's own physics (nes_title_anim.asm): no roof table.
    for y in range(8*SCENE_ROW0,240):
        for x in range(256):p[x,y]=0
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
    inks=[g if g is not None else encode(RGB[colors[i]]) for i,g in enumerate(GAME_PALETTE)]
    asm+=[' ORG 0xF900','title_palette: db '+','.join(str(v) for v in inks for _ in range(2))]
    (ROOT/'src/native/gen/title.asm').write_text('\n'.join(asm)+'\n')
    (ROOT/'src/native/gen/title_palette.asm').write_text('; Permanent shared cold/warm NES title palette.\n db '+','.join(str(v) for v in inks for _ in range(2))+'\n')
    # Only GAME OVER uses this font now (the level menu is the title HUD):
    # E and V here, G A M O R in font_extra.
    glyphs=[('E',0x70),('V',0x81)]
    def rows(tile):
        if isinstance(tile,str):return cyr_rows(tile)
        return [sum(128>>x for x,v in enumerate(row) if v) for row in r.tiles[256+tile]]
    # ИГРА ОКОНЧЕНА: коды A K O H E P — буквы NES, i g h — кириллица И Г Ч
    if RUS:glyphs=[('A',alphabet['A']),('i','И'),('g','Г'),('h','Ч')]
    font=['; NES title-credit CHR glyphs for GAME OVER.',
          f'NES_TITLE_CREDITS_INK equ {encode(RGB[palettes[2][2]])}',
          f'NES_TITLE_TEXT_SLOT equ {credit_ink}','font_tab:']
    for char,tile in glyphs:
        font.append(' db "'+char+'",'+','.join(map(str,rows(tile))))
    font.append(' db " ",0,0,0,0,0,0,0,0   ; пробел закрашивает клетку')
    font.append(' db 255 ; continue at font_extra')
    (ROOT/'src/native/gen/font_nes.asm').write_text('\n'.join(font)+'\n')
    # FE00..FE2F is sprite slot 5's background buffer (page FE): the five glyphs
    # must end below FE00; the blank glyph (space) lives in font_tab.
    extra=['; The five GAME OVER glyphs occupy permanent high RAM below sprite slot 5.',' ORG 0xFDD0','font_extra:']
    for ch in ('KOHEP' if RUS else 'GAMOR'):
        extra.append(' db "'+ch+'",'+','.join(map(str,rows(alphabet[ch]))))
    extra.append(' ASSERT $ <= 0xFE00')
    (ROOT/'src/native/gen/font_nes_extra.asm').write_text('\n'.join(extra)+'\n')
    out=ROOT/'build/nes_title';out.mkdir(parents=True,exist_ok=True)
    (out/'title_screen_full.raw').write_bytes(screen)
    # Warm title (after GAME OVER): the logo and credits above STRIPE_END are
    # one ink per row, so plane 8000 keeps only their mono mask and
    # title_stripes spreads it over the planes by a row-run table. The brick
    # scene below stays in full three planes. Bytes the row ink gets wrong
    # (Revenge touching MONTEZUMA'S) are patched in plane 8000 afterwards.
    STRIPE_END=160
    ink=[None]*STRIPE_END
    for y in range(STRIPE_END):
        used={p[x,y] for x in range(256)}-{0}
        assert len(used)<=2, f'title row {y} has inks {used}'
        if used:
            # Majority ink; the minority one becomes plane-8000 patches.
            ink[y]=max(used,key=lambda v:sum(p[x,y]==v for x in range(256)))
    for y in range(STRIPE_END):          # empty rows take a neighbour's ink
        if ink[y] is None:ink[y]=ink[y-1] if y else next(v for v in ink if v)
    warm=bytearray(screen)
    for c in range(32):
        for y in range(STRIPE_END):
            o=256*c+255-y
            warm[o]=warm[o]|warm[0x2000+o]|warm[0x4000+o]
            warm[0x2000+o]=warm[0x4000+o]=0
    runs=[]
    for y in range(STRIPE_END):
        if runs and runs[-1][0]==ink[y]:runs[-1][2]=y
        else:runs.append([ink[y],y,y])
    expanded=bytearray(warm)
    for v,y0,y1 in runs:
        for c in range(32):
            for y in range(y0,y1+1):
                o=256*c+255-y;m=expanded[o]
                expanded[o]=m if v&4 else 0
                expanded[0x2000+o]=m if v&2 else 0
                expanded[0x4000+o]=m if v&1 else 0
    fixes=[]
    for o in range(0x6000):
        if expanded[o]!=screen[o]:
            fixes.append((0x8000+o,screen[o]));expanded[o]=screen[o]
    assert expanded==screen
    tab=['; Warm title row inks: colour, first offset (255-last row), row count.',
         'title_stripe_tab:']
    tab+=[f' db {v},{255-y1},{y1-y0+1}' for v,y0,y1 in runs]+[' db 0']
    tab+=['; Screen patches: address, byte; ends with high byte 0.']
    tab+=[f' dw 0x{a:04X}\n db {b}' for a,b in fixes]+[' dw 0']
    (ROOT/'src/native/gen/title_stripes.asm').write_text('\n'.join(tab)+'\n')
    scene_data=bytes(scene)
    assert len(scene_data)+24<=768, 'title scene overflows the room field buffer'
    screen=warm
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
    scene_raw=out/'title_scene.raw';scene_raw.write_bytes(scene_data)
    scene_packed=out/'title_scene.zx0'
    subprocess.run([str(zx_bin),'-f',str(scene_raw),str(scene_packed)],check=True,capture_output=True)
    tstream=scene_packed.read_bytes()
    cache+=[f'TITLE_SCENE_ROW0 equ {SCENE_ROW0}','title_scene_packed:']
    for i in range(0,len(tstream),24):
        cache.append(' db '+','.join(map(str,tstream[i:i+24])))
    cache.append('title_packed_end:')
    (ROOT/'src/native/gen/title_packed.asm').write_text('\n'.join(cache)+'\n')
    rgb=Image.new('RGB',pixel.size);rgb.putdata([decode(inks[v]) for v in pixel.getdata()]);rgb.save(out/'native.png')
    (out/'native.idx').write_bytes(pixel.tobytes())
    # Independent MAME snapshot confirms both source streams, including HUD-free
    # attribute quadrants. Optional so clean builds need only the local ROM.
    ref=out/'title_90.ppu'
    if ref.exists():
        ppu=ref.read_bytes();assert nt[:512]==ppu[0x2000:0x2200] and at[:32]==ppu[0x23c0:0x23e0]
    (out/'title.json').write_text(json.dumps(dict(name_rle='D9E9',attribute_rle='DB12',mame_verified=ref.exists(),scaled=False,palette=inks,credits=credits,scene_rows=[20,29],scene='native tiles, game builder',rope_column=15,rope_rows=[23,29],shaft_columns=[14,16]),indent=2)+'\n')

if __name__=='__main__':main()
