; Original NES $A3ED samples both sides at top+17 and the middle at top+16.
; Test the moved hero every physics step; pickup scanning remains independent.
nphys_hazards:
 push bc
 ld a,(0x7305)
 ld b,a
 ld a,(0x7304)
 add a,10
 ld c,a
 call nphys_read
 call nphys_hazard_class
 jp z,nph_dead
 ld a,b
 add a,11
 ld b,a
 call nphys_read
 call nphys_hazard_class
 jp z,nph_dead
 ld a,(0x7305)
 add a,8
 ld b,a
 dec c
 call nphys_read
 call nphys_hazard_class
 jp z,nph_dead
 pop bc
 ret
nph_dead:
 pop bc
 ld bc,0
 ld e,c
 call L_8DA2
 ld a,1
 ld (jn_fire),a
 ret
