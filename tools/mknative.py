#!/usr/bin/env python3
"""Данные нативной сборки: src/native/gen/cart.asm — блоки данных картриджа (разметка build/monty.skool) с меткой
C_xxxx на каждый адрес (EQU), слова-указатели в данные -> dw C_xxxx; src/native/gen/video.asm — исходные полосы тайлов и цвета;
src/native/gen/spat.asm — общие исходные кадры объектов и таблица указателей.
  node tools/vsnap.js && python3 -I tools/mknative.py"""
import re, os, sys
ROOT = os.path.join(os.path.dirname(__file__), '..')
IMG = open(os.path.join(ROOT, 'build/monty_entry.bin'), 'rb').read()
CART = bytearray(IMG)
if '--nes-full' in sys.argv:
    # Inventory retains MSX logical item IDs, but its art must use NES blocks.
    # These aliases otherwise name MSX-only tiles absent from full_video.py.
    for inventory, world in [(0x8C,0x49),(0x91,0x4E)]:
        CART[0x9FD2+inventory:0x9FD2+inventory+4] = IMG[0x9FD2+world:0x9FD2+world+4]
LO, HI = 0x800C, 0xBFFF
PTR_TABLES = {0x9477: 100, 0xAD0B: 10}         # указатели в данные (комнаты, эффекты)

items = []                                     # (вид, адрес)
ptr = set()
for a, n in PTR_TABLES.items():
    for k in range(n): ptr.add(a + 2 * k)
kind = None
for l in open(os.path.join(ROOT, 'build/monty.skool')):
    m = re.match(r'^([cbw* @])\$([0-9A-F]{4}) (.*?)\s*(;.*)?$', l)
    if not m: continue
    t, a, txt = m.group(1), int(m.group(2), 16), m.group(3).strip()
    if t in 'cbw': kind = t
    if not (LO <= a <= HI): continue
    items.append(('c' if kind == 'c' else 'b', a))
    if kind == 'b' and txt.startswith('DEFW'):
        for k in range(len(txt[4:].split(','))): ptr.add(a + 2 * k)
data = set()
for i, (k, a) in enumerate(items):
    if k == 'b':
        e = items[i + 1][1] if i + 1 < len(items) else HI + 1
        data.update(range(a, e))
if '--nes-full' in sys.argv:
    # Original geometry/room-pointer stream is replaced by the NES room pack.
    data.difference_update(range(0x9477, 0x9FD2))
# блоки данных: непрерывные участки (как в разметке); берутся только нужные нативному коду — по меткам C_xxxx
# в src/native/*.asm и, по цепочке, по словам-указателям внутри взятых блоков
blocks = []
a = LO
while a <= HI:
    if a not in data: a += 1; continue
    b = a
    while b <= HI and b in data: b += 1
    blocks.append((a, b)); a = b
def blk_of(x):
    for (a, b) in blocks:
        if a <= x < b: return (a, b)
import glob
need = set()
for f in glob.glob(os.path.join(ROOT, 'src/native/*.asm')):
    if os.path.basename(f) in (('drawroom.asm','sound.asm') if '--nes-full' in sys.argv else ('drawroom_nes.asm','sound_nes.asm')): continue
    for m in re.finditer(r'C_([0-9A-F]{4})', open(f).read()): need.add(int(m.group(1), 16))
take, work = set(), [blk_of(x) for x in need if blk_of(x)]
while work:
    bk = work.pop()
    if bk in take: continue
    take.add(bk)
    for p in range(bk[0], bk[1] - 1):
        if p in ptr:
            w = IMG[p] | IMG[p + 1] << 8
            if w in data and blk_of(w) not in take: work.append(blk_of(w))
