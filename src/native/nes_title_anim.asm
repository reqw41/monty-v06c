; Title choreography on the game engine (fix37): the hero's own physics (L_9156,
; hero_state, L_8DE8) walks Joe left down the roof steps to the rope cap (a floor
; tile) at X116; Down takes the rope and he slides to the bottom of the scene.
; The scene map lives in the game's own rows (TT_MAP = FIELD_VNT row 12 = VNT row 18,
; the same screen lines); field rows above it are cleared. Game effects are muted
; (L_AC1A = RET) while the title music owns EF00. Drawing: title_paint.
 IFDEF NES_JOE_BLEND80
TT_X0 equ 236                 ; start on the upper roof step (exit right at X 239)
TT_XJ equ 116                 ; on the rope cap (a floor tile): Down climbs onto the rope
title_animate:
 push bc
 xor a
title_scene_ready:
 ld (spr_rec+11),a
 ld hl,FIELD_VNT              ; field rows above the scene (TT_MAP = row 12) are empty
 ld bc,12*32
 ld e,a
 call memfill
 ld hl,TT_X0*256+127          ; 7304 = Y (top of the roof step), 7305 = X
 ld (0x7304),hl
 ld hl,TT_X0*256+124
 ld (0x7300),hl
 ld hl,0x0080                 ; 7078: facing left, 7079: standing
 ld (0x7078),hl
 ld a,0xC9                    ; no game effects over the title music (EF00 is not installed yet)
 ld (L_AC1A),a
title_walk:                   ; 7072/7076/7077/705F are zero: title_resume clears 7000..71FF, cold boot from ram0
 ld c,0x88                    ; left
 ld a,(0x7305)
 cp TT_XJ+1
 jp nc,tw_input
 ld c,0x84                    ; down onto the rope
tw_input:
 ld a,c
 ld (0x73EE),a
 call L_9156
 call hero_state
 call L_8DE8
 ld a,(0x7305)
 ld (spr_new+2),a
 rrca                         ; walking phase from X (no footstep clicks on the title)
 and 3
 ld (jn_walk),a
 ld a,0xF4
 ld hl,0x7304
 sub (hl)
 ld (spr_new+9),a
 ld a,(hl)                    ; rope hand phase from Y (instead of joe_clock's tick)
 ld (jn_tick),a
 call joe_select
 push af
 ld a,(0x7079)
 cp 4
 ld hl,22*256+1               ; walking/step poses: skip the empty top row
 jp nz,tw_rows
 ld hl,23*256+0               ; rope poses: all 23 rows
tw_rows:
 ld (jn_skip),hl              ; jn_skip, jn_rows_count
 pop af
 call title_paint
title_walk_shown:
 ld a,(0x7304)
 cp 206                       ; down the rope to the bottom of the scene (exit below is Y 221)
 jp c,title_walk
 ld a,0xF5                    ; L_AC1A: PUSH AF again
 ld (L_AC1A),a
 call title_wait
 call title_unpaint
 pop bc
 ei
 ret
title_animate_end:

 ; Keep the new horizontal bounds separate until the old pose is restored.
 ORG 0xFAEF
title_paint_width:
 ld (spr_new+10),a
 ld (spr_new+7),a
 inc a
 ld b,a
 ld a,(spr_new+2)
 and 7
 jp title_paint_last_column
 ASSERT $ <= 0xFB00
 ORG title_animate_end
 ELSE
title_animate:
 ret
 ENDIF
