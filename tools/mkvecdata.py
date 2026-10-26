#!/usr/bin/env python3
"""Данные для сборки i8080 -> src/vec/gen/data.asm.

- room_blk: данные комнат картриджа 9444-A066 как есть (ROOM_TS 9444, ROOM_TAB 9477, ROOM_DATA 9541,
  TILESETS 9FD1); слова таблицы ROOM_TAB пересчитаны на адрес блока.
- row_base (A4C5), mirror_pairs (AB0C), hud_box (AA88-AA95), inv_blank (85D7, 10 байт).
- tiles0: шаблоны тайлов банка 0 (build/res/tiles.bin), colors_base (32), floors (9 x 7).
- msx2vec: цвета MSX -> байт палитры Вектора BBGGGRRR; merge_pairs: пары (убираемый, замена) по близости
  цветов, по возрастанию расстояния, конец FF.
"""
import os
ROOT = os.path.join(os.path.dirname(__file__), '..')
IMG = open(os.path.join(ROOT, 'build/monty_entry.bin'), 'rb').read()
RES = lambda n: open(os.path.join(ROOT, 'build/res', n), 'rb').read()
PAL = [(0, 0, 0), (0, 0, 0), (33, 200, 66), (94, 220, 120), (84, 85, 237), (125, 118, 252), (212, 82, 77), (66, 235, 245),
       (252, 85, 84), (255, 121, 120), (212, 193, 84), (230, 206, 128), (33, 176, 59), (201, 91, 186), (204, 204, 204), (255, 255, 255)]
LO, HI = 0x9444, 0xA066
out = ['; создано tools/mkvecdata.py — не править', '']


def db(label, data, per=16):
    if label: out.append(f'{label}:')
    for i in range(0, len(data), per):
        out.append('\t\tdb\t' + ','.join(f'0x{b:02X}' for b in data[i:i + per]))


out.append('room_blk:')
a = LO
while a <= HI:
    if 0x9477 <= a < 0x9477 + 200:
        w = IMG[a] | IMG[a + 1] << 8
        out.append(f'\t\tdw\troom_blk+0x{w - LO:04X}')
        a += 2
    else:
        e = min(HI + 1, a + 16, 0x9477 if a < 0x9477 else HI + 1)
        out.append('\t\tdb\t' + ','.join(f'0x{b:02X}' for b in IMG[a:e])); a = e
for n, ad in (('ROOM_TS', 0x9444), ('ROOM_TAB', 0x9477), ('TILESETS', 0x9FD1)):
    out.append(f'{n}\t\tequ\troom_blk+0x{ad - LO:04X}')
db('row_base', IMG[0xA4C5:0xA4CE])
a = 0xAB0C
while IMG[a] != 0xFF: a += 2
db('mirror_pairs', IMG[0xAB0C:a + 1])
db('hud_box', IMG[0xAA88:0xAA94])
db('inv_blank', IMG[0x85D7:0x85E1])
db('colors_base', RES('colors.bin'))
db('floors', RES('floors.bin'), 7)


def vec(c):
    r, g, b = c
    return (round(b * 3 / 255) << 6) | (round(g * 7 / 255) << 3) | round(r * 7 / 255)


db('msx2vec', bytes(vec(c) for c in PAL))
pairs = []
for i in range(1, 16):
    for j in range(1, 16):
        if i != j:
            d = sum((x - y) ** 2 for x, y in zip(PAL[i], PAL[j]))
            pairs.append((d, i, j))
pairs.sort()
db('merge_pairs', bytes(x for _, i, j in pairs for x in (i, j)) + b'\xFF')
out.append('\t\tALIGN\t256')
db('tiles0', RES('tiles.bin')[:0x800])
os.makedirs(os.path.join(ROOT, 'src/vec/gen'), exist_ok=True)
open(os.path.join(ROOT, 'src/vec/gen/data.asm'), 'w').write('\n'.join(out) + '\n')
print('src/vec/gen/data.asm')
