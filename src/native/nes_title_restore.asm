; Permanent NES title restoration. The packed screen lives in low RAM freed
; by excluding unused MSX VDP artwork, never in the visible screen planes.
title_resume:
 di
 ld sp,0x7F60
 ld hl,hi_score			; рекорд — до очистки 7000..71FF
 ld de,0x7017
 ld b,3
tr_hi_cmp:
 ld a,(de)
 cp (hl)
 jp c,tr_hi_keep
 jp nz,tr_hi_new
 inc hl
 inc de
 dec b
 jp nz,tr_hi_cmp
 jp tr_hi_keep
tr_hi_new:
 ld de,0x7017
 ld hl,hi_score
 ld bc,3
 call copy_de_hl
tr_hi_keep:
 ld hl,title_packed
 ld de,0x8000
 call title_zx0
 call title_stripes
 call title_scene_draw
 ld hl,0x7000
 ld bc,0x0200                ; 7200..7328 — снимок холодного старта (таблица клеток, слоты врагов,
 ld e,0                      ; размеры Джо): его нельзя обнулять, иначе после GAME OVER нет врагов
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
 call nes_title_music
 ei
 call title_hud
title_warm_menu:
 call title_scene_fire
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

; Title HUD: record in the score box, chosen level in the centre. Arrows
; change the level, Fire (space or joystick) starts; digits 1..3 still start.
title_hud:
 ld a,0xFF			; keys held on entry must be released first
 ld (menu_keys),a
 ld a,(menu_level)
 or a
 jp nz,th_level
 inc a
 ld (menu_level),a
th_level:
 call title_level_draw
 ld hl,hi_score
 ld c,0x80+18
th_byte:
 ld a,(hl)
 push hl
 push af
 rrca
 rrca
 rrca
 rrca
 and 15
 call title_digit
 pop af
 and 15
 call title_digit
 pop hl
 inc hl
 ld a,c
 cp 0x80+30
 jp nz,th_byte
 ret
title_level_draw:
 ld a,(menu_level)
 ld c,0x80+14
; A digit, C column page: NES 16x16 digit at HUD rows 2..3 (C += 2).
; Upper tiles in ink 7 (accent, all planes), lower in ink 2 (A000), as in the game.
title_digit:
 add a,a
 add a,a
 add a,0x18
 cp 0x38
 jp nz,tdg_id
 ld a,0xDA
tdg_id:
 ld l,0xFF-HUD_YSHIFT-16
 ld b,0xFF
 call tdg_pair
 ld l,0xFF-HUD_YSHIFT-24
 ld b,0
 call tdg_pair
 inc c
 inc c
 ret
tdg_pair:
 call tdg_tile
 inc c
 inc a
 call tdg_tile
 dec c
 inc a
 ret
; A tile, C column page, L top offset, B ink mask for 8000 and C000.
tdg_tile:
 push af
 push bc
 push hl
 ld hl,raw_base
 call add_hl_a
 ld l,(hl)
 ld h,0
 add hl,hl
 add hl,hl
 add hl,hl
 ld de,full_raw
 add hl,de
 ex de,hl
 pop hl
 push hl
 ld h,c
 ld c,8
tdg_row:
 ld a,(de)
 and b
 ld (hl),a
 ld a,h
 add a,0x20
 ld h,a
 ld a,(de)
 ld (hl),a
 ld a,h
 add a,0x20
 ld h,a
 ld a,(de)
 and b
 ld (hl),a
 ld a,h
 sub 0x40
 ld h,a
 inc de
 dec l
 dec c
 jp nz,tdg_row
 pop hl
 pop bc
 pop af
 ret
; Menu keys (after F1+F3): CY = start, B = level.
menu_scan:
 ld a,(kbmat+2)
 and 14
 jp nz,ms_digit
 ld a,(kbmat+7)			; Fire = space bit 7 -> bit 0
 rlca
 and 1
 ld b,a
 ld a,(kbmat)			; arrows: 10 left, 20 up, 40 right, 80 down
 and 0xF0
 or b
 ld hl,menu_keys
 ld c,(hl)
 ld (hl),a
 ld b,a
 ld a,c
 cpl
 and b				; newly pressed (CY = 0)
 ret z
 rrca
 jp c,ms_fire
 ld hl,menu_level
 and 0x48			; left or down: lower level
 ld a,(hl)
 jp z,ms_up
 dec a
 jp nz,ms_set
 ld a,3
 jp ms_set
ms_up:
 inc a
 cp 4
 jp c,ms_set
 ld a,1
ms_set:
 ld (hl),a
 call title_level_draw
 or a
 ret
ms_fire:
 ld a,(menu_level)
 ld b,a
 jp ms_normal
ms_digit:
 ld b,255
ms_digit_next:
 inc b
 rrca
 jp nc,ms_digit_next
