#!/usr/bin/env python3
"""PPM -> PNG (увеличение x2): tools/ppm2png.py a.ppm [b.ppm ...] -> a.png ...; с -o out.png склеивает в ряд."""
import sys
from PIL import Image
args = sys.argv[1:]
out = None
if '-o' in args:
    i = args.index('-o'); out = args[i + 1]; del args[i:i + 2]
ims = [Image.open(a).resize((512, 384), Image.NEAREST) for a in args]
if out:
    w = Image.new('RGB', (sum(i.width + 8 for i in ims), 384), (128, 128, 128))
    x = 0
    for i in ims: w.paste(i, (x, 0)); x += i.width + 8
    w.save(out)
else:
    for a, i in zip(args, ims): i.save(a.rsplit('.', 1)[0] + '.png')
