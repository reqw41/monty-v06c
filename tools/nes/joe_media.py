#!/usr/bin/env python3
"""Render headless Joe bench captures; preserve captured indices and Vector palette."""
import argparse, json
from pathlib import Path
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[2]

def picture(path, meta=None):
    meta = meta or path.with_suffix('.json')
    data = json.loads(meta.read_text())
    palette = data if isinstance(data, list) else data['palette']
    colors = []
    for v in palette:
        colors += [(v & 7) * 32, ((v >> 3) & 7) * 32, ((v >> 6) & 3) * 64]
    im = Image.frombytes('P', (256, 192), path.read_bytes())
    im.putpalette(colors + [0] * (768 - len(colors)))
    return im.convert('RGB')

def animation(paths, output, scale):
    frames = []
    for p in paths:
        meta = p.parent / ('palette_' + p.stem.split('_')[-1] + '.json') if p.stem.startswith('raster_') else None
        im = picture(p, meta).resize((256 * scale, 192 * scale), Image.Resampling.NEAREST)
        frames.append(im.convert('P', palette=Image.Palette.ADAPTIVE, colors=8))
    if not frames:
        raise ValueError('No frames for ' + str(output))
    frames[0].save(output, save_all=True, append_images=frames[1:], duration=20, loop=0, optimize=True)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--directory', type=Path, default=ROOT / 'build/joe_nes')
    ap.add_argument('--scale', type=int, default=3)
    args = ap.parse_args(); dest, scale = args.directory, args.scale
    for room in ['1_9', '5_7', '7_2']:
        panels = []
        for variant, title in [('default', 'Room palette / 2 colours'), ('nes2', 'NES palette / 2 colours'), ('nes3', 'NES palette / 3 colours')]:
            im = picture(dest / f'{variant}_{room}.idx')
            im.resize((256 * scale, 192 * scale), Image.Resampling.NEAREST).save(dest / f'{variant}_{room}.png')
            panel = Image.new('RGB', (256 * scale, 192 * scale + 24), '#181818')
            panel.paste(im.resize((256 * scale, 192 * scale), Image.Resampling.NEAREST), (0, 24))
            ImageDraw.Draw(panel).text((10, 6), title, fill='white')
            panels.append(panel)
        joined = Image.new('RGB', (768 * scale, panels[0].height))
        for i, panel in enumerate(panels): joined.paste(panel, (i * panel.width, 0))
        joined.save(dest / f'palette_{room}.png')
    raw = dest / 'raw'
    walk = sorted(raw.glob('walk_*.idx'))[:70]
    death = [p for p in sorted(raw.glob('ladder_*.idx')) if json.loads(p.with_suffix('.json').read_text())['state'] == 8]
    raster = sorted((dest / 'scan').glob('raster_*.idx'))
    animation(raster, dest / 'jump.gif', scale)
    animation(walk, dest / 'walk.gif', scale)
    animation(death, dest / 'death.gif', scale)
    print('Rendered palette comparisons and jump/walk/death GIFs in', dest)

if __name__ == '__main__': main()
