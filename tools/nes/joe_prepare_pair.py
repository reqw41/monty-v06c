#!/usr/bin/env python3
"""Generate an isolated two-row Joe preparation experiment from the current loop.

The blob is placed at E000 only for the unit benchmark. It is not a game ROM:
normal tile construction owns that region. No production allocation is changed.
"""
from pathlib import Path
import re,argparse
root=Path(__file__).resolve().parents[2]
ap=argparse.ArgumentParser()
ap.add_argument('--baseline',default='build/nes-physics-checked')
ap.add_argument('--output',default='build/joe-prep-pair')
args=ap.parse_args()
out=root/args.output
out.mkdir(parents=True,exist_ok=True)
src=(root/'src/native/joe.asm').read_text()
block=src[src.index('joe_prepare:'):src.index('joe_put:')]
prefix,rest=block.split('jn_prep_row:',1)
row,tail=rest.split('jn_row_done:',1)
row='jn_prep_row:'+row
labels=set(re.findall(r'^([A-Za-z_]\w*):',block,re.M))
rowlabels=set(re.findall(r'^([A-Za-z_]\w*):',row,re.M))|{'jn_row_done'}
prelabels=labels-rowlabels

def rename(text,which=0):
 return re.sub(r'\b[A-Za-z_]\w*\b',lambda m:('p2_'+m[0]+str(which) if m[0] in rowlabels else 'p2_'+m[0] if m[0] in prelabels else m[0]),text)
a=rename(prefix)
lines=[]
for line in a.splitlines():
 lines.append(line)
 m=re.fullmatch(r'(\s*ld \()(p2_\w+)0(\+1\),[a-z]+)(.*)',line)
 if m:lines.append(m[1]+m[2]+'1'+m[3]+m[4])
a='\n'.join(lines)+'\n'
a=a.replace(' ld hl,p2_jn_third_column0\n ld (hl),0xC3',' ld hl,p2_jn_third_column0\n ld (hl),0xC3\n ld hl,p2_jn_third_column1\n ld (hl),0xC3')
a=a.replace(' ld (hl),0x01\np2_jn_third_ready:',' ld (hl),0x01\n ld hl,p2_jn_third_column0\n ld (hl),0x01\np2_jn_third_ready:')
a+=' ld a,(jn_rows_count)\n and 1\n jp nz,p2_jn_prep_row1\n'
rows=[]
for n in (0,1):
 b=rename(row,n).replace('ld (p2_jn_prep_source'+str(n)+'+1),hl','ld (p2_jn_prep_source'+str(1-n)+'+1),hl')
 t=rename('jn_row_done:'+tail[:tail.index('jn_prep_end:')],n).replace('ld (p2_jn_dest_read'+str(n)+'+1),a','ld (p2_jn_dest_read'+str(1-n)+'+1),a')
 if n==1:t+='p2_jn_prep_end:\n cp 0\n jp nz,p2_jn_prep_row0\n ret\n'
 rows.append(b+t)
sym=(root/args.baseline/'monty.sym').read_text()
asm='; Isolated real-i8080 experiment: the production ROM is untouched.\n DEVICE NOSLOT64K\n'
asm+='\n'.join(n+' equ 0x'+v for n,v in re.findall(r'^(\w+): EQU 0x([0-9A-F]+)',sym,re.M))+'\n ORG 0xE000\np2_begin:\n'
asm+=a+''.join(rows)+'p2_end:\n SAVEBIN "prep2.bin",p2_begin,p2_end-p2_begin\n'
(out/'prep2.asm').write_text(asm)
print('Generated paired-row experiment')
