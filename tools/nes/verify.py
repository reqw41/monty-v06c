#!/usr/bin/env python3
"""Validate extraction against ROM code and optional independent MAME dumps."""
import argparse,csv,json
from pathlib import Path
from assets import ROM,GROUPS
from cpu import CPU
from catalog import decode_rle

ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('rom',type=Path);ap.add_argument('output',type=Path);ap.add_argument('--reference',type=Path);a=ap.parse_args()
r=ROM(a.rom.read_bytes());checks={}
# Lossless decode of every CHR tile, including both bitplanes and bit order.
encoded=bytearray()
for tile in r.tiles:
    for bitplane in (0,1):
        for y in range(8):encoded.append(sum(((tile[y][x]>>bitplane)&1)<<(7-x) for x in range(8)))
assert bytes(encoded)==r.chr
checks['chr_roundtrip_tiles']=512
# Independent execution of the ROM OAM writer, both facing directions.
n=0
for group,(table,count) in GROUPS.items():
    for state in range(count):
        animation=r.w(table+2*state)
        for f in range(r.b(animation)):
            ptr=r.w(animation+6+2*f)
            for direction in (1,2):
                c=CPU(r.prg);m=c.mem;m[0x2e]=ptr&255;m[0x34]=ptr>>8;m[0x40]=direction;m[0x10]=64;m[0x16]=64;m[0x95]=2
                c.call(0xc40f)
                parts=r.meta(ptr,direction)
                expected=bytes(v for p in parts for v in ((p['y']+64)&255,p['tile'],p['attribute'],(p['x']+64)&255))
                assert m[0x200:0x200+len(expected)]==expected,(group,state,f,direction)
                assert m[0x7c]==len(parts)
                n+=1
checks['oam_views_against_rom_writer']=n
# Direct packet decoding vs execution of the original RLE routine.
for idx in range(99):
    c=CPU(r.prg);c.mem[0x792]=1;c.mem[0x794]=1;c.mem[0x79b]=idx;c.mem[0x79a]=__import__('math').isqrt(idx+1)
    c.call(0xbaff);c.mem[5:7]=c.mem[0x79c:0x79e];c.call(0xbd6a);c.call(0xbe5e);c.call(0xbe8c)
    assert c.ppu[0x20c0:0x23c0]==decode_rle(r,r.w(0xc601+2*idx))[0]
    assert c.ppu[0x23c0:0x2400]==decode_rle(r,r.w(0xc6c9+2*idx))[0]
checks['direct_rle_vs_rom_room_routines']=99
pal=json.loads((a.output/'data/palettes.json').read_text())
assert len(pal['variants'])==1782
assert all(len(v['palette'])==32 and max(v['palette'])<64 for v in pal['variants'])
checks['palette_cases']=1782
props=json.loads((a.output/'data/vector_proposals.json').read_text())
assert len(props)==8 and all(p['max_index']<=7 and len(p['palette_BBGGGRRR'])==8 for p in props)
checks['vector_mockups_8_indices']=8
# Stable MAME reference: redraw with captured game state (inventory, flags, level).
# Keep every static name-table cell and every attribute/palette entry in the comparison.
if a.reference:
    anim=json.loads((a.output/'data/animations.json').read_text())
    classes={t:i for i,v in enumerate(anim) for t in v['tiles']}
    comparisons=[]
    generated=json.loads((a.output/'data/rooms.json').read_text())['rooms']
    for file in sorted(a.reference.glob('*.ppu')):
        raw=file.with_suffix('.ram').read_bytes();ref=file.read_bytes();c=CPU(r.prg);c.mem[:2048]=raw
        c.call(0xbaff);c.mem[5:7]=c.mem[0x79c:0x79e];c.mem[0xf3]=0
        for pc in (0xbd6a,0xbe5e,0xbe8c,0x92b1,0xac9a,0xaceb,0xac54):c.call(pc)
        errors=[];animated=0
        for pos in range(0x20c0,0x23c0):
            v,w=c.ppu[pos],ref[pos]
            if v==w:continue
            if v in classes and w in classes and classes[v]==classes[w]:animated+=1
            else:errors.append((f'{pos:04X}',v,w))
        attrs=[f'{p:04X}' for p in range(0x23c8,0x2400) if (c.ppu[p]^ref[p]) & (0xf0 if p<0x23d0 else 0xff)]
        # HUD occupies rows 0..5; mask upper HUD quadrants in $23C8-CF.
        pbad=[f'{p:04X}' for p in range(0x3f00,0x3f10) if c.ppu[c.pa(p)]!=ref[p]]
        item=dict(name=file.stem,room=raw[0x79b],floor=raw[0x79a],static_errors=errors,attribute_errors=attrs,background_palette_errors=pbad,animated_phase_differences=animated)
        if file.stem.startswith('room_'):
            asset=generated[str(raw[0x79b])]
            assert asset['nametable']==list(ref[0x20c0:0x23c0]),('generated room field differs',file.stem)
            assert all(((asset['attributes'][p-0x23c0]^ref[p]) & (0xf0 if p<0x23d0 else 0xff))==0 for p in range(0x23c8,0x2400)),('generated room attributes differ',file.stem)
            assert asset['palette'][:16]==list(ref[0x3f00:0x3f10]),('generated room palette differs',file.stem)
        comparisons.append(item)
    checks['mame']=comparisons
    trace=a.reference/'timing.tsv'
    if trace.is_file():
        rows=list(csv.DictReader(trace.open(),delimiter='\t'));changes=[];last=None
        for row in rows:
            if not 60<=int(row['frame'])<120:continue
            v=int(row['fire_lower'])
            if last is not None and v!=last:changes.append(int(row['frame']))
            last=v
        checks['mame_fire_lower_change_frames_start_room']=changes
        checks['mame_fire_lower_intervals']=[b-a for a,b in zip(changes,changes[1:])]
    (a.output/'data/verification.json').write_text(json.dumps(checks,indent=2)+'\n')
    assert comparisons,'No reference dumps found'
    assert all(not(v['static_errors'] or v['attribute_errors'] or v['background_palette_errors']) for v in comparisons),str([(v['name'],len(v['static_errors']),v['attribute_errors'],v['background_palette_errors']) for v in comparisons if v['static_errors'] or v['attribute_errors'] or v['background_palette_errors']][:5])
else:(a.output/'data/verification.json').write_text(json.dumps(checks,indent=2)+'\n')
summary={k:v for k,v in checks.items() if k!='mame'}
if 'mame' in checks:summary['mame_comparisons_passed']=len(checks['mame'])
print(json.dumps(summary,indent=2))