out = ['; создано tools/mknative.py — не править', '; данные картриджа (нужные нативному коду): C_xxxx — адрес xxxx оригинала', '']
eqs = []
data_kept = 0
for (a, b) in sorted(take):
    if '--nes-full' in sys.argv:
        # These two MSX blocks contain much more art than the native game
        # reads. 830D copies 28 colour bytes from 841E; the last 9378 user
        # reads the ninth seven-byte row starting at 93C0. Keep the original
        # bytes that logic still uses and leave the rest out of NES_FULL.
        if a == 0xA9AD: continue  # obsolete MSX bonus rope / boundary strips
        if a == 0x841E: b = min(b, 0x841E + 28)
        if a == 0x9378: b = min(b, 0x93C0 + 9 * 7)
    data_kept += b-a
    out.append(f'blk_{a:04X}:')
    row = []
    def flush():
        if row: out.append('\t\tdb\t' + ','.join(row)); row.clear()
    p = a
    while p < b:
        eqs.append(f'C_{p:04X}\t\tequ\tblk_{a:04X}+0x{p - a:04X}')
        if p in ptr and p + 1 < b:
            w = IMG[p] | IMG[p + 1] << 8
            if w in data:
                flush(); eqs.append(f'C_{p + 1:04X}\t\tequ\tblk_{a:04X}+0x{p + 1 - a:04X}')
                out.append(f'\t\tdw\tC_{w:04X}'); p += 2; continue
        row.append(f'0x{CART[p]:02X}'); p += 1
        if len(row) == 16: flush()
    flush()
open(os.path.join(ROOT, 'src/native/gen/cart_full.asm' if '--nes-full' in sys.argv else 'src/native/gen/cart.asm'), 'w').write('\n'.join(out + [''] + eqs) + '\n')
print('данных картриджа', data_kept, 'из', len(data), 'байт,', len(take), 'блоков')

# --- шаблоны из снимка VRAM ---
V = open(os.path.join(ROOT, 'build/native/vram.bin'), 'rb').read()
S = ['; Создано tools/mknative.py: исходные кадры объектов, совпадающие кадры разделяются.',
     '\t\tORG\tVSPR', 'sprite_sources:']
frames = {}
refs = []
for i in range(64):
    frame = bytes(V[0x3800+32*i:0x3820+32*i])
    if frame not in frames: frames[frame] = 'shape_%02d' % len(frames)
    refs.append(frames[frame])
for i in range(0,64,8): S.append(' dw '+','.join(refs[i:i+8]))
for frame, label in frames.items():
    S.append(label+':')
    for i in range(0,32,16): S.append(' db '+','.join(map(str,frame[i:i+16])))
S.append('sprite_sources_end:')
open(os.path.join(ROOT, 'src/native/gen/spat.asm'), 'w').write('\n'.join(S)+'\n')
import runpy
runpy.run_path(os.path.join(ROOT, 'tools/mkvideo.py'), run_name='__main__')
print('шаблоны спрайтов: 2 КБ исходной графики')

# Direct logic classification in the unused boot-vector page (0040..00FF).
# Low tiles use explicit comparisons; bits 4/5 distinguish items and keys,
# low nibble keeps the original CPIR remainder (the corner of a 2x2 item).
# The low-tile comparisons and conveyor ranges in the assembly are intentional
# specializations. Fail generation if a different cartridge changes those sets.
assert set(t for t in IMG[0x943C:0x9444] if t < 0x40) == {8, 0x0B}
assert set(t for t in IMG[0xA00E:0xA013] if t < 0x40) == {0x38}
assert set(t for t in IMG[0x93FF:0x9409] if t < 0x40) == {4,5,6,8,0x10,0x11}
assert list(IMG[0x9412:0x9419]) == [4,5,6,0xB9,0xB8,0xBA,0x9B]
logic = [0] * 256
for address, size, kind in [(0x9418,16,0x20),(0x9430,12,0x30),(0x9428,8,0x40)]:
    for i, tile in enumerate(IMG[address:address+size]):
        assert tile >= 0x40 and logic[tile] == 0
        logic[tile] = kind | (size-i-1)
for tile in IMG[0x943C:0x9444]:
    if tile >= 0x40: logic[tile] |= 0x80
for tile in IMG[0xA00E:0xA013]:
    if tile >= 0x40: logic[tile] |= 0x10
for tile in IMG[0x93FF:0x9409]:
    if tile >= 0x40: logic[tile] |= 1
with open(os.path.join(ROOT,'src/native/gen/logic.asm'),'w') as out:
    out.write('; Generated by mknative.py from cartridge membership lists.\n\tORG 0x0040\nlogic_class:\n')
    for start in range(0x40,256,16):
        out.write('\tdb '+','.join('0x%02X'%v for v in logic[start:start+16])+'\n')
    out.write('\tASSERT $ == 0x0100\n')
