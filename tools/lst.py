#!/usr/bin/env python3
"""Фрагмент build/monty.skool по адресам: tools/lst.py A3CC [строк]  или  tools/lst.py A3CC-A4B5"""
import sys, re
a = sys.argv[1]; n = int(sys.argv[2]) if len(sys.argv) > 2 else 60
lo, hi = (int(x, 16) for x in a.split('-')) if '-' in a else (int(a, 16), None)
out, on, k = [], False, 0
for l in open('build/monty.skool'):
    m = re.match(r'^[cb*@ ]?\$([0-9A-F]{4})', l)
    if m:
        ad = int(m.group(1), 16)
        if not on and ad >= lo: on = True
        if on and hi is not None and ad > hi: break
    if on:
        if not l.strip(): continue
        out.append(l.rstrip().rstrip(';').rstrip()); k += 1
        if hi is None and k >= n: break
print('\n'.join(out))
