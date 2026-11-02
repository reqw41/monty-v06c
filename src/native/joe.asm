 ASSERT JOE_PICTURE+12*joe_nes_rows <= JOE_BACKGROUND
 ASSERT JOE_BACKGROUND+3*JOE_BACKGROUND_STRIDE*joe_nes_rows <= 0xFB00
 IFDEF NES_JOE_3COLOR
NES_JOE_COLORS equ 3
 ELSE
NES_JOE_COLORS equ 2
 ENDIF
; NES Joe, a foot-anchored cell of joe_nes_rows rows; leading empty rows are omitted.
; One cached M/C/pad/A image in F900..FA13; SP restore packs C/A background
; into FA20..FAA9, other builds retain the C/A/80 background layout.
; POP AF ignores the padding byte; C keeps the mask from POP BC.
; Slot 1 keeps only the original MSX attributes; its unused rectangles hold private scratch.
; Fields +13/+15 of slot 1 remain planner marks; 66FC..FF is outside band_pairs.
joe_clock:
 push af
 push hl
 ld hl,jn_epoch
 inc (hl)
 ld a,(0x7079)
 IFDEF NES_FULL
 cp 3
 jp z,jc_ladder
 cp 4
 jp z,jc_ladder
 ENDIF
 cp 1
 jp nz,jc_idle
 ld hl,jn_tick
 inc (hl)
 ld a,(hl)
 cp 6
 jp c,jc_end
 ld (hl),0
 ld hl,jn_walk
 inc (hl)
 ld a,(hl)
 and 3
 ld (hl),a
 IFDEF NES_FULL
 call joe_footstep
 ENDIF
 jp jc_end
 IFDEF NES_FULL
jc_ladder:
 ; NES animation 04 has four ticks per pose. Advance only while moving,
 ; independently of the MSX two-tick selector; keep its natural two poses.
 ld a,(0x7077)
 ld hl,0x7076
 or (hl)
 jp z,jc_end
 ld hl,jn_tick
 inc (hl)
 call nes_ladder_step
 ld a,(hl)
 cp 8
 jp c,jc_end
 ld (hl),0
 jp jc_end
 ENDIF
jc_idle:
 xor a
 ld (jn_tick),a
 ld (jn_walk),a
jc_end:
 pop hl
 pop af
 ret
joe_select:
 ld a,(0x7078)
 and 0x80
 ld (jn_dir),a
 ld a,(0x7079)
 cp 1
 jp z,js_walk
 cp 2
 ld b,7
 jp z,js_b
 cp 5
 IFDEF NES_FULL
 jp z,js_slide
 ELSE
 jp z,js_b
 ENDIF
 cp 6
 jp z,js_b
 cp 7
 jp z,js_b
 ; State 3 climbs the two-column ladder (88/89, top 10/11),
 ; in both directions. Select by state, independently of MSX layer order.
 cp 3
 IFDEF NES_FULL
 jp z,js_nes_ladder
 ELSE
 jp z,js_lad_phase
 ENDIF
 cp 4
 jp z,js_ladder
 cp 8
 jp z,js_death
 cp 9
 IFDEF NES_FULL
 jp z,js_fall
 ELSE
 ld b,18
 jp z,js_b
 ENDIF
 cp 10
 jp z,js_fall
 xor a
 ret
js_walk:
 ld a,(jn_walk)
 inc a
 ret
 IFDEF NES_FULL
js_slide:
 ld a,(0x7058)
 cp 0x95
 ld b,11
 jp z,js_b
 ld b,7
 jp js_b
 ENDIF
js_ladder:
 ld a,(0x7058)
 cp 0x90
 IFDEF NES_FULL
 jp z,js_chain_phase
 ELSE
 ld b,11
 jp z,js_b
 ENDIF
 cp 0x95
 IFDEF NES_FULL
 ld b,11
 ENDIF
 jp z,js_b
 cp 0x98
 ld b,12
 jp z,js_b
 cp 0xD8
 jp z,js_b
 cp 8
 jp nz,js_lad_phase
