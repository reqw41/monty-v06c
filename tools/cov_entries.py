#!/usr/bin/env python3
"""Входы для Ghidra из покрытия: исполненные адреса (build/cov/*.json), не попавшие в код Ghidra
(build/ghidra/code_ranges.txt). Входом считается начало каждого непрерывного (с зазором до 4 байт) участка таких адресов;
запускать попеременно с tools/ghidra/run.sh до нулевого остатка. Пишет build/cov_entries.txt, печатает остаток."""
import json, glob
pcs = set()
for f in glob.glob('build/cov/*.json'): pcs |= set(json.load(open(f))['pc'])
code = set()
for l in open('build/ghidra/code_ranges.txt'):
    a, b = [int(x.split(':')[-1], 16) for x in l.split()]
    code.update(range(a, b + 1))
miss = sorted(p for p in pcs if p not in code)
old = open('build/cov_entries.txt').read().split() if glob.glob('build/cov_entries.txt') else []
ms = set(miss)
new = [p for p in miss if not any(q in ms for q in range(p - 4, p))]
ent = sorted(set(int(x, 16) for x in old) | set(new))
open('build/cov_entries.txt', 'w').write(' '.join(f'{p:04x}' for p in ent) + '\n')
print('исполнено', len(pcs), 'вне кода Ghidra', len(miss), 'входов', len(ent))
print(' '.join(f'{p:04x}' for p in miss[:60]))
