#!/usr/bin/env python3
"""Full 32x24 NES field and original object coordinates for the native port.
Compile independent bit-LZ streams with five-bit literals and variable matches.
"""
from pathlib import Path
import json
from assets import ROM
from catalog import decode_rle
ROOT=Path(__file__).resolve().parents[2]

def pack(data, alphabet):
    """Bit LZ: 5-bit literals, near/far distances, variable run length."""
    from collections import defaultdict
    size=len(data);cost=[0]*(size+1);ops=[None]*size;index=defaultdict(list);candidates=[]
    for i in range(size):
        key=data[i:i+3];candidates.append(index[key][:]);index[key].append(i)
    for i in range(size-1,-1,-1):
        best=(6+cost[i+1],(1,0))
        for j in candidates[i]:
            distance=i-j;n=3
            while n<294 and i+n<size and data[j+n]==data[i+n]:n+=1
            dc=6 if distance<=32 else 10 if distance<=256 else 12
            for length in range(3,n+1):
                lc=3 if length<=6 else 7 if length<=38 else 10
                trial=1+dc+lc+cost[i+length]
                if trial<best[0]:best=(trial,(length,distance))
        cost[i],ops[i]=best
    bits=[]
    def put(v,n):bits.extend((v>>k)&1 for k in range(n-1,-1,-1))
    i=0
    while i<size:
        length,distance=ops[i]
        if not distance:put(0,1);put(alphabet.index(data[i]),5)
        else:
            put(1,1);d=distance-1
            if distance<=32:put(0,1);put(d,5)
            elif distance<=256:put(2,2);put(d,8)
            else:put(3,2);put(d,10)
            if length<=6:put(0,1);put(length-3,2)
            elif length<=38:put(2,2);put(length-7,5)
            else:put(3,2);put(length-39,8)
        i+=length
    bits.extend([0]*((-len(bits))%8))
    return bytes(sum(bits[i+k]<<(7-k) for k in range(8)) for i in range(0,len(bits),8))

