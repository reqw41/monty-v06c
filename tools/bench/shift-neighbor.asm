; Experimental one-bit refinement of an existing three-column mask.
; HL=8000 source, DE=destination (16-byte columns), B=C=rows.
 DEVICE NOSLOT64K
 ORG 0xE000
near_shift:
 ld a,(hl)
 push bc
 ld b,a
 ld a,l
 add a,c
 ld l,a
 ld a,(hl)
 push af
 ld a,l
 add a,c
 ld l,a
 ld a,(hl)
 ld c,a
 pop af
 ld h,a
 ld a,b
 or a
 rra
 ld b,a
 ld a,h
 rra
 ld h,a
 ld a,c
 rra
 ld c,a
 ld a,b
 ld (de),a
 ld a,e
 add a,16
 ld e,a
 ld a,h
 ld (de),a
 ld a,e
 add a,16
 ld e,a
 ld a,c
 ld (de),a
 ld a,e
 sub 31
 ld e,a
 pop bc
 ld a,l
 sub c
 sub c
 inc a
 ld l,a
 ld h,0x80
 dec b
 jp nz,near_shift
 ret
 SAVEBIN "near.bin",0xE000,$-0xE000
