#!/usr/bin/env python3
"""Extract this local NES ROM's three tunes and nine effects, original driver, NSF and APU events."""
import argparse,base64,hashlib,json,struct,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from cpu import CPU

FRAME_PERIOD=0.016639267340  # measured MAME NTSC screen, TASK_NES_ASSETS_2
TRACKS=[dict(id='title',title='Титульная тема',entry=0x8620,table=0xd3db,patterns=4,ticks=10,context='Титульный экран: $B8E0 → $8620'),
 dict(id='pyramid',title='Вход в пирамиду',entry=0x863a,table=0xd3fb,patterns=2,ticks=8,context='Начальная сцена на канате: $9880 → $863A'),
 dict(id='treasure',title='Переход к сокровищнице',entry=0x8654,table=0xd40f,patterns=2,ticks=5,context='Специальный переход: $9CD6 → $9CF3 → $8654')]

EFFECTS=[
 dict(id='sfx_door',title='Открытие двери',effect_kind='pulse',effect=1,context='$A2C9 → $8600(1)'),
 dict(id='sfx_jump',title='Прыжок',effect_kind='pulse',effect=2,context='$A834 / $AB32 → $8600(2)'),
 dict(id='sfx_sword',title='Враг побеждён мечом',effect_kind='pulse',effect=3,context='$A541 → $8600(3)'),
 dict(id='sfx_pickup',title='Подбор предмета',effect_kind='pulse',effect=4,context='$A34F / $A3D6 → $8600(4)'),
 dict(id='sfx_life',title='Дополнительная жизнь',effect_kind='pulse',effect=5,context='$809E → $8600(5)'),
 dict(id='sfx_landing',title='Конец скольжения',effect_kind='pulse',effect=6,context='$9FF5 / $9FFC → $8600(6)'),
 dict(id='sfx_land',title='Приземление',effect_kind='noise',effect=1,context='$9FC5 → $85F7(1)'),
 dict(id='sfx_death',title='Гибель / огонь / лазер',effect_kind='noise',effect=2,context='$A429 / $A453 / $A52E → $85F7(2)'),
 dict(id='sfx_pole',title='Скольжение по шесту',effect_kind='pole',effect=16,context='$A630 / $A639 → $860E; Y=64..190, +2/кадр')]

class ROM:
 """Only this analysed cartridge; music extraction does not require Pillow."""
 def __init__(self,data):
  expected='453a6a9198b11cf6f948f5b61ab98dd7e6fbf7928a7b257941d4f5e7aa4a54fb'
  if hashlib.sha256(data).hexdigest()!=expected:
   raise ValueError('Unsupported ROM: expected the analysed local monty.nes SHA-256 '+expected)
  self.data=data;self.prg=data[16:32784];self.chr=data[32784:]
 def w(self,address):return struct.unpack_from('<H',self.prg,address-0x8000)[0]

class SoundCPU(CPU):
 def __init__(self,prg,chr_data=None):
  super().__init__(prg);self.events=[];self.frame=-1
  if chr_data is not None:self.ppu[:len(chr_data)]=chr_data
 def write(self,address,value):
  if 0x4000<=address<=0x4017:self.events.append([self.frame,address,value])
  super().write(address,value)

def original(rom,track,cycles=3):
 c=SoundCPU(rom.prg,rom.chr);c.mem[0x7fd]=255;c.call(0x8588);c.call(track['entry'])
 for frame in range(track['patterns']*64*track['ticks']*cycles):
  c.frame=frame;c.call(0x872d);c.call(0x86c6)
 return c.events

def original_effect(rom,effect,frames=512):
 c=SoundCPU(rom.prg,rom.chr);c.mem[0x7fd]=255;c.call(0x8588);c.call(0x863a);c.call(0x85ee)
 c.mem[0x7d4]=1  # no frozen background note; preserve the game tempo of eight frames
 c.a=effect['effect'];c.call(0x8600 if effect['effect_kind']=='pulse' else 0x85f7 if effect['effect_kind']=='noise' else 0x860e)
 for frame in range(frames):
  c.frame=frame
  if effect['effect_kind']=='pole':
   if frame<64:c.mem[0x16]=64+frame*2
   elif frame==64:c.mem[0x7ef]=0;c.call(0x83f6)
  c.call(0x872d);c.call(0x86c6)
 return c.events

