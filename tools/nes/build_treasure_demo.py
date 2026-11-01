#!/usr/bin/env python3
"""Separate demo: wait on the existing ledge before the player jumps into bonus."""
from pathlib import Path
import argparse
import shutil
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--side', choices=('left', 'right'), default='left')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
build = root / ('build/treasure-listen' + ('-right' if args.side == 'right' else ''))
source = build / 'src'
shutil.copytree(root / 'src/native', source, dirs_exist_ok=True)

def edit(name, old, new, count=1):
    p = source / name
    text = p.read_text()
    assert text.count(old) >= count, (name, old)
    p.write_text(text.replace(old, new, count))

edit('game.asm', '"../vec/util.asm"', '"' + str(root / 'src/vec/util.asm') + '"')
edit('sprites.asm', '"../../build/native/ram0.pk"', '"' + str(root / 'build/native/ram0.pk') + '"')
edit('game.asm', '"../../build/native/monty.bin"', '"' + str(build / 'monty.bin') + '"', 2)
# Keep the normal boot relocation and cache construction; skip title/menu input.
p = source / 'nes_boot.asm'
t = p.read_text()
a, b = t.index('nm_wait:'), t.index('nes_begin:')
t = t[:a] + '''nm_wait:
 ld a,178
 ld (0x70AC),a
 ld b,1
 jp gs2
''' + t[b:]
t = t.replace('call title_animate', '; no introduction in the listening ROM', 1)
p.write_text(t)
edit('level.asm', 'or\t4\n', 'or\t0\n')
edit('level.asm', ' ld (0x71A7),a\n', '')
edit('level.asm', ' ld a,10\n ld (0x71A8),a\n', ' ld hl,0x0A08\n ld (0x71A7),hl\n')
edit('level.asm', ' ld a,44\n', ' ld a,172\n')
edit('level.asm', ' ld a,116\n', ' ld a,' + str(52 if args.side == 'left' else 188) + '\n')
if args.side == 'right':
    edit('level.asm', ' ld (0x7305),a\n', ' ld (0x7305),a\n ld a,254\n ld (0x7078),a\n')
edit('level.asm', 'ld a,4                    ; begin attached to the opening rope', 'xor a                     ; stand on the existing left ledge, waiting for input')
edit('nes_treasure.asm', 'nt_bonus_tick:\n', 'nt_bonus_tick:\n ret ; listening demo: retain bonus and loop music indefinitely\n')
subprocess.run([str(root/'tools/sjasmplus'), '--nologo', '--i8080', '-DNES_JOE_3COLOR',
 '-DNES_JOE_BLEND80', '-DNES_JOE_SP_RESTORE', '-DNES_LADDER_LOW', '-DNES_STABLE_COLORS',
 '--sym='+str(build/'monty.sym'), 'game.asm'], cwd=source, check=True)
name = 'Monty-v06c-treasure-music-demo.r0m' if args.side == 'left' else 'Monty-v06c-treasure-right-demo.r0m'
target = root.parents[1] / 'outputs/rom' / name
shutil.copyfile(build/'monty.bin', target)
print(target)
