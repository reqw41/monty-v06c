; NES presentation over the unchanged MSX map and logical HUD.
; Index 2 belongs to the room; Joe uses white 1 and dark brown 3.
style_palette:
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
 cp 9
 jp c,stp_row
 xor a
stp_row:
 ld hl,style_accents
 call add_hl_a
 ld a,(hl)
 ld (pal+4),a
 ld (pal+5),a
 IFDEF NES_FULL
 jp nes_snake_palette
 ELSE
 ret
 ENDIF
copy_de_hl_swap:
 ex de,hl
 jp copy_de_hl
style_cmap: db 0,0,6,6,6,6,3,6,2,2,2,1,6,2,4,4
style_pal: db 0,0,255,255,31,31,3,3,255,255,255,255,160,160,255,255

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
 cp 0x6E
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
 cp 0xE0
 jp c,fsm_regular
 cp 0xF0
 ret c
fsm_regular:
 cp 0xA0
 jp c,fsm_not_snake
 cp 0xA8
 jp nc,fsm_not_snake
 ld c,0x11		; snake ink = private palette index 5
 ret
fsm_not_snake:
 cp 0x38
 ld c,8
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
fsm_cyan: ld c,0x14
 ret
fsm_accent: ld c,4
 ret
fsm_white: ld c,1
 ret
 INCLUDE "gen/style_full.asm"
 ELSE
 INCLUDE "gen/style.asm"
 ENDIF
