"""Untimed NMOS 6502 executor for isolated ROM routines, not a NES emulator.

No interrupts/APU/render timing. Only PPU address/data/status are modelled.
Undocumented instructions fail closed. Used to execute original palette/room code.
"""
from disasm import OPS

class CPU:
    def __init__(self, prg):
        self.mem=bytearray(65536); self.mem[0x8000:]=prg
        self.ppu=bytearray(0x4000); self.addr=0; self.latch=0; self.ctrl=0
        self.a=self.x=self.y=0; self.s=0xfd; self.p=0x24; self.pc=0; self.buffer=0
        self.writes=[]
    def pa(self,a):
        a &= 0x3fff
        if 0x3000<=a<0x3f00: a-=0x1000
        if 0x2800<=a<0x3000: a-=0x800  # vertical mirroring
        if a>=0x3f00:
            a=0x3f00+(a&31)
            if a in (0x3f10,0x3f14,0x3f18,0x3f1c):a-=16
        return a
    def read(self,a):
        a &= 65535
        if a<0x2000:return self.mem[a&0x7ff]
        if a==0x2002:self.latch=0;return 0x80
        if a==0x2007:
            p=self.pa(self.addr);v=self.ppu[p];self.addr=(self.addr+(32 if self.ctrl&4 else 1))&0x3fff
            old=self.buffer;self.buffer=v;return v if p>=0x3f00 else old
        return self.mem[a]
    def write(self,a,v):
        a &=65535;v&=255
        if a<0x2000:self.mem[a&0x7ff]=v;return
        if a==0x2000:self.ctrl=v
        elif a==0x2006:
            self.addr=((v&63)<<8)|(self.addr&255) if self.latch==0 else (self.addr&0x3f00)|v
            self.latch^=1
        elif a==0x2007:
            self.ppu[self.pa(self.addr)]=v;self.writes.append((self.addr,v));self.addr=(self.addr+(32 if self.ctrl&4 else 1))&0x3fff
        elif a<0x8000:self.mem[a]=v
        else:raise ValueError(f'write ROM {a:04X}')
    def push(self,v):self.mem[0x100+self.s]=v&255;self.s=(self.s-1)&255
    def pop(self):self.s=(self.s+1)&255;return self.mem[0x100+self.s]
    def flag(self,f,v):self.p=(self.p|f) if v else (self.p&~f)
    def nz(self,v):v&=255;self.flag(2,v==0);self.flag(128,v&128);return v
    def fetch(self):v=self.read(self.pc);self.pc=(self.pc+1)&65535;return v
    def word(self):return self.fetch()|(self.fetch()<<8)
    def step(self):
        pos=self.pc;op=OPS[self.fetch()]
        if op=='-':raise ValueError(f'undocumented opcode at {pos:04X}')
        name,m=op.split('.');ea=None
        if m=='n':v=self.fetch()
        elif m in ('z','zx','zy','ix','iy'):
            z=self.fetch()
            if m=='zx':ea=(z+self.x)&255
            elif m=='zy':ea=(z+self.y)&255
            elif m=='ix':z=(z+self.x)&255;ea=self.read(z)|(self.read((z+1)&255)<<8)
            elif m=='iy':ea=((self.read(z)|(self.read((z+1)&255)<<8))+self.y)&65535
            else:ea=z
            v=0 if name in ('STA','STX','STY') else self.read(ea)
        elif m in ('w','wx','wy','ind'):
            ea=self.word()
            if m=='wx':ea=(ea+self.x)&65535
            elif m=='wy':ea=(ea+self.y)&65535
            elif m=='ind':ea=self.read(ea)|(self.read((ea&0xff00)|((ea+1)&255))<<8)
            v=self.read(ea) if name not in ('JSR','JMP','STA','STX','STY') else 0
        elif m=='r':v=self.fetch();ea=(self.pc+(v if v<128 else v-256))&65535
        else:v=self.a
        if name in ('LDA','LDX','LDY'):setattr(self,name[-1].lower(),self.nz(v))
        elif name in ('STA','STX','STY'):self.write(ea,getattr(self,name[-1].lower()))
        elif name in ('AND','ORA','EOR'):self.a=self.nz(self.a&v if name=='AND' else self.a|v if name=='ORA' else self.a^v)
        elif name in ('ADC','SBC'):
            if name=='SBC':v^=255
            t=self.a+v+(self.p&1);self.flag(64,(~(self.a^v)&(self.a^t)&128));self.flag(1,t>255);self.a=self.nz(t)
        elif name in ('CMP','CPX','CPY'):
            r=self.a if name=='CMP' else self.x if name=='CPX' else self.y
            self.flag(1,r>=v);self.nz(r-v)
        elif name=='BIT':self.flag(2,not(self.a&v));self.flag(64,v&64);self.flag(128,v&128)
        elif name in ('INC','DEC'):self.write(ea,self.nz(v+(1 if name=='INC' else -1)))
        elif name in ('ASL','LSR','ROL','ROR'):
            c=self.p&1
            self.flag(1,v&(128 if name in ('ASL','ROL') else 1))
            r=self.nz((v<<1)|(c if name=='ROL' else 0)) if name in ('ASL','ROL') else self.nz((v>>1)|((c<<7) if name=='ROR' else 0))
            if m=='a':self.a=r
            else:self.write(ea,r)
        elif name in ('INX','DEX','INY','DEY'):
            r=name[-1].lower();setattr(self,r,self.nz(getattr(self,r)+(1 if name.startswith('IN') else -1)))
        elif name in ('TAX','TAY','TXA','TYA','TSX','TXS'):
            r={'TAX':'a','TAY':'a','TXA':'x','TYA':'y','TSX':'s','TXS':'x'}[name];dst=name[-1].lower();setattr(self,dst,getattr(self,r) if dst=='s' else self.nz(getattr(self,r)))
        elif name in ('CLC','SEC','CLI','SEI','CLD','SED','CLV'):self.flag({'CLC':1,'SEC':1,'CLI':4,'SEI':4,'CLD':8,'SED':8,'CLV':64}[name],name.startswith('SE'))
        elif name=='PHA':self.push(self.a)
        elif name=='PHP':self.push(self.p|0x30)
        elif name=='PLA':self.a=self.nz(self.pop())
        elif name=='PLP':self.p=(self.pop()|32)&~16
        elif name=='JSR':self.push((self.pc-1)>>8);self.push(self.pc-1);self.pc=ea
        elif name=='RTS':self.pc=((self.pop()|(self.pop()<<8))+1)&65535
        elif name=='JMP':self.pc=ea
        elif name.startswith('B') and name!='BRK':
            f,on={'BPL':(128,False),'BMI':(128,True),'BVC':(64,False),'BVS':(64,True),'BCC':(1,False),'BCS':(1,True),'BNE':(2,False),'BEQ':(2,True)}[name]
            if bool(self.p&f)==on:self.pc=ea
        elif name!='NOP':raise ValueError(f'unsupported {name} at {pos:04X}')
    def call(self,pc,limit=1000000):
        self.push(0x7f);self.push(0xfe);self.pc=pc
        for n in range(limit):
            if self.pc==0x7fff:return n
            self.step()
        raise ValueError(f'routine {pc:04X} exceeded {limit} instructions, PC={self.pc:04X}')
