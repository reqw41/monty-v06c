#!/usr/bin/env python3
"""Неизменяемые исходные полосы тайлов для построения графики комнаты.
Запуск после tools/vsnap.js; все указатели — в исходники, экранных копий нет.
"""
from pathlib import Path
R = Path(__file__).resolve().parent.parent
v = (R/'build/native/vram.bin').read_bytes()
v0 = (R/'build/native/vram0.bin').read_bytes()
a = [4,5,6,0x38,0xA0,0xA3,0xA4,0xA7,0xB8,0xB9,0xBA,0xD0,0xD1,0xD2,0xD3,0xD4,0xD5]
strips = {}
def ptr(b):
    if b not in strips: strips[b] = 'raw_%03d' % len(strips)
    return strips[b]
base = [ptr(v0[t*8:t*8+8]) for t in range(256)]
frames = [ptr((v0 if f==0 else v)[b+t*8:b+t*8+8]) for t in a for f,b in enumerate([0,0x800,0x1000,0x2800])]
out = ['; Создано tools/mkvideo.py; неизменяемые полосы (дедупликация по 8 байт).',
       'anim_set: db '+','.join(map(str,a))+',255',
       'col0: db '+','.join(map(str,v0[0x2000:0x2020])), 'raw_base:']
for i in range(0,256,8): out += [' dw '+','.join(base[i:i+8])]
out += ['raw_anim:']
for i in range(0,len(frames),4): out += [' dw '+','.join(frames[i:i+4])]
changes = {}
transitions = []
for old in range(4):
    for new in range(4):
        changed = tuple(t for i,t in enumerate(a) if frames[4*i+old] != frames[4*i+new])
        if changed not in changes: changes[changed] = 'fire_delta_%d' % len(changes)
        transitions.append(changes[changed])
out += ['fire_transitions:']
for i in range(0,16,4): out += [' dw '+','.join(transitions[i:i+4])]
for changed,label in changes.items(): out += [label+': db '+','.join(map(str,changed+(255,)))]
for b,label in strips.items(): out += [label+': db '+','.join(map(str,b))]
(R/'src/native/gen/video.asm').write_text('\n'.join(out)+'\n')
print('Исходных полос:',len(strips),'байт графики:',8*len(strips))
