import json,sys
ref={q['name']:q for q in json.load(open('build/nes-physics-audit/walk-reference.json'))['cases']}
nat={r['name']:r for r in json.load(open('build/nes-physics-audit/walk-native.json'))['reports']}
name=sys.argv[1];lo=int(sys.argv[2]);hi=int(sys.argv[3])
c=ref[name];T={(r,col):t for r,col,t in c['terrain']}
x0=c['trace'][lo][0];y0=c['trace'][lo][1];col=x0//8;row=(y0+25)//8
print(name,'start',c['x'],c['y'],'keys',c['keys'][lo:hi])
for rr in range(row-5,row+3):print('%2d'%rr,' '.join('%02x'%T.get((rr,cc),0x17) for cc in range(max(0,col-4),min(32,col+6))),'  cols',max(0,col-4),'..')
for n in range(lo,min(hi,len(nat[name]['trace']))):print(n,'key',c['keys'][n],'NES',c['trace'][n][:3],'nat',nat[name]['trace'][n][:3])
