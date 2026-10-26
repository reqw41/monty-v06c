#!/usr/bin/env python3
"""Декодер описаний комнат (повтор A067 картриджа Coleco) -> таблица имён 32x24.

  tools/roomdec.py check            — сверка со снимками модели build/rooms/nt_L{1,2,3}.json
  tools/roomdec.py dump <комната> [уровень]   — записи описания с вложенностью

Формат (адреса — образ build/monty_entry.bin):
  Таблица 9477: слово на комнату/подописание i — начало потока; конец = начало i+1.
  Запись: байт кода K, далее параметры p1 p2 p3 (длина записи 1..4 — по виду).
    позиция клетки = ((K >> 6) & 3) << 8 | p1   (0..3FF, строка = поз >> 5)
    набор тайлов ts = 9444[K & 3F]; T(k) = байт 9FD1 + ts + k
  (K & 3E) == 3E — вызов подописания p (байт после кода), K & 1 — зеркалировать по возврату (AB29);
     длина 2. Возврат — по концу потока; вложенность — стек.
  K & 3F == 10 / 11 — конец текущего потока, если уровень (71A6) < 2/6 + ((K >> 6) & 3); иначе длина 1.
  K & 3F == 0B — столбец ширины T(0) из тайлов T(1..), 4 строки; длина 2.
  K & 3F < 20 — примитив по (K >> 2) & 7 (таблица A20A):
     0,4 A21A  прямоугольник тайла T(1): K&1 ? (ширина p2, высота p3, длина 4) : (p2 >> 4, p2 & F, длина 3)
     1,5 A27C  треугольник: прямоугольник T(3) p2 x p2 (K&10: высота 2*p2), поверх лесенка T(1)
               ширинами p2-1..1 по 1 (K&10: по 2) строки, со сдвигом вправо при K&1
     2   A2F0  столбец ширины T(0) из тайлов T(1..T(0)), p2 строк
     3   A318  полоса p2 клеток: T(1) x p2, затем T(2) x (p2-1), затем T(3) x 1 — с начала полосы
     6   A30E  как 2, затем верхняя строка — следующие T(0) тайлов
     7   A340  T(0) == FF ? p2 подряд идущих тайлов T(1..) : p2 раз подряд узор T(1..T(0))
  K & 3F 20..28 — предмет 2x2 (T(1) T(2) / T(3) T(4)), если ещё не взят; длина 2
  K & 3F 29..2F — дверь: T(1) в трёх клетках столбца, T(2) под ними (открытая — 2x4 из T(3..)); длина 2
  K & 3F >= 30 — враг-спрайт (A405, в таблицу имён не пишет); длина 2. Спрайт 2+n (атрибуты 7304 + 4n, n = 1..):
     Y = A496[p1 & F] (паук ts 86: -2), X = A4A5[p1 >> 4], имя T(1), цвет T(0); список 7086 — пары
     (n + 1 + поведение, K&40 ? 80 : 0), поведение 48 паук (ts 86), 10 (ts 88), 08 (ts 8A, череп)
  Объекты (20..3F) обрабатываются только на верхнем уровне (глубина 7194 = 0), в подописаниях пропускаются;
  у каждого свой бит «взят/открыт» в 70C0 + 2*комната (n-й объект: байт n//8, бит n%8; A514).
Перед потоком A1DF: строки 5-23 := 0, строки 0-4 := 8 (рамка инвентаря рисуется отдельно).
"""
import sys, json

IMG = open('build/monty_entry.bin', 'rb').read()
B = lambda a: IMG[a & 0xFFFF]
W = lambda a: B(a) | B(a + 1) << 8

ROW = [0xF8, 0xFC, 0x02, 0x0A, 0x14, 0x20, 0x2E, 0x3E, 0x50]   # A4C5


def room_index(r, c):
    return (ROW[r] + c) & 0xFF


def mirror_pairs():
    """Пары тайлов для зеркалирования (AB0C): [исходный, зеркальный], конец — FF."""
    p, a = {}, 0xAB0C
    while B(a) != 0xFF:
        p[B(a)] = B(a + 1); a += 2
    return p


