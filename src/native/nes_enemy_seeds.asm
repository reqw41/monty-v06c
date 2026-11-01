; Experimental sparse enemy cache. Four even shifts for the first four poses;
; odd shifts are refined from the preceding seed into the existing slot mask.
; Source survives the cold menu at E790; installed over title music at game start.
 ORG 0xE790
nes_seed_source:
 DISP 0xF170
nes_seed_masks:
 ld a,(sp_x)
 and 1
 jp z,psf_n
 ld a,(sp_x)
 dec a
 ld (sp_x),a
 call ps_find
 push af
 ld a,(sp_x)
 inc a
 ld (sp_x),a
 pop af
 ret nz
 ex de,hl
 ld a,h
 ld (nsm_page+1),a
 ld a,(sp_k)
 add a,ps_hi&255
 ld e,a
 ld d,ps_hi/256
 xor a
 ld (de),a                 ; derived mask uses the ordinary slot, never seed RAM
 ld a,(st_rows)
 ld b,a
 ld c,a
 ld a,(sp_k)
 add a,SPR_SLOTS/256
 ld d,a
 ld e,SM_OFS
nsm_row:
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
nsm_page:
 ld h,0
 dec b
 jp nz,nsm_row
 xor a
 ret
nes_seed_end:
 ASSERT $ <= live_hi+256
 ENT
nes_seed_source_end:
 ASSERT $ <= 0xE828
