#!/usr/bin/env python3
"""Ресурсы игры в независимом виде (build/res/) и проверка рендером без модели.

  tools/export_res.py            — выгрузка + сверка рендера комнат со снимками модели
Выход:
  build/res/tiles.bin    шаблоны тайлов, 4 банка по 256 (фазы анимации): игра циклически ставит R4 = 0, 1, 2, 5
                         (VRAM 0000, 0800, 1000, 2800); банки отличаются от 0-го на 13-17 тайлов (огонь, верёвки и т. п.);
                         E0, E8 переписываются в банках (1D15 из AE34). В файле банки по порядку R4 = 0, 1, 2, 5
  build/res/sprites.bin  шаблоны 64 спрайтов 16x16 (VRAM 3800-3FFF, в игре не меняются)
  build/res/colors.bin   таблица цветов Graphics I (32 байта, по 8 тайлов на байт; старшая тетрада — цвет точек)
  build/res/floors.bin   палитры 9 этажей (93C0 + 7*этаж -> элементы цвета 1..7, FLOOR_PALETTE 8EB0)
  build/res/rooms_L<у>.json  комнаты уровня: таблица имён строк 5-23 (hex) и объекты (вид, клетка, код, набор)
  build/res/tiles.png, build/res/L<у>_<комната>.png — проверочные картинки
  build/res/map_L<у>.png — карта уровня (пирамида) только из ресурсов и декодера
Темнота (8EB0): при ряде >= 9 - уровень элементы цвета 0-2, 10-13, 15-18 := 0 (сверено, 297 из 297).
Элемент 1C (тайлы E0-E7) обнуляется игрой в комнатах 30, 37, 42, 44, 52, 83 — мигание (лазеры?), не данные комнаты.
Сверка: таблица имён модели в момент снимка, отрисованная из этих ресурсов с её цветами и R4, совпадает
с экраном модели без спрайтов по пикселям во всех 297 комнатах.
Источник тайлов/спрайтов/цветов — снимок openMSX game20 (build/runtime/game20_vram.bin).
"""
import json, os, sys
from PIL import Image
sys.argv = sys.argv[:1]
exec(open(os.path.join(os.path.dirname(__file__), 'roomdec.py')).read().split("if __name__")[0])

PAL = [(0, 0, 0), (0, 0, 0), (33, 200, 66), (94, 220, 120), (84, 85, 237), (125, 118, 252), (212, 82, 77), (66, 235, 245),
       (252, 85, 84), (255, 121, 120), (212, 193, 84), (230, 206, 128), (33, 176, 59), (201, 91, 186), (204, 204, 204), (255, 255, 255)]
os.makedirs('build/res', exist_ok=True)
vram = open('build/runtime/game20_vram.bin', 'rb').read()
BANKS = {0: 0, 1: 1, 2: 2, 5: 3}
tiles = b''.join(vram[r * 0x800:(r + 1) * 0x800] for r in BANKS)
sprites, colors = vram[0x3800:0x4000], bytearray(vram[0x2000:0x2020])
floors = IMG[0x93C0:0x93C0 + 63]
for n, d in (('tiles', tiles), ('sprites', sprites), ('colors', colors), ('floors', floors)):
    open(f'build/res/{n}.bin', 'wb').write(d)


def floor_colors(floor):
    col = bytearray(colors); col[1:8] = floors[7 * min(floor, 8):7 * min(floor, 8) + 7]
    return col


def render(nt, floor, rows=range(24), col=None, back=1, r4=0):
    """Прозрачный цвет 0 показывает фон (R7 VDP, обычно 1 — чёрный); r4 — фаза анимации (0, 1, 2, 5)."""
    bank = BANKS[r4 & 7]
    col = col or floor_colors(floor)
    im = Image.new('RGB', (256, 192))
    px = im.load()
    for r in rows:
        for c in range(32):
            t = nt[r * 32 + c]; cc = col[t >> 3]
            for y in range(8):
                b = tiles[bank * 0x800 + t * 8 + y]
                for x in range(8):
                    k = (cc >> 4) if b >> (7 - x) & 1 else (cc & 15)
                    px[c * 8 + x, r * 8 + y] = PAL[k or back]
    return im


