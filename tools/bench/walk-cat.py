import json,collections,sys
d=json.load(open('build/nes-physics-audit/walk-native.json'))
ref={q['name']:q for q in json.load(open('build/nes-physics-audit/walk-reference.json'))['cases']}
cat=collections.Counter();ex={}
for r in d['reports']:
    if not r['differences']:continue
    f=r['first'];w,g=f['want'],f['got']
    if g[2]>=8 and not (w[2]&20):k='B native dies, NES lives'
    elif f['step']<=4+0 and w[2]!=g[2]:k='C early state differs'
    elif g[0]==w[0] and g[1]!=w[1]:k='D y differs'
    elif g[1]==w[1]:k='E x differs'
    else:k='F other'
    cat[k]+=1;ex.setdefault(k,[]).append((r['name'],f))
for k,v in cat.most_common():
    print(v,k)
    for e in ex[k][:4]:print('   ',e)
