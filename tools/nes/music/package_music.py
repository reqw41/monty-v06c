#!/usr/bin/env python3
"""Bundle local music deliverables and reproducible source, never the cartridge."""
import argparse,json,zipfile
from pathlib import Path

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('music',type=Path);p.add_argument('zip',type=Path);a=p.parse_args()
 source=Path(__file__).resolve().parent;repo=source.parents[2]
 data=json.loads((a.music/'music.json').read_text())
 files=['player.html','index.html','apu.js','player.js','music-data.js','music.json','monty.nsf','verification.json','independent_verification.json','render_verification.json']
 files += [track['id']+'.wav' for track in data['tracks']]
 for name in files:
  if not (a.music/name).is_file():raise FileNotFoundError(a.music/name)
 a.zip.parent.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(a.zip,'w',zipfile.ZIP_DEFLATED) as z:
  for name in files:z.write(a.music/name,name)
  z.write(source/'README.md','README.md');z.write(repo/'docs/NES_MUSIC.md','NES_MUSIC.md');z.write(repo/'docs/NES_MUSIC.md','source/docs/NES_MUSIC.md')
  for file in sorted(source.iterdir()):
   if file.suffix in ('.py','.js','.lua','.html','.md'):z.write(file,'source/tools/nes/music/'+file.name)
  for name in ['cpu.py','disasm.py']:z.write(source.parent/name,'source/tools/nes/'+name)
 print(a.zip, a.zip.stat().st_size,'bytes')
if __name__=='__main__':main()
