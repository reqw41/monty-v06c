#!/usr/bin/env python3
"""Лист комнат пирамидой: tools/pyramid.py <уровень> -> build/rooms/pyramid<уровень>.png (по build/rooms/L<у>_<n>.ppm)."""
import sys, json
from PIL import Image, ImageDraw
lv = sys.argv[1]
d = json.load(open(f'build/rooms/L{lv}.json'))
W, H = 96, 72
img = Image.new('RGB', (19 * (W + 2), 9 * (H + 12)), (40, 40, 40)); dr = ImageDraw.Draw(img)
for i, (r, c, _) in d.items():
    x, y = c * (W + 2), r * (H + 12)
    img.paste(Image.open(f'build/rooms/L{lv}_{i}.ppm').resize((W, H)), (x, y + 11))
    dr.text((x + 2, y), i, fill=(255, 255, 0))
img.save(f'build/rooms/pyramid{lv}.png')
