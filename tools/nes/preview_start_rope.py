#!/usr/bin/env python3
"""Render the real emulator captures made by nes-start-rope.js."""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT.parents[1] / 'outputs'
CAPTURE = ROOT / 'build/title-scene/capture'


def picture(path):
    pixels = path.read_bytes()
    assert len(pixels) == 256 * 256
    palette = json.loads(path.with_suffix('.json').read_text())['palette']
    colours = [((v & 7) * 32, ((v >> 3) & 7) * 32, ((v >> 6) & 3) * 64)
               for v in palette]
    im = Image.new('RGB', (256, 256))
    im.putdata([colours[v] for v in pixels])
    return im.resize((512, 512), Image.Resampling.NEAREST)


def main():
    OUT.mkdir(exist_ok=True)
    title = picture(CAPTURE / 'title.idx')
    title.save(OUT / 'title-nes-maze.png')
    frames = [picture(p) for p in sorted(CAPTURE.glob('intro-*.idx'))]
    assert frames
    frames[0].save(OUT / 'start-rope.gif', save_all=True, append_images=frames[1:],
                   duration=[20] * (len(frames) - 1) + [1000], loop=0, disposal=2)
    title.save(OUT / 'title-and-start.gif', save_all=True, append_images=frames,
               duration=[1600] + [20] * (len(frames) - 1) + [1000], loop=0, disposal=2)
    print(OUT / 'title-nes-maze.png')
    print(OUT / 'start-rope.gif')


if __name__ == '__main__':
    main()
