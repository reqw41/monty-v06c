#!/usr/bin/env python3
"""Full 32x24 NES field and original object coordinates for the native port.
Compile independent bit-LZ streams with prefix-class codes (see DIST_CLASSES).
"""
from pathlib import Path
import json
from assets import ROM
from catalog import decode_rle
ROOT=Path(__file__).resolve().parents[2]

# Prefix-class codes shared with nf_unpack (drawroom_nes.asm): class k is
# k one-bits then a zero (the last class has no zero), then BITS value bits;
# value+base. Distance base 1, length base 3.
DIST_CLASSES=((5,1),(8,33),(10,289))
LEN_CLASSES=((3,3),(4,11),(8,27))
# Literal after a 0 token bit: 0 -> tile 08, 10 -> tile 00, 11 + 5 bits -> alphabet.
def class_bits(classes,v):
    for k,(bits,base) in enumerate(classes):
        if base<=v<base+(1<<bits):return k+(k<len(classes)-1)+bits
    return None
def lit_bits(t):return 2 if t==8 else 3 if t==0 else 8

def pack(data, alphabet):
    """Bit LZ with optimal parse over the prefix-class codes above."""
    from collections import defaultdict
    size=len(data);cost=[0]*(size+1);ops=[None]*size;index=defaultdict(list);candidates=[]
    maxlen=LEN_CLASSES[-1][1]+(1<<LEN_CLASSES[-1][0])-1
    for i in range(size):
        key=data[i:i+3];candidates.append(index[key][:]);index[key].append(i)
    for i in range(size-1,-1,-1):
        best=(lit_bits(data[i])+cost[i+1],(1,0))
        for j in candidates[i]:
            distance=i-j;dc=class_bits(DIST_CLASSES,distance)
            if dc is None:continue
            n=3
            while n<maxlen and i+n<size and data[j+n]==data[i+n]:n+=1
            for length in range(3,n+1):
                trial=1+dc+class_bits(LEN_CLASSES,length)+cost[i+length]
                if trial<best[0]:best=(trial,(length,distance))
        cost[i],ops[i]=best
    bits=[]
    def put(v,n):bits.extend((v>>k)&1 for k in range(n-1,-1,-1))
    def put_class(classes,v):
        for k,(nb,base) in enumerate(classes):
            if base<=v<base+(1<<nb):
                put((1<<k)-1,k)
                if k<len(classes)-1:put(0,1)
                put(v-base,nb);return
        raise ValueError(v)
    i=0
    while i<size:
        length,distance=ops[i]
        if not distance:
            put(0,1)
            if data[i]==8:put(0,1)
            elif data[i]==0:put(2,2)
            else:put(3,2);put(alphabet.index(data[i]),5)
        else:
            put(1,1);put_class(DIST_CLASSES,distance);put_class(LEN_CLASSES,length)
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
    def get_class(classes):
        k=0
        while k<len(classes)-1 and get(1):k+=1
        return classes[k][1]+get(classes[k][0])
    while len(out)<size:
        if not get(1):
            out.append(8 if not get(1) else 0 if not get(1) else alphabet[get(5)]);continue
        d=get_class(DIST_CLASSES);n=get_class(LEN_CLASSES)
        for _ in range(n):out.append(out[-d])
    assert len(out)==size and (bit+7)//8==len(data)
    return bytes(out)

INCLUDE=0xFE   # object token: FE, token count, dw address -> read those tokens in place

def share_object_lists(lists):
    """Replace runs of three or more two-byte tokens already stored in an
    earlier list by an include (4 bytes). The reader's sticky visibility must
    agree at the run start, unless the run itself starts with a change."""
    def tokens(data):
        out=[];i=0;vis=0x90
        while data[i]:
            out.append((bytes(data[i:i+2]),vis))
            if data[i]==255:vis=data[i+1]
            i+=2
        return out
    pool=[]          # (label, byte offset, token, entry visibility) of literal tokens
    result=[];decoded={}
    for data,label in lists.items():
        toks=tokens(data);lines=[];offset=0;i=0;literal=[]
        def flush():
            nonlocal literal
            if literal:lines.append(' db '+','.join(str(b) for t in literal for b in t));literal=[]
        while i<len(toks):
            best=(0,None)
            for start in range(len(pool)):
                k=0
                while (i+k<len(toks) and start+k<len(pool) and pool[start+k][0]==pool[start][0]
                       and pool[start+k][1]==pool[start][1]+2*k and pool[start+k][2]==toks[i+k][0]):k+=1
                if k>=3 and k>best[0]:best=(k,start)
            k,start=best
            if k:
                flush();src=pool[start];lines.append(f' db {INCLUDE},{k}');lines.append(f' dw {src[0]}+{src[1]}')
                offset+=4;i+=k;continue
            pool.append((label,offset,toks[i][0],toks[i][1]));literal.append(toks[i][0]);offset+=2;i+=1
        flush();lines.append(' db 0')
        result.append((label,lines));decoded[label]=toks
    # Independent check: expand includes through the emitted bytes.
    memory={};labels={}
    for label,lines in result:
        labels[label]=len(memory)
        for line in lines:
            if line.startswith(' db '):
                for v in line[4:].split(','):memory[len(memory)]=int(v)
            else:
                name,off=line[4:].split('+');memory[len(memory)]=('ref',name,int(off));memory[len(memory)]=None
    def expand(pos,count=None):
        out=[];vis=0x90;n=0
        while count is None or n<count:
            b=memory[pos]
            if count is None and b==0:break
            if b==INCLUDE:
                k=memory[pos+1];ref=memory[pos+2];sub=expand(labels[ref[1]]+ref[2],k);out+=sub;pos+=4;n+=1;continue
            out.append(bytes((b,memory[pos+1])));pos+=2;n+=1
        return out
    for label,lines in result:
        assert expand(labels[label])==[t for t,v in decoded[label]],label
    # Visibility check: replay sticky state over the expansion.
    for label,_ in result:
        vis=0x90;states=[]
        for t in expand(labels[label]):
            states.append(vis)
            if t[0]==255:vis=t[1]
        assert states==[v for t,v in decoded[label]],label
    return result