js_chain_phase:
 IFDEF NES_FULL
 ld a,(jn_tick)
 rrca
 ELSE
 ld a,(0x70AA)
 ENDIF
 and 2
 ld b,10
 jp z,js_b
 ld b,19
 jp js_b
js_lad_phase:
 IFDEF NES_FULL
 ld a,(jn_tick)
 rrca
 ELSE
 ld a,(0x70AA)
 ENDIF
 rrca
 and 1
 add a,8
 ret
js_death:
js_death_phase:
 ld a,(0x70A9)
 ld b,a
 ld a,112
 sub b
 ld b,a
 ld a,(jn_fire)
 or a
 ld a,b
 ld c,24
 ld b,13
 jp z,js_div
 ld c,40
 ld b,20
js_div:
 cp c
 jp c,js_b
 sub c
 inc b
 jp js_div
js_hazard:
 cp 0x38
 jp z,js_hot
 cp 0xD0
 ret c
 cp 0xD6
 jp c,js_hot
 cp 0xE0
 ret nz
js_hot:
 ld a,1
 ld (jn_fire),a
 ret
js_fall:
 IFDEF NES_FULL
 ld a,(jn_fire)
 or a
 jp nz,js_fall_fire
 ld a,(0x70A9)
 cp 53                 ; NES death_tumble: two frames, 30 ticks each
 jp c,js_blank
 ld b,6
 cp 83
 jp c,js_b
 ld b,5
 jp js_b
js_fall_fire:
 ld a,(0x70A9)       ; NES death_burst: three frames, 9 ticks each
 cp 86
 jp c,js_blank
 ld b,22
 cp 95
 jp c,js_b
 ld b,21
 cp 104
 jp c,js_b
 ld b,20
 jp js_b
js_blank:
 ld b,18
 jp js_b
 ELSE
 ld a,(0x70A9)
 rrca
 rrca
 rrca
 and 1
 add a,5
 ret
 ENDIF
js_b:
 ld a,b
 ret
 IFDEF NES_FULL
; Physics keeps its MSX anchor at ladder X-1. Shift only the NES pixels.
NES_LADDER_CENTERED equ 0
jn_visual_x:
 ld a,(spr_new+2)
 ret
jn_visual_x_end:

 ENDIF
joe_plan:
 ld a,(jn_hold)
 or a
 ret nz
 call joe_select
 ld hl,jn_frame
 cp (hl)
 ld (hl),a
 call nz,jn_mark
 ld a,(jn_dir)
 ld hl,jn_key+1
 cp (hl)
 call nz,jn_mark
 ld a,(jn_epoch)
 ld (jn_ready_epoch),a
 ld a,(spr_rec+29)
 ld hl,spr_rec+13
 or (hl)
 ld (hl),a
 ld a,(spr_rec+31)
 ld hl,spr_rec+15
 or (hl)
 ld (hl),a
 xor a
 ld (spr_rec+29),a
 ld (spr_rec+31),a
 ld (spr_new+16),a
 ld a,(spr_rec+15)
 or a
 ret z
 ld a,(spr_new+1)
 inc a
 ld c,a
 ld a,(spr_new+4)
 and 0x8F
 ld b,a
 ld a,(spr_new+17)
 inc a
 ld e,a
 ld a,(spr_new+20)
 and 0x8F
 or b
 jp z,jn_hidden
 jp m,jn_hidden
 ld a,c
 cp SCREEN_HEIGHT
 jp c,jn_foot0
 ld c,e
jn_foot0:
 ld a,e
 cp SCREEN_HEIGHT
 jp nc,jn_foot
 cp c
 jp c,jn_foot
 ld c,e
jn_foot:
 ld a,c
 cp SCREEN_HEIGHT
 jp nc,jn_hidden
 ld a,(jn_frame)
 ld hl,joe_top_rows
 call add_hl_a
 ld e,(hl)
 ld a,c
 add a,e
 sub joe_nes_rows-16
 ld b,e
 jp nc,jn_top_ready
 cpl
 inc a
 add a,b
 ld b,a
 xor a
