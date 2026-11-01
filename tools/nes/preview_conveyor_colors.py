#!/usr/bin/env python3
"""Compare NES CHR with verified native conveyor cache bytes."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont
from assets import ROM, RGB

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT.parents[1] / 'outputs'


def main():
    data = json.loads((ROOT / 'build/conveyor-colors.json').read_text())
    native = {q['t']: q['frames'] for q in data['images']}
    rom = ROM((ROOT / 'orig/nes/monty.nes').read_bytes())
    palette = [((v & 7) * 32, ((v >> 3) & 7) * 32, ((v >> 6) & 3) * 64)
               for v in data['palette']]
    font_path = '/System/Library/Fonts/Supplemental/Arial.ttf'
    font = ImageFont.truetype(font_path, 18)
    small = ImageFont.truetype(font_path, 13)
    frames = []
    for phase in range(4):
        im = Image.new('RGB', (550, 238), '#171b22')
        d = ImageDraw.Draw(im)
        d.text((18, 12), 'Транспортёр: отдельный цвет зацепов', font=font, fill='white')
        for row, label in enumerate(['NES', 'Было', 'Проба']):
            y0 = 53 + row * 52
            d.text((18, y0 + 6), label, font=font, fill='#ccd3df')
            pic = Image.new('RGB', (96, 8))
            for y in range(8):
                for x in range(96):
                    tile, xx = (x % 24) // 8, x % 8
                    v = rom.tiles[0x13c + 3 * phase + tile][y][xx]
                    if row == 0:
                        colour = RGB[[0x0f, 0x16, 0x06, 0x1c][v]]
                    elif row == 1:
                        colour = palette[2 if v else 0]
                    else:
                        b = native[4 + tile][phase]
                        ink = sum(bit for p, bit in enumerate([4, 2, 1])
                                  if b[p * 8 + y] & (128 >> xx))
                        colour = palette[ink]
                    pic.putpixel((x, y), colour)
            im.paste(pic.resize((384, 32), Image.Resampling.NEAREST), (142, y0))
        d.text((18, 218), 'Движется C000; тело в A000; плоскость 8000 пустая.', font=small, fill='#aeb7c7')
        frames.append(im)
    OUT.mkdir(exist_ok=True)
    frames[0].save(OUT / 'conveyor-white-hooks.png')
    frames[0].save(OUT / 'conveyor-white-hooks.gif', save_all=True, append_images=frames[1:],
                   duration=160, loop=0, disposal=2)
    print(OUT / 'conveyor-white-hooks.gif')


if __name__ == '__main__':
    main()
