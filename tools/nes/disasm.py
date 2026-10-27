"""Small documented-6502 disassembler used for ROM cross references."""
import sys
ROWS = [
'BRK.i ORA.ix - - - ORA.z ASL.z - PHP.i ORA.n ASL.a - - ORA.w ASL.w -',
'BPL.r ORA.iy - - - ORA.zx ASL.zx - CLC.i ORA.wy - - - ORA.wx ASL.wx -',
'JSR.w AND.ix - - BIT.z AND.z ROL.z - PLP.i AND.n ROL.a - BIT.w AND.w ROL.w -',
'BMI.r AND.iy - - - AND.zx ROL.zx - SEC.i AND.wy - - - AND.wx ROL.wx -',
'RTI.i EOR.ix - - - EOR.z LSR.z - PHA.i EOR.n LSR.a - JMP.w EOR.w LSR.w -',
'BVC.r EOR.iy - - - EOR.zx LSR.zx - CLI.i EOR.wy - - - EOR.wx LSR.wx -',
'RTS.i ADC.ix - - - ADC.z ROR.z - PLA.i ADC.n ROR.a - JMP.ind ADC.w ROR.w -',
'BVS.r ADC.iy - - - ADC.zx ROR.zx - SEI.i ADC.wy - - - ADC.wx ROR.wx -',
'- STA.ix - - STY.z STA.z STX.z - DEY.i - TXA.i - STY.w STA.w STX.w -',
'BCC.r STA.iy - - STY.zx STA.zx STX.zy - TYA.i STA.wy TXS.i - - STA.wx - -',
'LDY.n LDA.ix LDX.n - LDY.z LDA.z LDX.z - TAY.i LDA.n TAX.i - LDY.w LDA.w LDX.w -',
'BCS.r LDA.iy - - LDY.zx LDA.zx LDX.zy - CLV.i LDA.wy TSX.i - LDY.wx LDA.wx LDX.wy -',
'CPY.n CMP.ix - - CPY.z CMP.z DEC.z - INY.i CMP.n DEX.i - CPY.w CMP.w DEC.w -',
'BNE.r CMP.iy - - - CMP.zx DEC.zx - CLD.i CMP.wy - - - CMP.wx DEC.wx -',
'CPX.n SBC.ix - - CPX.z SBC.z INC.z - INX.i SBC.n NOP.i - CPX.w SBC.w INC.w -',
'BEQ.r SBC.iy - - - SBC.zx INC.zx - SED.i SBC.wy - - - SBC.wx INC.wx -']
OPS=' '.join(ROWS).split()

def decode(b,pc):
 op=OPS[b[pc-0x8000]]
 if op=='-': return 1, f'.byte ${b[pc-0x8000]:02X}'
 name,m=op.split('.'); n=1 if m in ('i','a') else 3 if m in ('w','wx','wy','ind') else 2
 data=b[pc-0x8000+1:pc-0x8000+n];v=int.from_bytes(data,'little')
 arg={'i':'','a':'A','n':f'#${v:02X}','z':f'${v:02X}','zx':f'${v:02X},X','zy':f'${v:02X},Y','w':f'${v:04X}','wx':f'${v:04X},X','wy':f'${v:04X},Y','ix':f'(${v:02X},X)','iy':f'(${v:02X}),Y','ind':f'(${v:04X})','r':f'${(pc+2+(v if v<128 else v-256))&65535:04X}'}[m]
 return n,name+' '+arg
if __name__=='__main__':
 b=open(sys.argv[1],'rb').read()[16:32784];pc=int(sys.argv[2],16) if len(sys.argv)>2 else 0x8000;end=int(sys.argv[3],16) if len(sys.argv)>3 else 0x10000
 while pc<end:
  n,s=decode(b,pc); print(f'{pc:04X}  {b[pc-0x8000:pc-0x8000+n].hex(" "):8} {s}');pc+=n
