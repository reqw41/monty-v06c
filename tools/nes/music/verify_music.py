#!/usr/bin/env python3
"""Check original music on MAME and exported NSF on Game Music Emu (when installed)."""
import argparse,csv,ctypes,ctypes.util,json,os,subprocess
from pathlib import Path
from extract_music import TRACKS,EFFECTS,FRAME_PERIOD,ROM,original,original_effect

def mame_check(rom,out):
 checks=[];r=ROM(rom.read_bytes())
 for track in TRACKS+EFFECTS:
  folder=(out/'reference'/track['id']).resolve();folder.mkdir(parents=True,exist_ok=True)
  period=track['patterns']*64*track['ticks'] if 'patterns' in track else 512;marker=folder/'complete.json';marker.unlink(missing_ok=True)
  env=dict(os.environ,SDL_VIDEODRIVER='dummy',SDL_AUDIODRIVER='dummy',NES_MUSIC_DIR=str(folder),NES_MUSIC_ENTRY=str(track.get('entry',0)),NES_MUSIC_TICKS=str(period),NES_MUSIC_KIND=track.get('effect_kind','music'),NES_MUSIC_EFFECT=str(track.get('effect',0)))
  run=subprocess.run(['mame','nes','-cart',str(rom.resolve()),'-video','none','-sound','none','-nothrottle','-skip_gameinfo','-seconds_to_run',str(period//60+10),'-cfg_directory',str(folder/'cfg'),'-nvram_directory',str(folder/'nvram'),'-autoboot_script',str(Path(__file__).with_name('capture_music.lua').resolve())],env=env,capture_output=True,text=True)
  (folder/'capture.log').write_text(run.stdout+run.stderr)
  assert run.returncode==0 and marker.exists() and '[LUA ERROR]' not in run.stdout+run.stderr,(track['id'],'MAME incomplete')
  actual=[[int(v['frame']),int(v['address']),int(v['value'])] for v in csv.DictReader((folder/'apu.tsv').open(),delimiter='\t') if int(v['address']) not in (0x4014,0x4016)]
  expected=[v for v in (original(r,track,1) if 'patterns' in track else original_effect(r,track,period)) if v[0]>=0]
  assert actual==expected,(track['id'],'MAME APU writes differ',next(((a,b) for a,b in zip(actual,expected) if a!=b),('length',len(actual),len(expected))))
  checks.append(dict(track=track['id'],frames=period,matching_apu_writes=len(actual)));print('MAME',checks[-1],flush=True)
 return checks

def gme_check(nsf):
 path=ctypes.util.find_library('gme')
 if not path:return dict(available=False)
 g=ctypes.CDLL(path);p=ctypes.c_void_p
 g.gme_open_file.argtypes=[ctypes.c_char_p,ctypes.POINTER(p),ctypes.c_int];g.gme_open_file.restype=ctypes.c_char_p
 g.gme_start_track.argtypes=[p,ctypes.c_int];g.gme_start_track.restype=ctypes.c_char_p
 g.gme_play.argtypes=[p,ctypes.c_int,ctypes.POINTER(ctypes.c_int16)];g.gme_play.restype=ctypes.c_char_p
 g.gme_track_count.argtypes=[p];g.gme_track_count.restype=ctypes.c_int
 g.gme_warning.argtypes=[p];g.gme_warning.restype=ctypes.c_char_p;g.gme_delete.argtypes=[p]
 player=p();error=g.gme_open_file(os.fsencode(nsf.resolve()),ctypes.byref(player),44100);assert not error,error
 results=[]
 try:
  assert g.gme_track_count(player)==len(TRACKS)+len(EFFECTS)
  for index,track in enumerate(TRACKS+EFFECTS):
   error=g.gme_start_track(player,index);assert not error,error
   seconds=track['patterns']*64*track['ticks']*FRAME_PERIOD+0.3 if 'patterns' in track else 2
   buf=(ctypes.c_int16*(int(44100*seconds)*2))();error=g.gme_play(player,len(buf),buf);assert not error,error
   peak=max(map(abs,buf));assert peak>100,(track['id'],'silent NSF')
   warning=g.gme_warning(player);assert not warning,warning
   results.append(dict(track=track['id'],rendered_seconds=seconds,peak=peak))
 finally:g.gme_delete(player)
 return dict(available=True,library=path,tracks=results)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('rom',type=Path);p.add_argument('output',type=Path);p.add_argument('--skip-mame',action='store_true');a=p.parse_args()
 result=dict(mame=[] if a.skip_mame else mame_check(a.rom,a.output),gme=gme_check(a.output/'monty.nsf'))
 (a.output/'independent_verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
