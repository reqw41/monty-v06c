#!/usr/bin/env python3
"""Сверка этапа 1: снимки tools/vroom.js против декодера (tools/roomdec.py) и ресурсов MSX.
  tools/vcheck.py [уровни]  -> печать итогов, build/vec/rooms/map_L<у>.png (экраны Вектора пирамидой)
Проверяется: 1) таблица имён Вектора = декодер + интерфейс (счёт 0, 6 жизней, пустой инвентарь);
2) пиксели: индекс Вектора = cmap[цвет MSX] (тайлы банка 0, палитра этажа, темнота; 0 -> 1);
3) слияния: сколько цветов MSX отображено в чужой индекс (cmap[c] занят другим цветом)."""
import os, sys
from PIL import Image
sys.argv = sys.argv[:2]
exec(open('tools/roomdec.py').read().split("if __name__")[0])
tiles = open('build/res/tiles.bin', 'rb').read()[:0x800]
colors = open('build/res/colors.bin', 'rb').read()
floors = open('build/res/floors.bin', 'rb').read()
DARK = (0, 1, 2, 0x10, 0x11, 0x12, 0x13, 0x15, 0x16, 0x17, 0x18)
RB = [-8, -4, 2, 10, 20, 32, 46, 62, 80]
levels = [int(x) for x in (sys.argv[1] if len(sys.argv) > 1 else '1,2,3').split(',')]


def vcol(b):
    return ((b & 7) * 36, ((b >> 3) & 7) * 36, (b >> 6) * 85)


for lv in levels:
    ok_nt = ok_px = 0; merged = {}; n = 0
    PW, PH = 128, 96
    pyr = Image.new('RGB', (19 * (PW + 2), 9 * (PH + 2)), (40, 40, 40))
    for r in range(9):
        for c in range(8 - r, 11 + r):
            i = RB[r] + c; n += 1
            d = open(f'build/vec/rooms/L{lv}_{i}.bin', 'rb').read()
            vnt, cmap, pal, px = d[:768], d[768:784], d[784:800], d[800:]
            rm = decode(i, lv)
            exp = bytes(hud_after(rm.nt, lv, 6, b'\0\0\0', b'\xff')[:768])
            ok_nt += vnt == exp
            col = bytearray(colors); f = min(r, 8); col[1:8] = floors[7 * f:7 * f + 7]
            if r >= 9 - lv:
                for g in DARK: col[g] = 0
            bad = 0
            for y in range(192):
                for x in range(256):
                    t = exp[(y >> 3) * 32 + (x >> 3)]; cb = col[t >> 3]
                    k = (cb >> 4) if tiles[t * 8 + (y & 7)] >> (7 - (x & 7)) & 1 else (cb & 15)
                    if cmap[k or 1] != px[y * 256 + x]: bad += 1
            ok_px += bad == 0
            owners = {}
            for k in range(1, 16): owners.setdefault(cmap[k], []).append(k)
            m = sum(len(v) - 1 for v in owners.values() if len(v) > 1)
            # слито только среди реально видимых — грубо: число индексов меньше числа цветов
            im = Image.new('RGB', (256, 192)); im.putdata([vcol(pal[2 * px[q]]) for q in range(256 * 192)])
            pyr.paste(im.resize((PW, PH)), (c * (PW + 2), r * (PH + 2)))
    pyr.save(f'build/vec/rooms/map_L{lv}.png')
    print(f'уровень {lv}: таблица имён совпала {ok_nt}/{n}, пиксели совпали {ok_px}/{n}')