jn_top_ready:
 IFDEF NES_FULL
 cp HUD_ROWS*8
 jp nc,jn_full_field
 ld c,a
 ld a,HUD_ROWS*8
 sub c
 add a,b
 cp joe_nes_rows
 jp nc,jn_hidden
 ld b,a
 ld a,HUD_ROWS*8
jn_full_field:
 ENDIF
 cp SCREEN_HEIGHT
 jp nc,jn_hidden
 ld c,a
 ld a,b
 ld (jn_skip),a
 ld a,joe_nes_rows
 sub b
 ld b,a
 ld a,SCREEN_HEIGHT
 sub c
 cp b
 jp nc,jn_rows
 ld b,a
jn_rows:
 ld a,b
 ld (jn_rows_count),a
 ld hl,spr_new+5
 ld a,c
 rrca
 rrca
 rrca
 and 31
 ld (hl),a
 inc l
 ld a,c
 add a,b
 dec a
 rrca
 rrca
 rrca
 and 31
 ld (hl),a
 inc l
 IFDEF NES_FULL
 call jn_visual_x
 ELSE
 ld a,(spr_new+2)
 ENDIF
 rrca
 rrca
 rrca
 and 31
 ld (hl),a
 inc l
 ld d,a
 IFDEF NES_FULL
 call jn_visual_x
 ELSE
 ld a,(spr_new+2)
 ENDIF
 and 7
 ld a,1
 jp z,jn_width
 inc a
jn_width:
 add a,d
 cp 32
 jp c,jn_right
 ld a,31
jn_right:
 ld (hl),a
 ld hl,spr_new+9
 IFDEF NES_FULL
 ld a,SCREEN_TOP-FIELD_YSHIFT
 ELSE
 ld a,SCREEN_TOP
 ENDIF
 sub c
 ld (hl),a
 inc l
 ld a,(spr_new+7)
 ld (hl),a
 inc l
 ld (hl),b
 inc l
 ld (hl),0
 inc l
 inc l
 ld (hl),1
 ld a,1
 jp jn_visible
jn_hidden:
 xor a
 ld (spr_new+14),a
jn_visible:
 ld hl,spr_new
 cp (hl)
 ld (hl),a
 call nz,jn_mark
 ret
jn_mark:
 push af
 ld a,1
 ld (spr_rec+13),a
 ld (spr_rec+15),a
 pop af
 ret
joe_copy_second:
 ld de,spr_new+17
 ld hl,spr_rec+17
 ld b,4
 jp memcpyb
joe_prepare:
 ld a,1
 ld (spr_new+14),a
 call jn_pre                ; HL = jn_key; прежний ключ — в jn_old (joe_cache.asm)
 ld c,0
 ld a,(jn_frame)
 call mk_cmp
 ld a,(jn_dir)
 call mk_cmp
 IFDEF NES_FULL
 call jn_visual_x
 ELSE
 ld a,(spr_new+2)
 ENDIF
 and 7
 call mk_cmp
 ld a,(jn_skip)
 call mk_cmp
 ld a,(jn_rows_count)
 call mk_cmp
 call jn_cache              ; Z — образ готов (тот же или второй в кэше)
 ret z
 IFDEF NES_FULL
 call jn_visual_x
 ELSE
 ld a,(spr_new+2)
 ENDIF
 and 7
 ; JP skips column 3 for aligned X. LXI B consumes the same two-byte
 ; operand for shifted X; B/C are dead after the middle column.
 ld hl,jn_third_column
 ld (hl),0xC3
 or a
 jp z,jn_third_ready
 ld (hl),0x01
jn_third_ready:
 ; Joe uses nibble lookup tables, not the legacy rotate_byte procedure.
 ld b,a
 add a,a
 add a,a
 add a,a
 add a,a
 or joe_nibble_rotations&255
 ld (jn_lookup0+1),a
 ld (jn_lookup1+1),a
 ld (jn_lookup2+1),a
 ld (jn_lookup3+1),a
 ld a,255
 inc b
 jp jn_mask_test
