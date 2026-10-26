#!/usr/bin/env python3
"""Черновой control-файл SkoolKit из разметки Ghidra (build/ghidra/code_ranges.txt):
код в областях ОЗУ 0000-25AE и картриджа 8000-BFFF — блоки 'c', остальное — 'b'.
Одиночные команды вне этих областей и в данных (B102, B104, E804) — ложные срабатывания автоанализа.
Пишет build/auto.ctl. Рабочий, размечаемый руками файл — src/monty.ctl (заводится из auto.ctl один раз)."""
AREAS = [(0x0000, 0x25AE), (0x8000, 0xBFFF)]
FALSE = {0xB102, 0xB104, 0xE804}
rng = []
for l in open('build/ghidra/code_ranges.txt'):
    a, b = [int(x.split(':')[-1], 16) for x in l.split()]
    if a in FALSE: continue
    for lo, hi in AREAS:
        if lo <= a <= hi: rng.append((a, min(b, hi)))
rng.sort()
out = ['@ $0000 org', '@ $0000 start']
pos = 0
for a, b in rng:
    if a > pos: out.append(f'b ${pos:04X}')
    out.append(f'c ${a:04X}'); pos = b + 1
out.append(f'b ${pos:04X}')
out.append('i $10000')
open('build/auto.ctl', 'w').write('\n'.join(out) + '\n')
print(len(out), 'строк')
