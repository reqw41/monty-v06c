#!/usr/bin/env python3
"""Cold 16-colour ROM wrapper; the in-game binary is restored without changes."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--build', default='build/nes-blend80-sp-white-ladder')
    ap.add_argument('--output', required=True)
    ap.add_argument('--quick', action='store_true')
    args = ap.parse_args()
    build = ROOT / args.build
    stage = build / 'splash'
    stage.mkdir(parents=True, exist_ok=True)
    core = (build / 'monty.bin').read_bytes()
    assert len(core) == 0xFEC0
    symbols = {n: int(v, 16) for n, v in re.findall(r'^(\w+): EQU 0x([0-9A-F]+)',
                                                 (build / 'monty.sym').read_text(), re.M)}
    source = ROOT / 'assets/montezuma-vector-256x256-16.png'
    im = Image.open(source)
    assert im.mode == 'P' and im.size == (256, 256)
    indices = list(im.getdata())
    assert set(indices) == set(range(16))
    palette = (ROOT / 'assets/montezuma-vector.pal').read_bytes()
    assert len(palette) == 16
    screen = bytearray(0x8000)
    for plane, bit in enumerate((8, 4, 2, 1)):
        for col in range(32):
            for y in range(256):
                screen[plane*8192+256*col+255-y] = sum(128 >> x for x in range(8)
                    if indices[y*256+col*8+x] & bit)
    (stage / 'screen.bin').write_bytes(screen)
    (stage / 'source.idx').write_bytes(bytes(indices))
    (stage / 'palette.bin').write_bytes(palette)
    zx0 = ROOT / 'build/nes_title/zx0'
    for name, data, options in [('payload', core[256:], ['-b']), ('prefix', core[:256], [])]:
        digest = hashlib.sha256(data + bytes([args.quick])).hexdigest()
        raw, packed, tag = (stage / (name + suffix) for suffix in ('.raw', '.zx0', '.sha256'))
        if not packed.exists() or not tag.exists() or tag.read_text() != digest:
            raw.write_bytes(data)
            subprocess.run([str(zx0), '-f', *(['-q'] if args.quick else []), *options,
                            str(raw), str(packed)], check=True, capture_output=True)
            tag.write_text(digest)
    count = (stage / 'payload.zx0').stat().st_size
    assert count < 0x7000, 'compressed game does not fit below the splash image'
    (stage / 'splash_config.asm').write_text(
        f'CORE_END equ {len(core)}\nPAYLOAD_BYTES equ {count}\nCORE_ZX0 equ {symbols["title_zx0"]}\n')
    shutil.copyfile(ROOT / 'src/native/splash.asm', stage / 'splash.asm')
    result = subprocess.run([str(ROOT / 'tools/sjasmplus'), '--nologo', '--i8080',
                             '--sym=splash.sym', 'splash.asm'], cwd=stage,
                            capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    target = ROOT / args.output
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(stage / 'splash.rom', target)
    report = dict(core_sha256=hashlib.sha256(core).hexdigest(), packed_payload=count,
                  prefix_bytes=(stage / 'prefix.zx0').stat().st_size, image_colours=16,
                  image_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                  rom=str(target.relative_to(ROOT)), dismissed_by='Space or joystick Fire' if symbols.get('NES_JOYSTICK_P') else 'Space')
    (stage / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