jn_mask_loop:
 or a
 rra
jn_mask_test:
 dec b
 jp nz,jn_mask_loop
 IFDEF NES_JOE_3COLOR
 ld (jn_m0_mask+1),a
 ENDIF
 ld (jn_a0_mask+1),a
 ld (jn_c0_mask+1),a
 ld (jn_a1_mask+1),a
 ld (jn_c1_mask+1),a
 cpl
 ld (jn_a2_mask+1),a
 ld (jn_c2_mask+1),a
 ld a,(jn_frame)
 add a,a
 ld hl,joe_nes_frames
 call add_hl_a
 ld e,(hl)
 inc hl
 ld d,(hl)
 ld a,(jn_skip)
 ld l,a
 ld h,0
 add hl,de
 ld (jn_prep_source+1),hl
 ld a,(jn_rows_count)
 add a,a
 add a,a
 IFDEF NES_JOE_3COLOR
 sub 3
 ld (jn_stride1+1),a
 ld (jn_stride2+1),a
 add a,3
 ELSE
 ld (jn_stride),a
 ENDIF
 add a,JOE_PICTURE&255
 ld (jn_prep_end+1),a
 ld a,JOE_PICTURE&255
 ld (jn_dest_read+1),a
 ld a,(jn_dir)
 rlca
 and joe_row_mirror_xor
jn_mirror_ready:
 ld (jn_mirror_branch+1),a
jn_prep_row:
jn_prep_source:
 ld hl,0
 ld a,(hl)
 inc hl
 ld (jn_prep_source+1),hl
jn_mirror_branch:
 xor 0
jn_row_index:
 ld l,a
 ld h,joe_row_lo/256
 ld d,(hl)
 inc h
 ld e,(hl)
 ld h,joe_nibble_rotations/256
 ld a,d
 rrca
 rrca
 rrca
 rrca
 and 15
jn_lookup0:
 or 0
 ld l,a
 ld b,(hl)
 ld a,d
 and 15
jn_lookup1:
 or 0
 ld l,a
 ld c,(hl)
 ld a,e
 rrca
 rrca
 rrca
 rrca
 and 15
jn_lookup2:
 or 0
 ld l,a
 ld d,(hl)
 ld a,e
 and 15
jn_lookup3:
 or 0
 ld l,a
 ld e,(hl)
jn_dest_read:
 ld hl,JOE_PICTURE
 IFDEF NES_JOE_3COLOR
 ; Form the left mask in registers and write M/C/pad/A forwards.
 ; B/C retain their unmasked source bytes for the middle column.
 ld a,b
 or c
jn_m0_mask:
 and 255
 cpl
 ld (hl),a
 inc l
 ld a,c
jn_c0_mask:
 and 255
 ld (hl),a
 inc l
 inc l
 ld a,b
jn_a0_mask:
 and 255
 ld (hl),a
jn_stride1:
 ld a,0
 ELSE
 ld a,b
jn_a0_mask:
 and 255
 inc l
 inc l
 inc l
 ld (hl),a
 ld a,c
jn_c0_mask:
 and 255
 dec l
 dec l
 ld (hl),a
 IFDEF NES_JOE_3COLOR
 inc l
 inc l
 or (hl)
 dec l
 dec l
 ENDIF
 cpl
 dec l
 ld (hl),a
 ld a,(jn_stride)
 ENDIF
 add a,l
 ld l,a
 jp nc,jn_column1
 inc h
jn_column1:
 IFDEF NES_JOE_3COLOR
 ; The left source bytes are no longer needed. Keep the middle inks in
 ; B/C, form the union mask in registers, then write M/C/pad/A forwards.
 ld a,b
 xor d
jn_a1_mask:
 and 255
 xor b
 ld b,a
 ld a,c
 xor e