class Assembler:
 def __init__(self,origin):self.origin=origin;self.code=bytearray();self.labels={};self.fixups=[]
 def emit(self,*values):self.code.extend(values)
 def label(self,name):self.labels[name]=self.origin+len(self.code)
 def branch(self,opcode,label):self.emit(opcode,0);self.fixups.append((len(self.code)-1,label))
 def finish(self):
  for offset,label in self.fixups:
   delta=self.labels[label]-(self.origin+offset+1)
   assert -128<=delta<=127
   self.code[offset]=delta&255
  return bytes(self.code)

def make_nsf(rom):
 # Only the sound routines, sound tables and used CHR music region are retained.
 payload=bytearray(0x6800)
 def put(address,data):payload[address-0x8000:address-0x8000+len(data)]=data
 put(0x81f5,rom.prg[0x1f5:0x822]);put(0xd334,rom.prg[0x5334:0x545f]);put(0xe000,rom.chr[0x800:0x1000])
 # Relocate channel streams from PPU $0800..$0FFF to CPU $E000..$E7FF.
 patched=set()
 for track in TRACKS:
  for pattern in range(track['patterns']):
   header=rom.w(track['table']+pattern*2)
   for channel in range(3 if track['id']=='treasure' else 4):
    address=header+channel*2
    if address not in patched:
     value=rom.w(address);assert 0x800<=value<0x1000
     put(address,struct.pack('<H',value+0xd800));patched.add(address)
 # Replace only the PPU reader with equivalent direct reads. The sequencer,
 # note parsing, software envelopes and all channel writers remain original.
 reader=Assembler(0x872d);reader.emit(0xad,0xd4,7);reader.branch(0xf0,'read');reader.emit(0x60);reader.label('read');reader.emit(0xa0,0)
 for pointer,low,high in [(0xf6,0xd6,0xd5),(0xf8,0xd9,0xd8),(0xfa,0xdc,0xdb)]:
  reader.emit(0xb1,pointer,0x8d,low,7,0xc8,0xb1,pointer,0x8d,high,7,0x88)
 reader.emit(0xad,0xeb,7);reader.branch(0xf0,'done');reader.emit(0xb1,0xfc,0x8d,0xde,7);reader.label('done');reader.emit(0xa9,1,0x8d,0xd4,7,0x60)
 code=reader.finish();assert len(code)<=0x879c-0x872d
 put(0x872d,bytes([0xea])*(0x879c-0x872d));put(0x872d,code)
 # NSF INIT preserves the caller's stack; A selects 3 tunes + 9 effects.
 init=Assembler(0x8000);init.emit(0x48,0xa9,0,0xa2,0);init.label('clear');init.emit(0x9d,0xcc,7,0xe8,0xe0,0x31);init.branch(0xd0,'clear')
 init.emit(0xa9,0xff,0x8d,0xfd,7,0xa9,0x40,0x8d,0x17,0x40,0x20,0x88,0x85,0x68,0xc9,3);init.branch(0x90,'music')
 init.emit(0x38,0xe9,3,0x48,0x20,0x3a,0x86,0x20,0xee,0x85,0xa9,1,0x8d,0xd4,7,0x68,0xc9,6);init.branch(0x90,'pulse')
 init.emit(0xc9,8);init.branch(0x90,'noise');init.emit(0xa9,1,0x8d,0xcc,7,0xa9,64,0x85,0x16,0x4c,0x0e,0x86)
 init.label('pulse');init.emit(0x18,0x69,1,0x4c,0,0x86);init.label('noise');init.emit(0x38,0xe9,5,0x4c,0xf7,0x85)
 init.label('music');init.emit(0x0a,0xaa,0xbd,0,0x81,0x85,0x0e,0xbd,1,0x81,0x85,0x0f,0x6c,0x0e,0)
 init_code=init.finish();assert len(init_code)<=0x80;put(0x8000,init_code)
 put(0x8100,b''.join(struct.pack('<H',t['entry']) for t in TRACKS))
 play=Assembler(0x8080);play.emit(0xad,0xcc,7);play.branch(0xf0,'step');play.emit(0xad,0xce,7,0xc9,64);play.branch(0xb0,'endpole')
 play.emit(0x0a,0x18,0x69,64,0x85,0x16,0xee,0xce,7);play.branch(0xd0,'step')
 play.label('endpole');play.emit(0xa9,0,0x8d,0xef,7,0x8d,0xcc,7,0x20,0xf6,0x83)
 play.label('step');play.emit(0x20,0x2d,0x87,0x4c,0xc6,0x86);put(0x8080,play.finish())
 header=bytearray(128);header[:8]=b'NESM\x1a\x01\x0c\x01';struct.pack_into('<HHH',header,8,0x8000,0x8000,0x8080)
 for offset,title in [(14,"Montezuma's Revenge NES (2022)"),(46,'Composer unverified'),(78,'Original game soundtrack')]:header[offset:offset+len(title)]=title.encode('ascii')
 struct.pack_into('<H',header,110,16639);struct.pack_into('<H',header,120,19997)
 return bytes(header+payload)

