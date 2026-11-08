import concurrent.futures,json,os,subprocess,sys,time
from pathlib import Path
b=sys.argv[1]; out=Path(b)/'checks';out.mkdir(parents=True,exist_ok=True)
names=sorted(p for p in Path('tools/bench').glob('nes-*.js') if not any(x in p.name for x in ('physics-audit','splash','ladder-gameplay')))+[Path('tools/bench/restart-enemies.js')]
def run(p):
 t=time.monotonic();env=dict(os.environ,B=b)
 with (out/(p.stem+'.log')).open('w') as f:
  r=subprocess.run(['node',str(p)],env=env,stdout=f,stderr=subprocess.STDOUT)
 result=dict(test=p.stem,status=r.returncode,seconds=round(time.monotonic()-t,2))
 (out/(p.stem+'.json')).write_text(json.dumps(result))
 print(json.dumps(result),flush=True)
 return result
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
 results=list(pool.map(run,names))
(out/'summary.json').write_text(json.dumps(results,indent=2))
print('DONE',len(results),'passed',sum(r['status']==0 for r in results),flush=True)