jn_c1_mask:
 and 255
 xor c
 ld c,a
 ld a,b
 or c
 cpl
 ld (hl),a
 inc l
 ld (hl),c
 inc l
 inc l
 ld (hl),b
 ELSE
 ld a,b
 xor d
jn_a1_mask:
 and 255
 xor b
 inc l
 inc l
 inc l
 ld (hl),a
 ld a,c
 xor e
jn_c1_mask:
 and 255
 xor c
 dec l
 dec l
 ld (hl),a
 IFDEF NES_JOE_3COLOR
 inc l
 inc l
 or (hl)
 dec l
 dec l
 ENDIF
 cpl
 dec l
 ld (hl),a
 ENDIF
jn_third_column:
 jp jn_row_done
 IFDEF NES_JOE_3COLOR
jn_stride2:
 ld a,0
 ELSE
 ld a,(jn_stride)
 ENDIF
 add a,l
 ld l,a
 jp nc,jn_column2
 inc h
jn_column2:
 IFDEF NES_JOE_3COLOR
 ld a,d
jn_a2_mask:
 and 0
 ld d,a
 ld a,e
jn_c2_mask:
 and 0
 ld e,a
 or d
 cpl
 ld (hl),a
 inc l
 ld (hl),e
 inc l
 inc l
 ld (hl),d
 ELSE
 ld a,d
jn_a2_mask:
 and 0
 inc l
 inc l
 inc l
 ld (hl),a
 ld a,e
jn_c2_mask:
 and 0
 dec l
 dec l
 ld (hl),a
 IFDEF NES_JOE_3COLOR
 inc l
 inc l
 or (hl)
 dec l
 dec l
 ENDIF
 cpl
 dec l
 ld (hl),a
 ENDIF
jn_row_done:
 ; The first column occupies at most 23*4 bytes, within one page.
 ASSERT (JOE_PICTURE&255)+4*joe_nes_rows <= 256
 ld a,(jn_dest_read+1)
 add a,4
 ld (jn_dest_read+1),a
jn_prep_end:
 cp 0
 jp nz,jn_prep_row
 ret
joe_put:
 ld a,(jn_hold)
 or a
 jp nz,jn_put_geometry
 ld a,(jn_ready_epoch)
 ld (jn_last_epoch),a
jn_put_geometry:
 ld hl,spr_rec+9
 ld de,spr_new+9
 REPT 4
 ld a,(de)
 ld (hl),a
 inc e
 inc l
 ENDR
 ld a,(jn_frame)
 ld (jn_shown),a
 ld a,(jn_dir)
 ld (jn_shown_dir),a
 ld a,(jn_skip)
 ld (jn_shown_skip),a
 IFDEF NES_JOE_BLEND80
NES_JOE_BLEND_MODE equ 1
 ; Experimental: preserve the background's third colour bit through Joe.
jn_blend_select:
 ld a,1
 ld (jn_no80),a
 ELSE
 call jn_test80
 ENDIF
jn_put_tested:
 IFNDEF NES_JOE_BLEND80
 ld hl,jn_put_full
 ld de,jn_put_full_second-jn_put_full
 ld a,(jn_no80)
 or a
 jp z,jn_put_select
 ENDIF
 ld hl,jn_put_two
 ld de,jn_put_two_second-jn_put_two
jn_put_select:
 ld (jn_put_repeat+1),hl
 ld a,(spr_rec+11)
 and 1
 jp z,jn_put_initial
 add hl,de
jn_put_initial:
 ld (jn_put_row+1),hl
 ; IRQ owns the stack until it is restored; no calls or interrupts in the loop.
 ld hl,0
 add hl,sp
 ld (jn_stack),hl
jn_put_sp:
 ld sp,JOE_PICTURE          ; страница — текущий образ кэша (joe_cache.asm)
jn_put_background:
 ld de,JOE_BACKGROUND
 ld hl,spr_rec+7
 ld a,(spr_rec+8)
 sub (hl)
 inc a
 ld (jn_columns),a
 ld a,(spr_rec+10)
 add a,0xC0
 ld h,a
