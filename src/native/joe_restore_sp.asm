; Two rows consume four background bytes: C/A, C/A.
; IRQ owns the stack throughout, just as in joe_put. Preserve caller BC.
 ASSERT JOE_BACKGROUND_STRIDE == 2
 push bc
 call joe_burst_clean       ; снять 8000 под ушедшим облаком смерти (nes_column.asm); BC — свободен
 ld hl,0
 add hl,sp
 ld (jn_stack),hl
 ld sp,JOE_BACKGROUND
 ld a,(spr_rec+11)
 ld b,a
 ld a,(spr_rec+9)
 sub b
 ld (jr_sp_end+1),a
 ld hl,jr_sp_pair
 ld a,b
 and 1
 jp z,jr_sp_even
 ld hl,jr_sp_single
jr_sp_even:
 ld (jr_sp_start+1),hl
 ld hl,spr_rec+7
 ld a,(spr_rec+8)
 sub (hl)
 inc a
 ld (jn_columns),a
 ld a,(spr_rec+10)
 add a,0xC0
 ld h,a
jr_sp_column:
 ld a,h
 ld (jr_sp_c+1),a
 ld (jr_sp_single_c+1),a
 sub 0x20
 ld (jr_sp_a+1),a
 ld (jr_sp_single_a+1),a
 ld a,(spr_rec+9)
 ld l,a
jr_sp_start:
 jp jr_sp_pair
jr_sp_single:
 pop bc
 ld (hl),c
jr_sp_single_a:
 ld h,0xA0
 ld (hl),b
jr_sp_single_c:
 ld h,0xC0
 dec l
 jp jr_sp_count
jr_sp_pair:
 pop bc
 ld (hl),c
jr_sp_a:
 ld h,0xA0
 ld (hl),b
 dec l
 pop bc
 ld (hl),b
jr_sp_c:
 ld h,0xC0
 ld (hl),c
 dec l
jr_sp_count:
 ld a,l
jr_sp_end:
 cp 0
 jp nz,jr_sp_pair
 inc h
 ld a,(jn_columns)
 dec a
 ld (jn_columns),a
 jp nz,jr_sp_column
 ld hl,(jn_stack)
 ld sp,hl
 pop bc
 ret
