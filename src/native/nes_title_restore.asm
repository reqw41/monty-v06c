; Permanent NES title restoration. The packed screen lives in low RAM freed
; by excluding unused MSX VDP artwork, never in the visible screen planes.
title_resume:
 di
 ld sp,0x7F60
 ld hl,title_packed
 ld de,0x8000
 call title_zx0
 ld hl,0x7000
 ld bc,0x0329                ; retain motion/menu/joystick helpers at 7329..737F
 ld e,0
 call memfill
 ld hl,cmap
 ld bc,16
 ld e,0
 call memfill
 ld a,NES_TITLE_TEXT_SLOT
 ld (cmap+15),a
 ld de,title_warm_palette
 ld hl,pal
 ld bc,16
 call copy_de_hl
 ld a,1
 ld (pal_load),a
 xor a
 ld (video_enabled),a
 ld (video_dirty),a
 ld (crit_pend),a
 ei
title_warm_menu:
 ld hl,menu_txt
 ld de,MENU_POS
 call txt_draw
 ld a,1
 ld (kb_req),a
 call frame_wait
 call cheat_menu_keys
 jp nc,title_warm_menu
title_warm_choice:
 call title_animate
 di
 ld sp,GSTACK
 jp warm_restart

; Forward ZX0 v2, i8080 port of Einar Saukas' standard decoder.
; HL compressed source; DE destination. A is the interlaced bit buffer.
title_zx0:
 ld bc,0xFFFF
 push bc
 inc bc
 ld a,0x80
tz_literals:
 call tz_elias
 push af
 ex de,hl
 call copy_de_hl
 ex de,hl
 pop af
 add a,a
 jp c,tz_new_offset
 call tz_elias
tz_copy:
 ex (sp),hl
 push hl
 add hl,de
 push af
 ex de,hl
 call copy_de_hl
 ex de,hl
 pop af
 pop hl
 ex (sp),hl
 add a,a
 jp nc,tz_literals
tz_new_offset:
 pop bc
 ld c,0xFE
 call tz_elias_loop
 inc c
 ret z
 ld b,c
 ld c,(hl)
 inc hl
 push af
 ld a,b
 rra
 ld b,a
 ld a,c
 rra
 ld c,a
 jp c,tz_offset_bit_one
 pop af
 push bc
 ld bc,1
 call tz_elias_backtrack
 inc bc
 jp tz_copy
tz_offset_bit_one:
 pop af
 push bc
 ld bc,2
 jp tz_copy
tz_elias:
 inc c
tz_elias_loop:
 add a,a
 jp nz,tz_elias_skip
 ld a,(hl)
 inc hl
 rla
tz_elias_skip:
 ret c
tz_elias_backtrack:
 add a,a
 push af
 ld a,c
 rla
 ld c,a
 ld a,b
 rla
 ld b,a
 pop af
 jp tz_elias_loop

 IFDEF NES_JOE_BLEND80
; Leap from the last roof step, cross the shaft while above the brick edge,
; then catch the rope with hands below its cap. Use the ordinary NES jump pose.
title_jump:
 ld hl,title_jump_path
title_jump_next:
 ld a,(hl)
 or a
 ret z
 inc hl
 ld b,a
 and 63
 add a,64
 ld (spr_new+9),a
 ld a,b
 rlca
 rlca
 and 3
 add a,a
 ld b,a
 ld a,(spr_new+2)
 sub b
 ld (spr_new+2),a
 push hl
 ld a,7
 call title_paint
title_jump_shown:
 pop hl
 jp title_jump_next
title_jump_path:
 ; Packed exact path: bits7..6 = horizontal delta /2; bits5..0 = screen L-64.
 db 40,107,109,112,114,116,117,183,120,121,121,122,122,122,122,185
 db 120,119,118,117,115,113,111,109,106,103,100,97,93,89,21,17
 db 0
title_paint:
 ld (jn_frame),a
 ld a,(jn_rows_count)
title_paint_position:
 ld (spr_new+11),a
 ld a,(spr_new+2)
 rrca
 rrca
 rrca
 and 31
 jp title_paint_width
title_paint_last_column:
 jp z,title_width
 inc b
title_width:
 ld a,b
 ld (spr_new+8),a
 jp title_paint_image
title_paint_image:
 di
 call joe_prepare
 call nes_poll
 call title_wait
 call title_unpaint
title_blit:
 ld hl,(spr_new+7)
 ld (spr_rec+7),hl
 jp joe_put
title_unpaint:
 ld a,(spr_rec+11)
 or a
 ret z
 jp joe_restore
title_wait:
 ei
 halt
 di
 xor a
 ld (nmi_pend),a
 ret
 INCLUDE "gen/title_roof.asm"
 ENDIF
title_warm_palette:
 INCLUDE "gen/title_palette.asm"
menu_txt: db "SELECT LEVEL   1, 2, 3.",0
game_over_txt: db "GAME OVER",0
 INCLUDE "nes_cheats.asm"
 INCLUDE "gen/title_packed.asm"
