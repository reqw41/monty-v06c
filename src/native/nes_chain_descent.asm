; The right rope in NES room (1,9) starts one cell left of its upper ledge.
; Enter from the ledge and shift to the rope column at the first cell boundary.
; Keep this code after the copied Joe attributes at F500: the former 7AC3
; location belongs to the sprite cache and is overwritten during full boot.
 ORG 0xF500+joe_attr_end-joe_attr_source
nes_chain_enter:
 ld a,(0x705A)
 cp 0x90
 jp nz,ncd_no
 ld a,(0x705B)
 cp 8
 jp nz,ncd_no
 ld a,(0x705C)
 cp 8
 jp nz,ncd_no
 ld a,4
 or a
 ret
ncd_no:
 xor a
 ret

nes_chain_align:
 ld a,(0x705A)
 cp 0x90
 ret nz
 ld a,(0x705B)
 or a
 ret nz
 ld a,(0x7305)
 sub 8
 ld (0x7305),a
 call L_9156
 ret
nes_chain_descent_end:
 ASSERT $ <= 0xF600
