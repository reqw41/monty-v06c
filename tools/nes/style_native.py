#!/usr/bin/env python3
"""NES-inspired native graphics, fitted to MSX collision cells. Local CHR only."""
import json
from pathlib import Path
from PIL import Image
from assets import ROM, RGB, sheet

ROOT = Path(__file__).resolve().parents[2]

def graphics(v0):
    rom = ROM((ROOT/'orig/nes/monty.nes').read_bytes())
    masks = {}
    mapping = {}
    def tile(msx, nes, values=(1,2,3)):
        mapping[msx] = dict(chr=nes, values=list(values))
        masks[msx] = bytes(sum(128>>x for x in range(8) if rom.tiles[nes][y][x] in values) for y in range(8))
    # Keep the MSX field, including its partial platforms and collision numbers.
    tile(8,0x100,()); tile(0xF4,0x101,())
    for a,b in [(0x10,0x111),(0x11,0x112),(0x88,0x10f),(0x89,0x110),
                (0x90,0x10c),(0x95,0x10d),(0x98,0x139),(0xD8,0x13a),
                (0x99,0x156),(0xD9,0x15a)]: tile(a,b)
    # Native score digits remain 8x16; NES digits are 16x16, sampled by pairs.
    for n in range(10):
        for half in range(2):
            a=0x18+16*half+n; t=0x1d0+4*n+2*half
            mapping[a]=dict(digit=n,half=half)
            masks[a]=bytes(sum(128>>x for x in range(8) if rom.tiles[t+x//4][y][2*(x%4)]) for y in range(8))
    # Thin NES frame, independent of room bricks. 09/0C horizontal, 0A/0B sides.
    masks.update({0xF8:bytes([255,255,0,0,0,0,0,0]),0xFB:bytes([0,0,0,0,0,0,255,255]),
                  0xF9:bytes([192]*8),0xFA:bytes([3]*8)})
    # Corner webs are visual tiles only. No writes to VNT or membership lists.
    web=[255,193,162,148,136,144,160,192]
    masks[0xF0]=bytes(web)
    masks[0xF1]=bytes(int(f'{b:08b}'[::-1],2) for b in web)
    # Small hats retain one icon per life; pair-sample the two-tile NES HUD hat.
    hats=[]
    for y in range(8):
        hats.append([rom.tiles[0x154+x//4][y][2*(x%4)] for x in range(8)])
    # Palette ink: orange crown/brim, white ribbon. NES source uses inks 1/2.
    hat_indices=[[0 if not v else 1 if v==2 else 2 for v in row] for row in hats]
    brick=[]
    for t in (0x100,0x101):
        pix=[[{0:0,1:3,2:2,3:6}[v] for v in row] for row in rom.tiles[t]]
        brick.append(bytes(sum(128>>x for x in range(8) if pix[y][x]&bit) for bit in (4,2,1) for y in range(8)))
    hat=bytes(sum(128>>x for x in range(8) if hat_indices[y][x]&bit) for bit in (4,2,1) for y in range(8))
    # Foreground/background modes for fixed native indices. Room darkness remains
    # driven by the original group colours; only wall shading uses a third ink.
    manifest=dict(mapping={str(k):v for k,v in mapping.items()},masks={str(k):list(v) for k,v in masks.items() if k not in mapping},hat_chr=[0x154,0x155],digit_base=0x1d0,
                  palette_accent=[rom.b(0xc5d5+i) for i in range(9)])
    out=ROOT/'build/nes_style'; out.mkdir(parents=True,exist_ok=True)
    (out/'source.json').write_text(json.dumps(manifest,indent=2)+'\n')
    asm=['; Generated from local NES CHR by tools/nes/style_native.py.','style_bricks:']
    for b in brick: asm.append(' db '+','.join(map(str,b)))
    asm+=['style_hat:',' db '+','.join(map(str,hat)),'style_accents: db '+','.join(str(round(RGB[v][2]/85)*64+round(RGB[v][1]*7/255)*8+round(RGB[v][0]*7/255)) for v in manifest['palette_accent'])]
    (ROOT/'src/native/gen/style.asm').write_text('\n'.join(asm)+'\n')
    return masks

if __name__=='__main__':
    graphics((ROOT/'build/native/vram0.bin').read_bytes())