def objects(rom,index):
    p=rom.w(0xc791+2*index);result=[]
    while rom.b(p):
        t=rom.b(p)
        size=5 if t<=4 else 8 if 0x0e<=t<=0x10 else 6 if t>=0x11 else 9
        record=bytes(rom.b(p+i) for i in range(size));result.append(record);p+=size
        assert len(result)<40,(index,hex(p))
    return result

def native_tiles():
    """NES field tile -> native tile (also used by the title scene)."""
    # Semantic IDs preserve the established native collision/pickup routines.
    native={0:8,1:11,2:0xd6,3:0xd7,0x17:0,0xc:0x90,0xd:0x95,0xe:0xcc,
            0xf:0x10,0x10:0x11,0x11:0x88,0x12:0x89,0x13:0xc8,0x14:0xc9,
            0x15:0xca,0x16:0xcb}
    native.update({i:0x38 for i in range(0x1c,0x20)})
    native.update({0x18+i:0xd2+i for i in range(4)})
    native.update({i:0xe0 for i in range(0x2d,0x35)})
    native.update({i:0xe8 for i in range(0x35,0x39)})
    native.update({i:(4 if i<0x3f else 0xb8)+(i-0x3c)%3 for i in range(0x3c,0x48)})
    native.update({0x39:0xc0,0x3a:0xb0,0x3b:0xbb})
    for start,ids in [(0x56,[0xc1,0xc2,0xc3,0xc5]),(0x5a,[0xb1,0xb2,0xb3,0xb4]),(0x5e,[0xbc,0xbd,0xbe,0xbf])]:
        native.update({start+i:t for i,t in enumerate(ids)})
    return native

def main():
    rom=ROM((ROOT/'orig/nes/monty.nes').read_bytes())
    native=native_tiles()
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
    for data,label in streams.items():
        asm.append(label+':')
        for i in range(0,len(data),24):asm.append(' db '+','.join(map(str,data[i:i+24])))
    for label,lines in share_object_lists(lists):asm+=[label+':']+lines
    # The HUD frame is static: tools/nes/title_native.py draws it with the title.
    def table(name,classes):
        rows=[]
        for k,(bits,base) in enumerate(classes):rows.append(f'{bits|(128 if k==len(classes)-1 else 0)},{base&255},{base>>8}')
        return f'{name}: db '+','.join(rows)
    asm+=['nf_literals: db '+','.join(map(str,literals)),
          table('nf_dist_tab',DIST_CLASSES),table('nf_len_tab',LEN_CLASSES),table('nf_lit_tab',((5,0),))]
    asm+=['nf_type_kind: db 0,'+','.join(str(k) for k,f in types), 'nf_type_flags: db 0,'+','.join(str(f) for k,f in types), 'nf_rooms_end:']
    (ROOT/'src/native/gen/rooms_full.asm').write_text('\n'.join(asm)+'\n')
    out=ROOT/'build/nes_full';out.mkdir(parents=True,exist_ok=True)
    report=dict(rooms=99,unique_fields=len(streams),field_bytes=sum(map(len,streams)),object_bytes=sum(map(len,lists)),unique_object_lists=len(lists),types=len(types),rows=30,field_rows=24,hud_rows=6,coordinates='original NES; no scaling',records=records)
    (out/'rooms.json').write_text(json.dumps(report,indent=2)+'\n')
    print({k:v for k,v in report.items() if k!='records'})
if __name__=='__main__':main()