def check_nsf(nsf,index,expected,frames):
 prg=nsf[128:]+bytes(32768-len(nsf[128:]));c=SoundCPU(prg);c.a=index;c.call(0x8000)
 for frame in range(frames):c.frame=frame;c.call(0x8080)
 got=[v for v in c.events if v[1]!=0x4017]
 assert got==expected,(index,'NSF driver differs from original ROM')
 return len(got)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('rom',type=Path);p.add_argument('output',type=Path);a=p.parse_args();r=ROM(a.rom.read_bytes());out=a.output;out.mkdir(parents=True,exist_ok=True)
 nsf=make_nsf(r);(out/'monty.nsf').write_bytes(nsf)
 data=dict(format='monty-nes-apu-events-v1',rom_sha256=hashlib.sha256(r.data).hexdigest(),framePeriod=FRAME_PERIOD,cpuHz=1789772.7272727273,tracks=[])
 checks=[]
 for track in TRACKS:
  period=track['patterns']*64*track['ticks'];events=original(r,track)
  cycles=[[[f-i*period,address,value] for f,address,value in events if i*period<=f<(i+1)*period] for i in range(3)]
  assert cycles[1]==cycles[2],(track['id'],'no stable event loop')
  checks.append(dict(track=track['id'],original_vs_nsf_writes=check_nsf(nsf,TRACKS.index(track),events,period*3),stable_loop_frames=period))
  data['tracks'].append(dict(track,kind='music',periodFrames=period,loopStartFrame=period,frames=period*2,initialWrites=[[address,value] for f,address,value in events if f<0],events=[v for v in events if 0<=v[0]<period*2]))
  print(track['id'],period,'frames',round(period*FRAME_PERIOD,3),'seconds',flush=True)
 for index,effect in enumerate(EFFECTS):
  events=original_effect(r,effect)
  count=check_nsf(nsf,len(TRACKS)+index,events,512)
  levels={};last=0
  for frame,address,value in events:
   levels[address]=value
   if frame>=0 and ((levels.get(0x4004,0)&15) or (levels.get(0x400c,0)&15)):last=frame
  frames=max(last+13,80 if effect['effect_kind']=='pole' else 24)
  checks.append(dict(track=effect['id'],original_vs_nsf_writes=count,frames=frames))
  data['tracks'].append(dict(effect,kind='sfx',periodFrames=frames,loopStartFrame=0,frames=frames,initialWrites=[[a,v] for f,a,v in events if f<0],events=[v for v in events if 0<=v[0]<frames]))
  print(effect['id'],frames,'frames',round(frames*FRAME_PERIOD,3),'seconds',flush=True)
 (out/'music.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n')
 (out/'music-data.js').write_text('globalThis.MONTY_NES_MUSIC='+json.dumps(data,ensure_ascii=False,separators=(',',':'))+';\n')
 (out/'verification.json').write_text(json.dumps(dict(checks=checks,nsf_sha256=hashlib.sha256(nsf).hexdigest()),indent=2)+'\n')
 for name in ['apu.js','player.js','index.html']:
  src=Path(__file__).with_name(name)
  if src.exists():(out/name).write_bytes(src.read_bytes())
 # A single offline HTML file embeds all data and player sources.
 template=Path(__file__).with_name('index.html')
 if template.exists():
  html=template.read_text()
  for name in ['music-data.js','apu.js','player.js']:
   html=html.replace('<script src="'+name+'"></script>','<script>\n'+(out/name).read_text()+'\n</script>')
  for name,mime in [('apu.js','text/javascript'),('monty.nsf','application/octet-stream')]:
   html=html.replace('href="'+name+'"','href="data:'+mime+';base64,'+base64.b64encode((out/name).read_bytes()).decode()+'"')
  (out/'player.html').write_text(html)
if __name__=='__main__':main()
