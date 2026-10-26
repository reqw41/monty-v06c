#!/usr/bin/env python3
"""Каталог объектов комнат: build/res/objects.png и печать наборов тайлов.
Предмет K 20..28: тайлы T(1) T(2) / T(3) T(4); дверь 29..2B: закрытая T(1) x3 + T(2) столбцом, открытая 2x4 из T(3..);
враг 30..32: спрайт 16x16 — имя T(1), цвет T(0) (A405 -> атрибуты 7304+4n). T(n) = байт 9FD1 + ts + n."""
import os, sys
from PIL import Image, ImageDraw
sys.argv = sys.argv[:1]
exec(open(os.path.join(os.path.dirname(__file__), 'export_res.py')).read().split('# лист тайлов')[0])

def T(ts, n): return B(0x9FD1 + ts + n)
def cells(cl, floor=0):
    """cl: список строк номеров тайлов -> картинка"""
    nt = [0] * 768
    for r, row in enumerate(cl):
        for c, t in enumerate(row): nt[r * 32 + c] = t
    return render(nt, floor, rows=range(len(cl))).crop((0, 0, 8 * max(map(len, cl)), 8 * len(cl)))
def sprite(name, color):
    im = Image.new('RGB', (16, 16)); px = im.load()
    for x in range(16):
        for y in range(16):
            b = sprites[(name & 0xFC) * 8 + (x >> 3) * 16 + y]
            px[x, y] = PAL[color & 15] if b >> (7 - (x & 7)) & 1 else (0, 0, 0)
    return im

items = [(k, B(0x9444 + k)) for k in range(0x20, 0x29)]
doors = [(k, B(0x9444 + k)) for k in range(0x29, 0x2C)]
enemies = [(k, B(0x9444 + k)) for k in range(0x30, 0x33)]
sheet = Image.new('RGB', (15 * 40, 80), (50, 50, 50)); dr = ImageDraw.Draw(sheet)
x = 0
for k, ts in items:
    sheet.paste(cells([[T(ts, 1), T(ts, 2)], [T(ts, 3), T(ts, 4)]]).resize((32, 32), Image.NEAREST), (x + 4, 14))
    dr.text((x + 6, 2), f'{k:02X}', fill=(255, 255, 0)); print(f'предмет {k:02X} ts {ts:02X}:', IMG[0x9FD1 + ts:0x9FD1 + ts + 5].hex(' ')); x += 40
for k, ts in doors:
    sheet.paste(cells([[T(ts, 1)]] * 3 + [[T(ts, 2)]]).resize((16, 64), Image.NEAREST), (x + 2, 14))
    U = lambda n: T(ts, 2 + n)
    sheet.paste(cells([[U(1), U(2)]] + [[U(3), U(4)]] * 3).resize((32, 64), Image.NEAREST), (x + 20, 14) if False else (x + 20, 14))
    dr.text((x + 6, 2), f'{k:02X}', fill=(255, 255, 0)); print(f'дверь {k:02X} ts {ts:02X}:', IMG[0x9FD1 + ts:0x9FD1 + ts + 7].hex(' ')); x += 56
for k, ts in enemies:
    sheet.paste(sprite(T(ts, 1), T(ts, 0)).resize((32, 32), Image.NEAREST), (x + 4, 14))
    dr.text((x + 6, 2), f'{k:02X}', fill=(255, 255, 0)); print(f'враг {k:02X} ts {ts:02X}: цвет {T(ts, 0):02X} имя {T(ts, 1):02X}'); x += 40
sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save('build/res/objects.png')

# лист спрайтов: 64 шаблона 16x16 (имя = 4*номер), белым
sh = Image.new('RGB', (16 * 40, 4 * 44), (50, 50, 50)); dr = ImageDraw.Draw(sh)
for n in range(64):
    x, y = (n % 16) * 40, (n // 16) * 44
    sh.paste(sprite(n * 4, 15).resize((32, 32), Image.NEAREST), (x + 4, y + 11))
    dr.text((x + 4, y), f'{n * 4:02X}', fill=(255, 255, 0))
sh.save('build/res/sprites.png')
