; Permanent former cap-workaround space, following the copied Joe attributes.
 ORG 0xF500+joe_attr_end-joe_attr_source
; Align to original $9E5B, keeping the two native layers three pixels apart.
nphys_align_y:
 ld a,(0x7304)
 sub 14
 and 0xF8
 add a,14
 ld (0x7304),a
 sub 3
 ld (0x7300),a
 ret
nes_chain_descent_end:
 ASSERT $ <= 0xF600