ms_normal:
 xor a
 jp cheat_menu_store


; Spread the logo/credits mono mask from plane 8000 over all three planes,
; one ink per run of rows (gen/title_stripes.asm), then patch plane 8000.
title_stripes:
 ld hl,title_stripe_tab
ts_run:
 ld c,(hl)			; ink, 0 = end of runs
 inc hl
 inc c
 dec c
 jp z,ts_fix
 ld e,(hl)			; first offset in each column
 inc hl
 ld b,(hl)			; rows
 inc hl
 push hl
 ld d,0x80
ts_col:
 push de
 push bc
ts_row:
 ld a,(de)
 ld h,a				; mask
 ld a,d
 add a,0x40
 ld d,a
 ld a,c				; ink bit 0 → plane C000
 rra
 sbc a,a
 and h
 ld (de),a
 ld a,d
 sub 0x20
 ld d,a
 ld a,c				; ink bit 1 → plane A000
 rra
 rra
 sbc a,a
 and h
 ld (de),a
 ld a,d
 sub 0x20
 ld d,a
 ld a,c				; ink bit 2 → plane 8000
 and 4
 jp nz,ts_keep
 ld (de),a
ts_keep:
 inc e
 dec b
 jp nz,ts_row
 pop bc
 pop de
 inc d
 ld a,d
 cp 0xA0
 jp nz,ts_col
 pop hl
 jp ts_run
ts_fix:
 ld e,(hl)
 inc hl
 ld d,(hl)
 inc hl
 inc d
 dec d
 ret z
 ld a,(hl)
 inc hl
 ld (de),a
 jp ts_fix
 INCLUDE "gen/title_stripes.asm"

; Title scene: a field fragment in native tiles (rows TITLE_SCENE_ROW0..29),
; unpacked into the free room field buffer and drawn by the game's own image
; builder (full_style_modes, style_image, da_img, da_blit) - no tile cache.
; The fire top (D2) cycles the game's four phases every 8 frames.
TT_MAP equ FIELD_VNT
TT_IMG equ TT_MAP+32*(30-TITLE_SCENE_ROW0)
 ASSERT TT_IMG+24 <= FIELD_VNT+768
title_scene_fire:
 ld a,(frames)
 ld c,a
 and 7
 ret nz
 ld a,c
 rrca
 rrca
 rrca
 and 3
 ld (tile_phase),a
 ld a,0xD2
 jp ts_draw
title_scene_draw:
 ld hl,title_scene_packed
 ld de,TT_MAP
 call title_zx0
 xor a
 ld (tile_phase),a
ts_draw:				; A = the only tile to draw, 0 = all
 ld (ts_only+1),a
 ld a,0x31			; lit, as an ordinary room
 ld (room_colors+1),a
 ld hl,TT_MAP
 ld de,0x8000+255-8*TITLE_SCENE_ROW0
ts_cell:
 ld a,(hl)
 or a
 jp z,ts_next
 ld b,a
ts_only:
 ld a,0
 or a
 jp z,ts_go
 cp b
 jp nz,ts_next
ts_go:
 ld a,b
 push hl
 push de
 call ts_image
 pop hl
 push hl
 call da_blit
 pop de
 pop hl
ts_next:
 inc hl
 inc d
 ld a,d
 cp 0xA0
 jp nz,ts_cell
 ld d,0x80
 ld a,e
 sub 8
 ld e,a
 cp 255-8*30+8
 jp nc,ts_cell
 ret
; A = native tile -> its image at TT_IMG (tile_src), as tile_build makes it.
ts_image:
 ld (rr_t),a
 ld b,a
 ld c,1
 call full_style_modes
 ld a,(rr_t)
 cp 0xD2
 jp z,tsi_fire
 ld hl,raw_base
 call add_hl_a
 ld a,(hl)
 jp tsi_strip
tsi_fire:
 ld a,(tile_phase)
 add a,4*FULL_ANIM_D2
 ld hl,raw_anim
 call add_hl_a
 ld a,(hl)
tsi_strip:
 call full_strip
 ld hl,TT_IMG
 ld (tile_dst),hl
 ld (tile_src),hl
 ld a,c
 or a
 push bc
 push de
 call nz,style_image
 pop de
 pop bc
 ret c
 call da_img
 jp nes_terrain_image

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
 db 120,119,118,117,115,113,111,109,106,103,100,97,93,89,85,81    ; last two: 2 px left each, onto the game rope at X116
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
game_over_txt:
 IFDEF RUS
 db "igPA OKOHhEHA",0       ; ИГРА ОКОНЧЕНА: i g h — И Г Ч (gen/font_nes.asm)
 ELSE
 db "GAME OVER",0
 ENDIF
 INCLUDE "nes_cheats.asm"
 INCLUDE "gen/title_packed.asm"
