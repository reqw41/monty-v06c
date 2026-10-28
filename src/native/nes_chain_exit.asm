; NES room (1,9): leave the chain cap onto the adjacent right platform.
; The MSX state machine otherwise interprets Up at this cap as a fall.
 ORG VNT-0x30
nes_chain_exit:
 ld a,(0x73EE)
 and 1
 jp nz,nce_check
 inc a
 ret
nce_check:
 ld a,(0x705B)
 cp 0x90
 ret nz
 ld a,(0x705C)
 cp 8
 ret nz
 ld bc,0x08F9		; eight pixels right and seven up to the platform edge
 call L_8DD4
 pop hl			; discard the return into the MSX chain-top fall path
 ld bc,0
 xor a
 jp hs_8992
nes_chain_exit_end:
 ASSERT nes_chain_exit_end <= VNT