jn_put_col:
 ; The three screen pages are constant through this column. Patch the
 ; selected loop once rather than doing H arithmetic for every plane/row.
 IFNDEF NES_JOE_BLEND80
 ld a,(jn_no80)
 or a
 ld a,h
 jp nz,jn_pages_two
 ld (jn_full_c0+1),a
 ld (jn_full_c1+1),a
 sub 0x20
 ld (jn_full_a0+1),a
 ld (jn_full_a1+1),a
 sub 0x20
 ld (jn_full_800+1),a
 ld (jn_full_801+1),a
 jp jn_pages_ready
 ELSE
 ld a,h
 ENDIF
jn_pages_two:
 ld (jn_two_c0+1),a
 ld (jn_two_c1+1),a
 sub 0x20
 ld (jn_two_a0+1),a
 ld (jn_two_a1+1),a
jn_pages_ready:
 ld a,(spr_rec+9)
 ld l,a
 ld a,(spr_rec+11)
 ld c,a
 ld a,l
 sub c
 ld (jn_put_end+1),a
jn_put_row:
 IFDEF NES_JOE_BLEND80
 jp jn_put_two
 ELSE
 jp jn_put_full
 ENDIF
 IFNDEF NES_JOE_BLEND80
jn_put_full:
 ; Every byte commits C, A, 8000 together; cache words are M/C and pad/A.
 pop bc
 ld a,(hl)
 ld (de),a
 IFDEF NES_JOE_3COLOR
 and c
 ENDIF
 or b
 ld (hl),a
 inc e
jn_full_a0:
 ld h,0xA0
 pop af
 ld b,a
 ld a,(hl)
 ld (de),a
 and c
 or b
 ld (hl),a
 inc e
jn_full_800:
 ld h,0x80
 ld a,(hl)
 ld (de),a
 and c
 ld (hl),a
 inc e
jn_full_c0:
 ld h,0xC0
 dec l
 IFDEF NES_JOE_BLEND80
 ; Keep a compact optional three-plane path. Gameplay and title animation
 ; both use the unchanged two-row, two-plane loop below.
 jp jn_put_count
jn_put_full_second equ jn_put_full
jn_full_a1 equ jn_full_a0
jn_full_801 equ jn_full_800
jn_full_c1 equ jn_full_c0
 ELSE
jn_put_full_second:
 ; Every byte commits C, A, 8000 together; cache words are M/C and pad/A.
 pop bc
 IFDEF NES_JOE_BLEND80
 ld a,b
 ld (jn_title_xor1+1),a
 ld (jn_title_and1+1),a
 ENDIF
 ld a,(hl)
 ld (de),a
 IFDEF NES_JOE_3COLOR
 and c
 ENDIF
 or b
 ld (hl),a
 inc e
jn_full_a1:
 ld h,0xA0
 pop af
 IFDEF NES_JOE_BLEND80
jn_title_xor1:
 xor 0
 ENDIF
 ld b,a
 ld a,(hl)
 ld (de),a
 and c
 or b
 ld (hl),a
 inc e
jn_full_801:
 ld h,0x80
 IFDEF NES_JOE_BLEND80
 ld a,b
jn_title_and1:
 and 0
 ld b,a
 ENDIF
 ld a,(hl)
 ld (de),a
 and c
 IFDEF NES_JOE_BLEND80
 or b
 ENDIF
 ld (hl),a
 inc e
jn_full_c1:
 ld h,0xC0
 dec l
 jp jn_put_count
 ENDIF
 ENDIF
jn_put_two:
 pop bc
 ld a,(hl)
 ld (de),a
 IFDEF NES_JOE_3COLOR
 and c
 ENDIF
 or b
 ld (hl),a
 inc e
jn_two_a0:
 ld h,0xA0
 pop af
 ld b,a
 ld a,(hl)
 ld (de),a
 and c
 or b
 ld (hl),a
 inc e
 IF JOE_BACKGROUND_STRIDE == 3
 inc e ; unused 8000 background byte
 ENDIF
