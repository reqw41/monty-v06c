#!/usr/bin/env python3
"""Capture real NES gameplay and screen pixels with controller input only."""
import argparse,json,os,subprocess,zlib
from pathlib import Path

PROFILES={'idle': {'frames': 2300, 'flight': False, 'input': [[30, 31, ['Start']]]},
 'move_timer': {'frames': 2300,
                'flight': False,
                'input': [[30, 31, ['Start']], [200, 202, ['Right']], [210, 212, ['Left']]]},
 'pause_timer': {'frames': 2450,
                 'flight': False,
                 'input': [[30, 31, ['Start']], [600, 601, ['Start']], [720, 721, ['Start']]]},
 'jump_still': {'frames': 240, 'flight': True, 'input': [[30, 31, ['Start']], [130, 131, ['A']]]},
 'jump_running': {'frames': 520,
                  'flight': True,
                  'input': [[30, 31, ['Start']],
                            [130, 132, ['Right']],
                            [132, 133, ['Right', 'A']],
                            [133, 150, ['Right']]]},
 'jump_left_fall': {'frames': 1200,
                    'flight': True,
                    'input': [[30, 31, ['Start']],
                              [130, 131, ['A', 'Left']],
                              [131, 172, ['Left']],
                              [180, 280, ['Up']],
                              [290, 390, ['Left']],
                              [400, 500, ['Up']],
                              [520, 650, ['Right']]]},
 'fall_left': {'frames': 500, 'flight': True, 'input': [[30, 31, ['Start']], [130, 145, ['Left']]]},
 'neighbours': {'frames': 4500,
                'flight': True,
                'safe_laser': True,
                'sword': True,
                'pole': True,
                'input': [[30, 31, ['Start']],
                          [130, 132, ['Right']],
                          [135, 235, ['Down']],
                          [240, 280, ['Left']],
                          [400, 530, ['Left']],
                          [535, 536, ['Right']],
                          [540, 650, ['Up']],
                          [660, 661, ['A', 'Right']],
                          [661, 670, ['Right']],
                          [680, 700, ['Left']],
                          [715, 795, ['Down']],
                          [800, 814, ['Right']],
                          [815, 816, ['A', 'Right']],
                          [816, 860, ['Right']],
                          [1150, 1151, ['A', 'Left']],
                          [1151, 1300, ['Left']],
                          [1350, 1450, ['Down']],
                          [1460, 1550, ['Left']],
                          [1600, 1613, ['Right']],
                          [1620, 1900, ['Down']],
                          [1905, 1906, ['A', 'Left']],
                          [1906, 2050, ['Left']],
                          [2160, 2219, ['Left']],
                          [2225, 2450, ['Down']],
                          [2470, 3900, ['Right', 'Down']],
                          [3930, 3931, ['A', 'Left']],
                          [3931, 3940, ['Left']],
                          [3950, 3980, ['Down']]]},
 'fire_burst': {'frames': 2300,
                'flight': True,
                'input': [[30, 31, ['Start']],
                          [130, 132, ['Right']],
                          [135, 235, ['Down']],
                          [240, 280, ['Left']],
                          [400, 530, ['Left']],
                          [535, 536, ['Right']],
                          [540, 650, ['Up']],
                          [660, 661, ['A', 'Right']],
                          [661, 670, ['Right']],
                          [680, 700, ['Left']],
                          [715, 795, ['Down']],
                          [800, 814, ['Right']],
                          [815, 816, ['A', 'Right']],
                          [816, 860, ['Right']],
                          [1150, 1151, ['A', 'Left']],
                          [1151, 1300, ['Left']],
                          [1350, 1450, ['Down']],
                          [1460, 1550, ['Left']],
                          [1600, 1613, ['Right']],
                          [1620, 1900, ['Down']],
                          [1905, 2050, ['Right']]]},
 'rope_route': {'frames': 2700,
                'flight': True,
                'input': [[30, 31, ['Start']],
                          [130, 132, ['Right']],
                          [135, 235, ['Down']],
                          [240, 280, ['Left']],
                          [400, 530, ['Left']],
                          [535, 536, ['Right']],
                          [540, 650, ['Up']],
                          [660, 661, ['A', 'Right']],
                          [661, 670, ['Right']],
                          [680, 700, ['Left']],
                          [715, 795, ['Down']],
                          [800, 814, ['Right']],
                          [815, 816, ['A', 'Right']],
                          [816, 860, ['Right']],
                          [1150, 1151, ['A', 'Left']],
                          [1151, 1300, ['Left']],
                          [1350, 1450, ['Down']],
                          [1460, 1550, ['Left']],
                          [1600, 1613, ['Right']],
                          [1620, 1900, ['Down']],
                          [1905, 1909, ['Right']],
                          [1910, 1911, ['A', 'Right']],
                          [1911, 2000, ['Right', 'Down']],
                          [2010, 2200, ['Up']],
                          [2220, 2221, ['A', 'Right']],
                          [2221, 2250, ['Right']],
                          [2260, 2350, ['Left', 'Down']],
                          [2360, 2500, ['Down']]]}}

def lua(value):
 if isinstance(value,bool):return 'true' if value else 'false'
 if isinstance(value,str):return json.dumps(value)
 if isinstance(value,(float,int)):return str(value)
 if isinstance(value,list):return '{'+','.join(map(lua,value))+'}'
 return '{'+','.join(str(k)+'='+lua(v) for k,v in value.items())+'}'

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('rom',type=Path);p.add_argument('output',type=Path);p.add_argument('profiles',nargs='*',choices=list(PROFILES));a=p.parse_args()
 for name in a.profiles or list(PROFILES):
  out=(a.output/name).resolve();out.mkdir(parents=True,exist_ok=True);plan=PROFILES[name]
  for old in out.glob('frame_*.*'):old.unlink()
  (out/'plan.lua').write_text('return '+lua(plan)+'\n');(out/'plan.json').write_text(json.dumps(plan,indent=2)+'\n')
  (out/'complete.json').unlink(missing_ok=True)
  env=dict(os.environ,SDL_VIDEODRIVER='dummy',SDL_AUDIODRIVER='dummy',NES_LIVE_DIR=str(out),NES_LIVE_PLAN=str(out/'plan.lua'))
  result=subprocess.run(['mame','nes','-cart',str(a.rom.resolve()),'-video','none','-sound','none','-nothrottle','-skip_gameinfo','-seconds_to_run',str(plan['frames']//60+8),'-cfg_directory',str(out/'cfg'),'-nvram_directory',str(out/'nvram'),'-snapshot_directory',str(out/'snap'),'-autoboot_script',str(Path(__file__).with_suffix('.lua').resolve())],env=env,capture_output=True,text=True)
  (out/'capture.log').write_text(result.stdout+result.stderr)
  if result.returncode or not (out/'complete.json').is_file() or '[LUA ERROR]' in result.stdout+result.stderr:raise SystemExit(f'{name}: incomplete; see {out}/capture.log')
  for pixels in out.glob('*.pixels'):
   pixels.with_suffix('.pixels.z').write_bytes(zlib.compress(pixels.read_bytes(),9));pixels.unlink()
  print(name,(out/'complete.json').read_text().strip(),flush=True)
if __name__=='__main__':main()