class Room:
    def __init__(self, level, idx, taken=None):
        self.level = level
        self.taken = taken or bytes(0xD0)   # флаги 70C0..: бит n объекта комнаты i — байт 2i + n//8
        self.base = 2 * idx                 # 71A1: по комнате верхнего уровня (подописания не меняют)
        self.count = 0                      # 71A2: общий счётчик предметов, дверей и врагов
        self.nt = [0] * 0x400            # с запасом: запись за 2FF уходит в таблицу атрибутов спрайтов
        self.nt[0:0xA0] = [8] * 0xA0
        hud(self.nt, level, 0, b'', [])
        self.objs = []                   # (вид, позиция, K, ts)
        self.enemies = []                # A405: (Y, X, имя спрайта, цвет, поведение для 7086, флаг 80)
        self.trace = []

    def put(self, pos, tiles):
        for i, t in enumerate(tiles):
            self.nt[(pos + i) & 0x3FF] = t

    def run(self, idx, depth=0, mirror=0, parent_mirror=0):
        p, end = W(0x9477 + 2 * idx), W(0x9477 + 2 * idx + 2)
        while p < end:
            K = B(p); p1, p2, p3 = B(p + 1), B(p + 2), B(p + 3)
            k = K & 0x3F
            self.trace.append((depth, p, K, p1, p2, p3))
            if (K & 0x3E) == 0x3E:
                sub = B(p + mirror + 1)
                self.run(sub, depth + 1, K & 1, mirror)
                if K & 1:
                    self.mirror()
                p += 2; continue
            if k in (0x10, 0x11):
                if self.level < (2 if k == 0x10 else 6) + ((K >> 6) & 3):
                    return
                p += 1; continue
            pos = ((K >> 6) & 3) << 8 | p1
            ts = B(0x9444 + k)
            T = lambda n: B(0x9FD1 + ts + n)
            if k == 0x0B:
                w = T(0)
                for r in range(4): self.put(pos + 32 * r, [T(1 + i) for i in range(w)])
                p += 2; continue
            if k < 0x20:
                h = (k >> 2) & 7
                if h in (0, 4):
                    if K & 1: wd, ht, ln = p2, p3, 4
                    else: wd, ht, ln = p2 >> 4, p2 & 15, 3
                    for r in range(ht): self.put(pos + 32 * r, [T(1)] * wd)
                    p += ln; continue
                if h in (1, 5):
                    tall = 2 if K & 0x10 else 1
                    for r in range(p2 * tall): self.put(pos + 32 * r, [T(3)] * p2)
                    q = pos + (1 if K & 1 else 0)
                    n = p2
                    while True:
                        n -= 1
                        if n == 0: break
                        for r in range(tall): self.put(q + 32 * r, [T(1)] * n)
                        q += 32 * tall + (1 if K & 1 else 0)
                    p += 3; continue
                if h in (2, 6):
                    w = T(0)
                    for r in range(p2): self.put(pos + 32 * r, [T(1 + i) for i in range(w)])
                    if h == 6: self.put(pos, [T(1 + w + i) for i in range(w)])
                    p += 3; continue
                if h == 3:
                    self.put(pos, [T(1)] * p2)
                    self.put(pos, [T(2)] * (p2 - 1))
                    self.put(pos, [T(3)])
                    p += 3; continue
                if h == 7:
                    if T(0) == 0xFF: self.put(pos, [T(1 + i) for i in range(p2)])
                    else:
                        w = T(0)
                        self.put(pos, [T(1 + i) for i in range(w)] * p2)
                    p += 3; continue
            if depth > 0:                    # A150/A15D/A169: объекты только в описании самой комнаты
                p += 2; continue
            n = self.count; self.count += 1
            gone = self.taken[(self.base + n // 8) & 0xFF] >> (n % 8) & 1 if self.base + n // 8 < len(self.taken) else 0
            if k < 0x29 and gone:
                pass
            elif k < 0x29:
                self.objs.append(('предмет', pos, K, ts))
                self.put(pos, [T(1), T(2)]); self.put(pos + 32, [T(3), T(4)])
            elif k < 0x30 and gone:
                self.objs.append(('дверь открыта', pos, K, ts))
                U = lambda n: B(0x9FD1 + ts + 2 + n)
                self.put(pos, [U(1), U(2)])
                for r in range(1, 4): self.put(pos + 32 * r, [U(3), U(4)])
            elif k < 0x30:
                self.objs.append(('дверь', pos, K, ts))
                for r in range(3): self.put(pos + 32 * r, [T(1)])
                self.put(pos + 96, [T(2)])
            elif not gone:
                self.objs.append(('враг', pos, K, ts))
                y = B(0xA496 + (p1 & 15)); x = B(0xA4A5 + (p1 >> 4))
                if ts == 0x86: y -= 2; beh = 0x48     # паук
                elif ts == 0x88: beh = 0x10
                else: beh = 0x08
                self.enemies.append((y, x, T(1), T(0), beh, 0x80 if K & 0x40 else 0))
            p += 2

    def mirror(self):
        pairs = mirror_pairs()
        for r in range(5, 24):
            row = self.nt[r * 32:(r + 1) * 32]
            row = [pairs.get(t, t) if t not in (0, 8) else t for t in row]
            self.nt[r * 32:(r + 1) * 32] = row[::-1]


def hud(nt, level, lives, score, inv):
    """Строки 0-4: рамка AA5D (рисует CLEAR_ROOM до потока) и после потока A548: счёт и уровень (AEFE),
    инвентарь (список наборов тайлов 71B2.., конец FF) 2x2 с клетки 21h, жизни-1 шляп (тайл 6F, AABB)."""
    def put(pos, t): nt[pos] = t
    for i in range(10): put(1 + i, 0x09); put(0x81 + i, 0x0C)
    for i in range(8): put(0x17 + i, 0x09); put(0x97 + i, 0x0C)
    for r in range(3):
        for i, t in enumerate(IMG[0xAA88:0xAA94]): put(0x20 + 32 * r + i, t)
        for i, t in enumerate(IMG[0xAA89:0xAA93]): put(0x36 + 32 * r + i, t)
    return nt


def hud_after(nt, level, lives, score, inv):
    """Часть интерфейса после потока (A548): счёт, уровень, инвентарь, жизни."""
    z = False
    for k, pos, base in ((0, 0x38, 0x18), (1, 0x58, 0x28)):
        z = False
        for i, b in enumerate(score):
            for j, d in enumerate((b >> 4, b & 15)):
                if d or z: nt[pos + 2 * i + j] = base + d; z = True
                else: nt[pos + 2 * i + j] = 0          # ведущий ноль — пустой тайл (AF65 -> AF66)
    nt[0x34] = 0x18 + level; nt[0x54] = 0x28 + level
    for r in range(3):
        for i in range(10): nt[0x21 + 32 * r + i] = B(0x85D7 + i)
    pos = 0x21
    for ts in inv:
        if ts == 0xFF: break
        T = lambda n: B(0x9FD1 + ts + n)
        nt[pos], nt[pos + 1], nt[pos + 32], nt[pos + 33] = T(1), T(2), T(3), T(4); pos += 2
    for i in range(8): nt[0x61 + i] = 0; nt[0x77 + i] = 0
    n = lives - 1
    if n > 0:
        for i in range(min(n, 10)): nt[0x61 + i] = 0x6F
        if n >= 11:
            for i in range(min(n - 10, 8)): nt[0x77 + i] = 0x6F
    return nt


def decode(idx, level, taken=None):
    rm = Room(level, idx, taken); rm.run(idx); return rm


def check():
    total = bad = 0
    for lv in (1, 2, 3):
        ref = json.load(open(f'build/rooms/nt_L{lv}.json'))
        for i, v in sorted(ref.items(), key=lambda x: int(x[0])):
            nt = bytes.fromhex(v['nt'])
            rm = decode(int(i), v['a6'], bytes.fromhex(v['bits']))
            d = [a for a in range(0xA0, 0x300) if rm.nt[a] != nt[a]]
            total += 1
            if d:
                bad += 1
                if bad <= 12:
                    a = d[0]
                    print(f'L{lv} комната {i}: {len(d)} клеток, первая {a:03X} (строка {a >> 5}, столбец {a & 31}): '
                          f'декодер {rm.nt[a]:02X}, модель {nt[a]:02X}')
    print(f'совпало {total - bad} из {total} (строки 5-23)')
    hb = 0
    for lv in (1, 2, 3):
        ref = json.load(open(f'build/rooms/nt_L{lv}.json'))
        for i, v in ref.items():
            nt = bytes.fromhex(v['nt']); h = v['hud']
            rm = decode(int(i), v['a6'], bytes.fromhex(v['bits']))
            mine = hud_after(rm.nt, v['a6'], h['lives'], bytes.fromhex(h['score']), bytes.fromhex(h['inv']))
            d = [a for a in range(0xA0) if mine[a] != nt[a]]
            if d:
                hb += 1
                if hb <= 6: print(f'интерфейс L{lv} {i}: {len(d)} клеток, первая {d[0]:02X}: {mine[d[0]]:02X} вместо {nt[d[0]]:02X}')
    print(f'строки 0-4: совпало {297 - hb} из 297')
    eb = 0
    for lv in (1, 2, 3):
        ref = json.load(open(f'build/rooms/nt_L{lv}.json'))
        for i, v in ref.items():
            rm = decode(int(i), v['a6'], bytes.fromhex(v['bits']))
            spr, act = bytes.fromhex(v['spr']), bytes.fromhex(v['act'])
            exp_spr = b''.join(bytes([y, x, nm, cl]) for y, x, nm, cl, _, _ in rm.enemies)
            exp_act = b''.join(bytes([n + 2 + beh, fl]) for n, (_, _, _, _, beh, fl) in enumerate(rm.enemies))
            if spr[8:8 + len(exp_spr)] != exp_spr or act[:len(exp_act)] != exp_act or v['cnt'] != len(rm.enemies) \
               or act[len(exp_act):len(exp_act) + 1] not in (b'\xff', b''):
                eb += 1
                if eb <= 6: print(f'враги L{lv} {i}: декодер', exp_spr.hex(), exp_act.hex(), 'модель', spr[8:24].hex(), act.hex(), v['cnt'])
    print(f'враги: совпало {297 - eb} из 297')


if __name__ == '__main__':
    if sys.argv[1] == 'check': check()
    elif sys.argv[1] == 'dump':
        rm = decode(int(sys.argv[2]), int(sys.argv[3]) if len(sys.argv) > 3 else 1)
        for d, p, K, a, b, c in rm.trace: print('  ' * d + f'{p:04X}: {K:02X}  {a:02X} {b:02X} {c:02X}')
        for o in rm.objs: print(o[0], f'{o[1]:03X} K={o[2]:02X} ts={o[3]:02X}')