jn_two_c0:
 ld h,0xC0
 dec l
jn_put_two_second:
 pop bc
 ld a,(hl)
 ld (de),a
 IFDEF NES_JOE_3COLOR
 and c
 ENDIF
 or b
 ld (hl),a
 inc e
jn_two_a1:
 ld h,0xA0
 pop af
 ld b,a
 ld a,(hl)
 ld (de),a
 and c
 or b
 ld (hl),a
 inc e
 IF JOE_BACKGROUND_STRIDE == 3
 inc e ; unused 8000 background byte
 ENDIF
jn_two_c1:
 ld h,0xC0
 dec l
jn_put_count:
 ld a,l
jn_put_end:
 cp 0
jn_put_repeat:
 IFDEF NES_JOE_BLEND80
 jp nz,jn_put_two
 ELSE
 jp nz,jn_put_full
 ENDIF
 inc h
 ld a,(jn_columns)
 dec a
 ld (jn_columns),a
 jp nz,jn_put_col
 ld hl,(jn_stack)
 ld sp,hl
 ret

joe_restore:
 IFDEF NES_JOE_SP_RESTORE
 IFNDEF NES_JOE_BLEND80
 ASSERT 0 ; This experimental restore requires the two-plane-only put.
 ENDIF
 INCLUDE "joe_restore_sp.asm"
 ELSE
 push bc
 ld hl,spr_rec+9
 call en_load
 ld a,(jn_no80)
 or a
 jp z,jn_restore_three
 ld a,(st_rows)
 and 7
 add a,a
 ld e,a
 add a,a
 add a,a
 add a,a
 add a,e ; 18 * (R & 7)
 ld e,a
 ld a,jn_restore_two_end & 255
 sub e
 ld l,a
 ld h,jn_restore_two_end / 256
 ld (jn_restore_partial+1),hl
 ld hl,jn_restore_two
 ld (jn_restore_groups+1),hl
 ld de,JOE_BACKGROUND+1
 ld a,0xA0
 jp jn_restore_ready
jn_restore_three:
 ld a,(st_rows)
 and 7
 ld hl,jn_restore_end
 cp 5
 jp c,jn_restore_tail
 sub 4
 ld hl,jn_restore_first_end
jn_restore_tail:
 ld e,a
 add a,a
 add a,e
 add a,a
 add a,a
 add a,a
 add a,e ; 25 * (R & 7), at most 175 bytes
 ld e,a
 ld a,l
 sub e
 ld l,a
 ld (jn_restore_partial+1),hl
 ld hl,jn_restore_row
 ld (jn_restore_groups+1),hl
 ld de,JOE_BACKGROUND+2
 ld a,0x80
 jp jn_restore_ready
jn_restore_ready:
 ld (sp_pm),a
 ld a,(spr_rec+9)
 ld c,a
 ld hl,spr_rec+7
 ld a,(spr_rec+8)
 sub (hl)
 inc a
 ld (jn_columns),a
 ld a,(sp_pm)
 ld h,a
 ld a,(spr_rec+10)
 add a,h
 ld h,a
jn_restore_col:
 ld l,c
 ld a,(st_rows)
 rrca
 rrca
 rrca
 and 3
 ld b,a
jn_restore_partial:
 call jn_restore_end
 ld a,b
 or a
 jp z,jn_restore_next
jn_restore_groups:
 call jn_restore_row
 dec b
 jp nz,jn_restore_groups
jn_restore_next:
 inc h
 ld a,(jn_columns)
 dec a
 ld (jn_columns),a
 jp nz,jn_restore_col
 pop bc
 ret
 ENDIF
; Skipping an unchanged plane is safe even when other sprites overlap: Joe
; made no writes there, so his matching restore must also make no writes.
 IFNDEF NES_JOE_BLEND80
