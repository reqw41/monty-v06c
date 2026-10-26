#!/usr/bin/env python3
"""Данные нативной сборки: src/native/gen/cart.asm — блоки данных картриджа (разметка build/monty.skool) с меткой
C_xxxx на каждый адрес (EQU), слова-указатели в данные -> dw C_xxxx; src/native/gen/pats.asm — шаблоны из
снимка VRAM оригинала (tools/vsnap.js): банк 0, различия банков 1, 2, 5 для набора анимированных тайлов,
шаблоны спрайтов, начальные цвета.
  node tools/vsnap.js && python3 -I tools/mknative.py"""
import re, os
ROOT = os.path.join(os.path.dirname(__file__), '..')
IMG = open(os.path.join(ROOT, 'build/monty_entry.bin'), 'rb').read()
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
for (a, b) in sorted(take):
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
        row.append(f'0x{IMG[p]:02X}'); p += 1
        if len(row) == 16: flush()
    flush()
data_kept = sum(b - a for a, b in take)
open(os.path.join(ROOT, 'src/native/gen/cart.asm'), 'w').write('\n'.join(out + [''] + eqs) + '\n')
print('данных картриджа', data_kept, 'из', len(data), 'байт,', len(take), 'блоков')

# --- шаблоны из снимка VRAM ---
V = open(os.path.join(ROOT, 'build/native/vram.bin'), 'rb').read()
ANIM = [0x04, 0x05, 0x06, 0x38, 0xA0, 0xA3, 0xA4, 0xA7, 0xB8, 0xB9, 0xBA, 0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5]
BANKS = [0x0000, 0x0800, 0x1000, 0x2800]
other = [t for t in range(256) if t not in ANIM and any(V[b + 8 * t:b + 8 * t + 8] != V[8 * t:8 * t + 8] for b in BANKS[1:])]
if other: print('ВНИМАНИЕ: различия банков вне набора:', ' '.join(f'{t:02X}' for t in other))
V0 = open(os.path.join(ROOT, 'build/native/vram0.bin'), 'rb').read()   # на входе в A59D (банк 0 — сжатым, tools/pack.py)
P = ['; создано tools/mknative.py — не править'] + ['; различия банков 1, 2, 5: anim_set[i] -> pdiff + 24 i (по 8 байт на банк)', 'anim_set:\tdb\t' + ','.join(f'0x{t:02X}' for t in ANIM) + ',0xFF', 'pdiff:']
for t in ANIM:
    for b in BANKS[1:]: P.append('\t\tdb\t' + ','.join(f'0x{x:02X}' for x in V[b + 8 * t:b + 8 * t + 8]))
P += ['; цвета групп на входе в начало уровня', 'col0:\t\tdb\t' + ','.join(f'0x{x:02X}' for x in V0[0x2000:0x2020])]
S = ['; создано tools/mknative.py — не править', '; шаблоны спрайтов (VDP 3800) — прямо по рабочему адресу VSPR (часть образа)', '\t\tORG\tVSPR', 'spat:']
for i in range(0, 0x800, 16): S.append('\t\tdb\t' + ','.join(f'0x{x:02X}' for x in V[0x3800 + i:0x3810 + i]))
open(os.path.join(ROOT, 'src/native/gen/spat.asm'), 'w').write('\n'.join(S) + '\n')
open(os.path.join(ROOT, 'src/native/gen/pats.asm'), 'w').write('\n'.join(P) + '\n')
print('шаблоны: банк 0, различия', len(ANIM), 'тайлов, спрайты 2 КБ')