# лист тайлов (цвета этажа 0)
sheet = Image.new('RGB', (16 * 18, 16 * 18), (64, 64, 64))
for t in range(256):
    nt = [t] * 768
    sheet.paste(render(nt, 0, rows=[0]).crop((0, 0, 8, 8)).resize((16, 16), Image.NEAREST), ((t % 16) * 18, (t // 16) * 18))
sheet.save('build/res/tiles.png')

bad = tot = 0
from collections import defaultdict
cdiff = defaultdict(list)
r7s = defaultdict(list)
for lv in (1, 2, 3):
    ref = json.load(open(f'build/rooms/nt_L{lv}.json'))
    out = {}
    for i, v in sorted(ref.items(), key=lambda x: int(x[0])):
        rm = decode(int(i), v['a6'], bytes.fromhex(v['bits']))
        out[i] = {'row': v['r'], 'col': v['c'], 'nt': bytes(rm.nt[0xA0:0x300]).hex(),
                  'objs': [[k, p, K, ts] for k, p, K, ts in rm.objs]}
        im = render(rm.nt, v['r'], rows=range(5, 24))
        if int(i) in (2, 12, 42, 90): im.resize((512, 384), Image.NEAREST).save(f'build/res/L{lv}_{i}.png')
        # сверка с экраном модели без спрайтов (tools/room_nt.js), строки 5-23, кроме клеток анимации E0/E8
        ref_rgb = open(f'build/rooms/rgb_L{lv}_{i}.bin', 'rb').read()
        now = bytes.fromhex(v['now'])         # таблица имён модели в момент её снимка (игра уже меняла клетки)
        mcol = bytes.fromhex(v['col'])
        mine = render(now, v['r'], rows=range(5, 24), col=bytearray(mcol), back=v['r7'] & 15, r4=v['r4']).tobytes(); diff = 0
        r7s[v['r7']].append(f'{lv}:{i}')
        fc = floor_colors(v['r'])
        cdiff[tuple(k for k in range(32) if mcol[k] != fc[k])].append(f'{lv}:{i}')
        for r in range(5, 24):
            for c in range(32):
                if now[r * 32 + c] in (0xE0, 0xE8): continue
                for y in range(8):
                    o = ((r * 8 + y) * 256 + c * 8) * 3
                    if mine[o:o + 24] != ref_rgb[o:o + 24]: diff += 1
        tot += 1
        if diff:
            bad += 1
            if bad <= 8: print(f'L{lv} комната {i}: расходятся {diff} строк тайлов')
    json.dump(out, open(f'build/res/rooms_L{lv}.json', 'w'))
    # карта уровня только из ресурсов и декодера (палитра этажа без темноты, фаза анимации 0)
    Wd, Hd = 128, 76
    pyr = Image.new('RGB', (19 * (Wd + 2), 9 * (Hd + 2)), (40, 40, 40))
    for i, o in out.items():
        nt = [8] * 0xA0 + list(bytes.fromhex(o['nt']))
        pyr.paste(render(nt, o['row'], rows=range(5, 24)).crop((0, 40, 256, 192)).resize((Wd, Hd)),
                  (o['col'] * (Wd + 2), o['row'] * (Hd + 2)))
    pyr.save(f'build/res/map_L{lv}.png')
print('шаблоны тайлов: рендер таблицы имён модели с её цветами совпал в', tot - bad, 'из', tot, 'комнат')
for k, rooms in r7s.items(): print(f'R7={k:02X}:', len(rooms), 'комнат', ' '.join(rooms[:10]))
for k, rooms in sorted(cdiff.items(), key=lambda x: -len(x[1])):
    print('цвета: отличаются элементы', [hex(x) for x in k] or 'нет', '—', len(rooms), 'комнат:', ' '.join(rooms[:12]), '...' if len(rooms) > 12 else '')