jn_test80:
 xor a
 ld (jn_no80),a
 ld hl,spr_rec+9
 call en_load
 ld hl,spr_rec+7
 ld a,(spr_rec+8)
 sub (hl)
 inc a
 ld b,a
 ld a,(sv_col)
 add a,0x80
 ld h,a
 ld a,(sv_lo)
 ld l,a
 ld e,a
 ld a,(st_rows)
 ld c,a
 xor a
jn_scan80_col:
 ld d,c
jn_scan80_row:
 or (hl)
 ret nz
 dec l
 dec d
 jp nz,jn_scan80_row
 ld l,e
 inc h
 dec b
 jp nz,jn_scan80_col
 inc a
 ld (jn_no80),a
 ret
 ENDIF
jn_no80 equ spr_rec+30
jn_stack equ spr_new+23
jn_tick: db 0
jn_walk: db 0
jn_frame: db 255
jn_dir: db 0
jn_fire: db 0
jn_skip: db 0
jn_rows_count: db 0
jn_shown: db 0
jn_shown_dir: db 0
jn_shown_skip: db 0
 IF ($ & 255) > 251
 ALIGN 256
 ENDIF
jn_key: db 255,255,255,255,255
 ASSERT jn_key/256 == (jn_key+4)/256
jn_left equ spr_new+25
jn_stride equ spr_new+26
jn_source equ spr_new+27
jn_dest equ spr_new+21
jn_columns equ spr_rec+26


bg_turn equ 0x66FF
joe_motion_pending:
 xor a
 ld hl,spr_rec+1
 call obj_ptr
 ld a,(de)
 cp (hl)
 ret nz
 inc de
 inc hl
 ld a,(de)
 cp (hl)
 ret nz
 ld a,1
 ld hl,spr_rec+17
 call obj_ptr
 ld a,(de)
 cp (hl)
 ret nz
 inc de
 inc hl
 ld a,(de)
 cp (hl)
 ret nz
jn_motion_valid:
 IFDEF NES_FULL
 ; A brief walking reversal can return to the last painted X. Do not count
 ; that cancelled displacement as a fresh paint and restart the visual gate.
 ld a,(0x7079)
 cp 1
 ret z
 ENDIF
 ld a,(jn_epoch)
 ld (jn_last_epoch),a
 IFDEF NES_FULL
 cp a                       ; position comparison succeeded in every state
 ENDIF
 ret
jn_hold equ spr_rec+28

; Capture the collision context before death motion changes the sampled tiles.
jn_capture_death:
 push af
 ld a,(0x7079)
 cp 8
 jp z,jn_capture_done
 xor a
 ld (jn_fire),a
 IFDEF NES_FULL
 ld a,(0x7057)
 call js_hazard
 ld a,(0x7059)
 call js_hazard
 ld a,(0x705A)
 call js_hazard
 ld a,(0x705C)
 call js_hazard
 ENDIF
 ld a,(0x7058)
 call js_hazard
 ld a,(0x705B)
 call js_hazard
jn_capture_done:
 pop af
 ret
jn_epoch equ 0x66FC
jn_last_epoch equ 0x66FD
jn_ready_epoch equ 0x66FE

jn_wait equ spr_rec+24
jn_delta equ spr_rec+25

; No frame_handler here: waiting for display must not advance the game clock.
joe_step_gate:
 push af
 push hl
 ld a,(jn_epoch)
 ld hl,jn_last_epoch
 sub (hl)
 cp 2
 jp nc,jsg_full
 ; The picture queued for the next IRQ is also subject to the deadline.
 ld a,(spr_rec+13)
 or a
 jp z,jsg_fast
 ld a,(jn_epoch)
 ld hl,jn_ready_epoch
 sub (hl)
 cp 2
 jp c,jsg_fast
jsg_full:
 push bc
 push de
 ld hl,0
 add hl,sp
 ld (np_sp),hl
 ld sp,DISP_STACK
 ld a,1
 ld (jn_wait),a
 call joe_gate
 xor a
 ld (jn_wait),a
 ld hl,(np_sp)
 ld sp,hl
 pop de
 pop bc
jsg_fast:
 pop hl
 pop af
 ret
