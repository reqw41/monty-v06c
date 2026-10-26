#!/usr/bin/env python3
"""Сжатие начальных данных нативной сборки (распаковка — unpack в src/native/level.asm):
байт c < 80h — далее c + 1 байт как есть; 80h..FEh — следующий байт (c & 7Fh) + 2 раза; FFh — конец.
  build/native/ram0.bin (ОЗУ игры на входе в A59D) -> ram0.pk;  vram0.bin 0000-07FF (банк 0 шаблонов) -> pat0.pk"""
import os
ROOT = os.path.join(os.path.dirname(__file__), '..'); B = os.path.join(ROOT, 'build/native')
def pack(d):
    out = bytearray(); lit = bytearray(); i = 0
    def flush():
        nonlocal lit
        while lit: out.append(min(len(lit), 128) - 1); out.extend(lit[:128]); lit = lit[128:]
    while i < len(d):
        j = i
        while j < len(d) and d[j] == d[i] and j - i < 0x80: j += 1
        if j - i >= 3: flush(); out += bytes([0x80 + j - i - 2, d[i]]); i = j
        else: lit.append(d[i]); i += 1
    flush(); out.append(0xFF); return bytes(out)
def unpack(p):
    o = bytearray(); i = 0
    while p[i] != 0xFF:
        c = p[i]; i += 1
        if c < 0x80: o += p[i:i + c + 1]; i += c + 1
        else: o += bytes([p[i]]) * ((c & 0x7F) + 2); i += 1
    return bytes(o)
ram = bytearray(open(os.path.join(B, 'ram0.bin'), 'rb').read()); ram[0x340:0x3C0] = bytes(0x80)   # стек — не нужен
vram = open(os.path.join(B, 'vram0.bin'), 'rb').read()
for name, d in (('ram0', bytes(ram)), ('pat0', vram[:0x800])):
    p = pack(d); assert unpack(p) == d; open(os.path.join(B, name + '.pk'), 'wb').write(p); print(name, len(d), '->', len(p))
