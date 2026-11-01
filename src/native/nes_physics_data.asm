; The NES renderer uses its own art/pose clocks. Reuse only the obsolete MSX
; attribute tables. Native Joe also selects its own death pictures.
npd_return equ $
 ORG C_9378
nphys_box_data:
 db 0,2,14, 0,2,14, 0,0,0, 0,5,16
 db 3,3,13, 0,2,16, 0,2,16, 0,2,16
js_nes_ladder:
 ld a,(nphys_box_pose)
 cp 7
 ld b,12
 jp z,js_b
 jp js_lad_phase
nphys_walk_fall:
 ld bc,3
 jp hs_8A01
 ASSERT $ <= C_93A6
 ORG C_93A6
nphys_solid equ L_A894
nphys_top_wrap:
 ld a,220
 ld hl,0x7304
 sub (hl)
 ld c,a
 ret
nphys_rope_fire:
 ld a,(0x73EE)
 and 0x4A
 cp 0x40
 ret z                     ; Fire without a sideways direction does not consume the latch
 jp L_90E3
nphys_up_tick:
 ld hl,nphys_up_phase
 inc (hl)
 ld a,(hl)
 rra
 ret
 ASSERT $ <= C_93C0
 ORG npd_return
