; Title choreography uses the game's two-plane put and packed SP restore.
; Prepare the next pose before waiting for VBlank; erase and paint together.
 IFDEF NES_JOE_BLEND80
title_animate:
 push bc
 xor a
title_scene_ready:
 ld (spr_rec+11),a
 ld a,128
 ld (jn_dir),a
 ld a,240
 ld (spr_new+2),a
title_walk:
 ld a,1
 ld (jn_skip),a
 ld a,22
 ld (jn_rows_count),a
 ld a,(spr_new+2)
 ld b,a
 rrca
 rrca
 rrca
 and 31
 sub 23
 add a,a
 ld c,a
 ld a,b
 and 7
 jp z,title_roof_index
 inc c
title_roof_index:
 ld a,c
 ld hl,title_roof_rows
 call add_hl_a
 ld a,(hl)
 ld (spr_new+9),a
 ld a,(spr_new+2)
 rrca
 and 3
 call title_paint
title_walk_shown:
 call title_wait
 ld a,(spr_new+2)
 sub 2
 ld (spr_new+2),a
 cp 184
 jp nc,title_walk
 call title_jump
 xor a
 ld (jn_skip),a
 ld a,23
 ld (jn_rows_count),a
title_climb:				; down the ladder in the game's ladder poses 8/9
 ld a,(spr_new+9)
 rrca
 rrca
 rrca
 and 1
 add a,8
title_rope_pose:
 call title_paint
title_climb_shown:
 ld hl,spr_new+9
 dec (hl)
 ld a,(hl)
 cp 38
 jp nc,title_climb
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
