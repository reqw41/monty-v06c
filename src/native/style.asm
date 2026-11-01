; NES presentation and logical HUD. In NES_FULL Joe uses fixed inks 1/2/3;
; the room accent lives in slot 7.
style_palette:
 IFDEF NES_STABLE_COLORS
 ld a,5
 ld (full_modes+19),a     ; ordinary jewels: Joe skin, C000+A000
 ld a,0x3A
 ld (nes_snake_palette),a ; restore the normal LDA video_enabled entry
 ENDIF
 ld hl,style_cmap
 ld de,cmap
 ld bc,16
 call copy_de_hl_swap
 ld hl,style_pal
 ld de,pal
 ld bc,16
 call copy_de_hl_swap
 ld a,(0x71A7)
 inc a
 IFDEF NES_STABLE_COLORS
 cp 10
 jp nc,nt_bonus_palette
 ELSE
 cp 9
 jp c,stp_row
 xor a
 ENDIF
stp_row:
 ld hl,style_accents
 call add_hl_a
 ld a,(hl)
 IFDEF NES_FULL
 ld (pal+14),a
 ld (pal+15),a
 ELSE
 ld (pal+4),a
 ld (pal+5),a
 ENDIF
 IFDEF NES_FULL
 jp nes_snake_palette
 ELSE
 ret
 ENDIF
 IFNDEF NES_FULL
copy_de_hl_swap:
 ex de,hl
 jp copy_de_hl
 ENDIF
 IFDEF NES_FULL
style_cmap: db 0,0,6,6,6,6,2,6,7,7,7,1,6,7,1,1
 ELSE
style_cmap: db 0,0,6,6,6,6,3,6,2,2,2,1,6,2,4,4
 ENDIF
 IFNDEF NES_FULL
style_pal: db 0,0,255,255,31,31,3,3,255,255,255,255,160,160,255,255
 ENDIF

; A raw tile -> visual tile. Private F0/F1/F4 never enter VNT.
; rr_r/rr_c are valid at both full-room and dirty-cell entry points.
 IFNDEF NES_FULL
style_tile:
 ld b,a
 ld a,(rr_r)
 cp 5
 jp nc,st_field
 ld a,b
 cp 8
 jp z,st_hud_blank
 cp 9
 ret c
 cp 13
 ret nc
 add a,0xEF
 ret
st_hud_blank:
 xor a
 ret
st_field:
 ld a,b
 cp 8
 jp nz,st_empty
 ld a,(rr_r)
 and 1
 ld a,8
 ret z
 ld a,0xF4
 ret
st_empty:
 or a
 ret nz
 push hl
 push de
 ld a,(rr_r)
 ld l,a
 ld h,0
 REPT 5
 add hl,hl
 ENDR
 ld a,(rr_c)
 call add_hl_a
 ld de,VNT-32
 add hl,de
 ld a,(hl)
 cp 8
 jp nz,st_none
 ld de,31
 add hl,de
 ld a,(rr_c)
 or a
 jp z,st_right
 ld a,(hl)
 cp 8
 ld a,0xF0
 jp z,st_done
st_right:
 inc hl
 inc hl
 ld a,(rr_c)
 cp 31
 jp z,st_none
 ld a,(hl)
 cp 8
 ld a,0xF1
 jp z,st_done
st_none:
 xor a
st_done:
 pop de
 pop hl
 ret

 ENDIF
; Special three-ink brick / Joe-derived life hat. All other tiles retain the
; ordinary colour-group compiler, including fire body 38 and dynamic colours.
 IFNDEF NES_FULL
style_modes:
 ld a,b
 cp 0xF8
 jp nc,stm_cyan
 cp 0xF0
 jp z,stm_white
 cp 0xF1
 jp z,stm_white
 ld a,c
 or a
 ret z
 ld a,b
 cp 0x10
 jp z,stm_cyan
 cp 0x11
 jp z,stm_cyan
 cp 0x88
 jp z,stm_cyan
 cp 0x89
 jp z,stm_cyan
 cp 0x90
 jp z,stm_white
 cp 0x95
 ret nz
stm_white:
 ld c,0x10
 ret
stm_cyan:
 ld c,0x14
 ret

 ENDIF
style_image:
 IFDEF NES_STABLE_COLORS
 call object_image_select
 ret c
 ENDIF
 ld a,(rr_t)
 IFDEF NES_FULL
 cp 0xC8
 jp c,sti_no_vase
 cp 0xCC
 jp nc,sti_no_vase
 ld a,(room_colors+1)
 cp 0x11
 ret z
 ld a,(rr_t)
 sub 0xC8
 ld l,a
 ld h,0
 add hl,hl
 add hl,hl
 ld d,h
 ld e,l
 add hl,hl
 add hl,de
 add hl,hl
 ld de,style_vase
 add hl,de
 ex de,hl
 jp sti_copy
