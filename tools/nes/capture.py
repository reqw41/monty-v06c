#!/usr/bin/env python3
"""Optional MAME reference run. No display; captures are local ignored files."""
import argparse,os,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('rom',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
a.output.mkdir(parents=True,exist_ok=True)
env=dict(os.environ,SDL_VIDEODRIVER='dummy',SDL_AUDIODRIVER='dummy',NES_CAPTURE_DIR=str(a.output.resolve()))
marker=a.output/'capture-complete.json'
marker.unlink(missing_ok=True)
result=subprocess.run(['mame','nes','-cart',str(a.rom.resolve()),'-video','none','-sound','none','-nothrottle','-skip_gameinfo','-seconds_to_run','120','-cfg_directory',str(a.output/'cfg'),'-nvram_directory',str(a.output/'nvram'),'-snapshot_directory',str(a.output/'snap'),'-autoboot_script',str(Path(__file__).with_name('capture_mame.lua').resolve())],env=env,check=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
print(result.stdout,end='')
if not marker.is_file() or '[LUA ERROR]' in result.stdout or 'CAPTURE ERROR' in result.stdout:
    raise SystemExit('MAME capture incomplete; see output above')
