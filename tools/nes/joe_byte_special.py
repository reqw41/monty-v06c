#!/usr/bin/env python3
"""Build isolated byte-specialized Joe put routines; do not change a game ROM.

Transparent/opaque paths still save both original background bytes. They share
existing column restoration code; only their A-plane page needs extra patching.
"""
from pathlib import Path
import argparse,re,json
ROOT=Path(__file__).resolve().parents[2]
ap=argparse.ArgumentParser();ap.add_argument('--baseline',default='build/nes-physics-checked');ap.add_argument('--output',default='build/joe-byte-special');ap.add_argument('--mode',choices=['transparent','opaque','transparent-first','opaque-first'],default='transparent-first');a=ap.parse_args()
out=ROOT/a.output/a.mode;out.mkdir(parents=True,exist_ok=True)
source=(ROOT/'src/native/joe.asm').read_text();original=source[source.index('joe_put:'):source.index('joe_restore:')]
block=original.replace('NES_JOE_BLEND_MODE equ 1','')
handlers=[]
for i,entry in enumerate(['jn_put_two','jn_put_two_second']):
 types=['t'] if a.mode=='transparent' else ['o'] if a.mode=='opaque' else ['t','o'] if a.mode=='transparent-first' else ['o','t']
 checks=[' pop bc',' ld a,c']
 if types[0]=='t':
  checks+=[' inc a',f' jp z,sp_t{i}']
  if 'o' in types:checks+=[' dec a',f' jp z,sp_o{i}']
 else:
  checks+=[' or a',f' jp z,sp_o{i}']
  if 't' in types:checks+=[' inc a',f' jp z,sp_t{i}']
 old=entry+':\n pop bc\n';assert old in block;block=block.replace(old,entry+':\n'+'\n'.join(checks)+'\n',1)
 for kind in types:
  h=[f'sp_{kind}{i}:',' ld a,(hl)',' ld (de),a']
  if kind=='o':h+=[' ld (hl),b']
  h+=[' inc e',f'sp_{kind}_a{i}:',' ld h,0xA0',' pop af']
  if kind=='o':h+=[' ld b,a']
  h+=[' ld a,(hl)',' ld (de),a']
  if kind=='o':h+=[' ld (hl),b']
  h+=[' inc e',f' jp jn_two_c{i}']
  handlers.extend(h)
  # Patch once per column, exactly like the existing row-specific page values.
  old=' ld (jn_two_a1+1),a\n';assert old in block;block=block.replace(old,old+f' ld (sp_{kind}_a{i}+1),a\n',1)
block+='\n'+'\n'.join(handlers)+'\n'
labels=set(re.findall(r'^(\w+):',block,re.M));name=lambda n:'special_'+n if n in labels else n
block=re.sub(r'\b[A-Za-z_]\w*\b',lambda m:name(m[0]),block)
symbols=(ROOT/a.baseline/'monty.sym').read_text()
asm='; Isolated real-i8080 Joe byte specialization experiment.\n DEVICE NOSLOT64K\n'
asm+='\n'.join(n+' equ 0x'+v for n,v in re.findall(r'^(\w+): EQU 0x([0-9A-F]+)',symbols,re.M))+'\n ORG 0xE000\nspecial_begin:\n'+block+'special_end:\n SAVEBIN "put.bin",special_begin,special_end-special_begin\n'
(out/'put.asm').write_text(asm)
(out/'config.json').write_text(json.dumps({'mode':a.mode,'baseline':a.baseline,'isolated':True})+'\n')
print(out)