sti_no_vase:
 cp 0xDE
 ld de,style_hat_right
 jp z,sti_copy
 ENDIF
 cp 0x6F
 ld de,style_hat
 jp z,sti_copy
 cp 8
 jp z,sti_brick
 IFDEF NES_FULL
 cp 0x0B
 ELSE
 cp 0xF4
 ENDIF
 jp z,sti_brick
 or a
 ret
sti_brick:
 ld a,(room_colors+1)
 cp 0x11
 ret z
 ld a,(rr_t)
 ld de,style_bricks
 cp 8
 jp z,sti_copy
 ld de,style_bricks+24
sti_copy:
 ld hl,(tile_dst)
 ld bc,24
 call copy_de_hl
 scf
 ret


; The extra HUD row occupies the unused border at physical Y=16..23.
; Only four vertical sides are needed: room/logic never writes this row.
 IFNDEF NES_FULL
style_gap:
 ld hl,0x80CF
 ld c,192
 call stg_side
 ld hl,0x8BCF
 ld c,3
 call stg_side
 ld hl,0x96CF
 ld c,192
 call stg_side
 ld hl,0x9FCF
 ld c,3
stg_side:
 REPT 2
 REPT 8
 ld (hl),c
 dec l
 ENDR
 ld a,l
 add a,8
 ld l,a
 ld a,h
 add a,32
 ld h,a
 ENDR
 ret
 ENDIF
 IFDEF NES_FULL
full_style_modes:
 ld a,(room_colors+1)
 cp 0x11
 jp nz,fsm_lit
 ld a,b
 cp 0x18
 jp c,fsm_dark
 cp 0x38
 jp z,fsm_dark
 cp 0x88
 jp c,fsm_lit
 cp 0x96
 jp c,fsm_dark
 cp 0xC8
 jp c,fsm_lit
 cp 0xCE
 jp c,fsm_dark
 cp 0xD2
 jp c,fsm_lit
 cp 0xD8
 jp nc,fsm_lit
fsm_dark:
 ld c,0
 ret
fsm_lit:
 ld a,b
 jp nes_color_modes
fsm_default:
 cp 0xE0
 jp c,fsm_regular
 jp z,fsm_chain_white
 cp 0xE8
 jp nz,fsm_other_belt
 ld a,c
 or a
 ret z
 ld c,0x14              ; MSX E8 uses the cyan chain ink, index 6
 ret
fsm_other_belt:
 cp 0xF0
 ret c
fsm_regular:
 cp 0xA0
 jp c,fsm_not_snake
 cp 0xA8
 jp nc,fsm_not_snake
 ld c,0x10		; snake ink = shared one-plane green, index 4
 ret
fsm_not_snake:
 IFDEF NES_LADDER_LOW
LADDER_IN_JOE_PLANES equ 1
 ; White ladder and its cap live entirely in Joe's C000 plane.
 cp 0x10
 jp z,fsm_white
 cp 0x11
 jp z,fsm_white
 cp 0x88
 jp z,fsm_white
 cp 0x89
 jp z,fsm_white
 ENDIF
 cp 0x38
 ld c,8                  ; solid red body, palette index 2
 ret z
 cp 0xD6
 jp z,fsm_cyan
 cp 0xD7
 jp z,fsm_cyan
 cp 0xCA
 jp z,fsm_accent
 cp 0xCB
 jp z,fsm_accent
 cp 0xCC
 jp z,fsm_white
 cp 0xCD
 jp z,fsm_white
 rrca
 rrca
 rrca
 and 31
 push hl
 ld hl,full_modes
 call add_hl_a
 ld c,(hl)
 pop hl
 ret
; Two tiny ink handlers occupy the six bytes after the persistent snake code.
; This leaves the three-colour build below PS_TOP without changing runtime RAM.
style_low_after_inks equ $
 ORG 0x6FF8
 ASSERT nes_snake_end <= $
fsm_cyan: ld c,0x14
 ret
fsm_accent: ld c,4
 ret
nes_style_tail_end equ $
 ASSERT nes_style_tail_end <= 0x7000
 ORG style_low_after_inks
fsm_chain_white:
 ld a,c
 or a
 ret z
fsm_white: ld c,1
 ret
 INCLUDE "gen/style_full.asm"
 ELSE
 INCLUDE "gen/style.asm"
 ENDIF