def unpack(data, alphabet, size=768):
    out=bytearray();bit=0
    def get(n):
        nonlocal bit
        value=0
        for _ in range(n):value=(value<<1)|((data[bit//8]>>(7-bit%8))&1);bit+=1
        return value
    while len(out)<size:
        if not get(1):out.append(alphabet[get(5)]);continue
        d=get(5) if not get(1) else get(8) if not get(1) else get(10)
        n=3+get(2) if not get(1) else 7+get(5) if not get(1) else 39+get(8)
        for _ in range(n):out.append(out[-d-1])
    assert len(out)==size and (bit+7)//8==len(data)
    return bytes(out)

def objects(rom,index):
    p=rom.w(0xc791+2*index);result=[]
    while rom.b(p):
        t=rom.b(p)
        size=5 if t<=4 else 8 if 0x0e<=t<=0x10 else 6 if t>=0x11 else 9
        record=bytes(rom.b(p+i) for i in range(size));result.append(record);p+=size
        assert len(result)<40,(index,hex(p))
    return result

def main():
    rom=ROM((ROOT/'orig/nes/monty.nes').read_bytes())
    # Semantic IDs preserve the established native collision/pickup routines.
    native={0:8,1:11,2:0xd6,3:0xd7,0x17:0,0xc:0x90,0xd:0x95,0xe:0xcc,
            0xf:0x10,0x10:0x11,0x11:0x88,0x12:0x89,0x13:0xc8,0x14:0xc9,
            0x15:0xca,0x16:0xcb}
    native.update({i:0x38 for i in range(0x1c,0x20)})
    native.update({0x18+i:0xd2+i for i in range(4)})
    native.update({i:0xe0 for i in range(0x2d,0x35)})
    native.update({i:0xe8 for i in range(0x35,0x39)})
    native.update({i:4+(i-0x3c)%3 for i in range(0x3c,0x48)})
    native.update({0x39:0xc0,0x3a:0xb0,0x3b:0xbb})
    for start,ids in [(0x56,[0xc1,0xc2,0xc3,0xc5]),(0x5a,[0xb1,0xb2,0xb3,0xb4]),(0x5e,[0xbc,0xbd,0xbe,0xbf])]:
        native.update({start+i:t for i,t in enumerate(ids)})
    # Base fields contain no pickups; objects are applied separately by flags.
    streams={};indices=[];records=[];fields=[]
    for idx in range(99):
        raw,_=decode_rle(rom,rom.w(0xc601+2*idx))
        assert len(raw)==768
        missing=set(raw)-native.keys();assert not missing,(idx,missing)
        values=[native[t] for t in raw]
        for pos,t in enumerate(raw):
            if t in (0x39,0x3a,0x3b) and (pos+32>=768 or raw[pos+32]!=t):values[pos]={0x39:0xc7,0x3a:0xb7,0x3b:0x9c}[t]
            if t==0x0e and (pos+32>=768 or raw[pos+32]!=t):values[pos]=0xcd
        field=bytes(values)
        fields.append(field)
        records.append(dict(index=idx,native=list(field),nes=list(raw),objects=[list(b) for b in objects(rom,idx)]))
    literals=sorted(set(b''.join(fields)));assert len(literals)<=32
    for field in fields:
        data=pack(field,literals);assert unpack(data,literals)==field
        indices.append(streams.setdefault(data,f'nf_room_{len(streams)}'))
    # Two-byte position records with a shared type dictionary. Visibility is
    # sticky (normally $90), so only changes consume a prefix. No game data is
    # inferred from a rendered screenshot.
    lists={};obj_indices=[];types={}
    changes={0x11:8,0x12:11,0x13:0xe0,0x14:0x88,0x15:0x89,0x16:0x10,0x17:0x11,0x18:0}
    for room in records:
        data=bytearray();last_visibility=0x90
        for rec in room['objects']:
            kind=rec[0];visible=rec[-1]
            if (visible&15)>=(visible>>4):continue
            if kind<=4:
                pos=rec[2]*32+rec[1];flags=rec[3]
            elif kind>=0x11:
                assert kind in changes,(room['index'],rec)
                pos=(rec[1]|rec[2]<<8)-0x2000;flags=changes[kind];kind=0x80
            else:
                pos=(rec[1]|rec[2]<<8)-0x2000;flags=0
            assert 0<=pos<1024,(room['index'],rec,pos)
            type_id=types.setdefault((kind,flags),len(types)+1)
            assert type_id<63
            if visible!=last_visibility:data.extend((255,visible));last_visibility=visible
            data.extend(((type_id<<2)|(pos>>8),pos&255))
        data.append(0);obj_indices.append(lists.setdefault(bytes(data),f'nf_objects_{len(lists)}'))
    asm=['; Generated from original NES fields and object streams; 256x240, no scaling.','nf_rooms:']
    for i in range(0,99,8):asm.append(' dw '+','.join(indices[i:i+8]))
    asm+=['nf_object_lists:']
    for i in range(0,99,8):asm.append(' dw '+','.join(obj_indices[i:i+8]))
    for group in (streams,lists):
        for data,label in group.items():
            asm.append(label+':')
            for i in range(0,len(data),24):asm.append(' db '+','.join(map(str,data[i:i+24])))
    hud=[0]*192
    for c in range(1,12):hud[32+c]=0xfa;hud[160+c]=0xfb
    for c in range(18,31):hud[32+c]=0xfa;hud[160+c]=0xfb
    for y in range(1,6):
        for x,t in [(0,0xf8),(12,0xf9),(17,0xf9),(31,0xf8)]:hud[y*32+x]=t
    hud[32+17]=0xfd;hud[160+17]=0xfc
    hud_rle=[];i=0
    while i<len(hud):
        j=i+1
        while j<len(hud) and hud[j]==hud[i] and j-i<255:j+=1
        hud_rle.extend((j-i,hud[i]));i=j
    asm+=['nf_hud_rle: db '+','.join(map(str,hud_rle+[0])), 'nf_literals: db '+','.join(map(str,literals))]
    asm+=['nf_type_kind: db 0,'+','.join(str(k) for k,f in types), 'nf_type_flags: db 0,'+','.join(str(f) for k,f in types), 'nf_rooms_end:']
    (ROOT/'src/native/gen/rooms_full.asm').write_text('\n'.join(asm)+'\n')
    out=ROOT/'build/nes_full';out.mkdir(parents=True,exist_ok=True)
    report=dict(rooms=99,unique_fields=len(streams),field_bytes=sum(map(len,streams)),object_bytes=sum(map(len,lists)),unique_object_lists=len(lists),types=len(types),rows=30,field_rows=24,hud_rows=6,coordinates='original NES; no scaling',records=records)
    (out/'rooms.json').write_text(json.dumps(report,indent=2)+'\n')
    print({k:v for k,v in report.items() if k!='records'})
if __name__=='__main__':main()
