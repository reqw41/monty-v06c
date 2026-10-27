import json,glob,sys
S=''
def summ(pat):
    tot={};rooms={}
    for f in glob.glob(pat):
        for k,s in json.load(open(f)).items():
            r=rooms.setdefault(k,{'h':{},'n':0})
            for d,c in s['h'].items(): r['h'][d]=r['h'].get(d,0)+c; tot[d]=tot.get(d,0)+c
            r['n']+=s['n']
    n=sum(tot.values()); fr=sum(int(d)*c for d,c in tot.items())
    L=[]
    for k,r in rooms.items():
        if r['n']<60: continue
        f2=sum(int(d)*c for d,c in r['h'].items()); L.append((50*r['n']/f2,k,100*r['h'].get('1',0)/r['n']))
    L.sort()
    return n,50*n/fr,100*tot.get('1',0)/n,sum(1 for l in L if l[0]<49.5),len(L),L[:8],dict(sorted(tot.items(),key=lambda x:int(x[0])))
for name,pat in [(p,p) for p in sys.argv[1:]]:
    n,sps,one,bad,nr,worst,h=summ(pat)
    print(f'{name}: шагов {n}, {sps:.1f} шаг/с, ровно 1 кадр {one:.0f}%, комнат ниже 49,5: {bad} из {nr}')
    print('   распределение', h)
    print('   худшие:', ', '.join(f'{k} {s:.1f} ({o:.0f}%)' for s,k,o in worst))
