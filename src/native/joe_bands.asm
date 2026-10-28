; Eight background rows per call, 8000/A/C per byte.
 ORG video_raw_end
joe_source0:
joe_runtime0 equ 0xFB30
 DISP joe_runtime0
jn_restore_row:
 REPT 4
 ld a,(de)
 ld (hl),a
 dec e
 ld a,h
 add a,0x20
 ld h,a
 ld a,(de)
 ld (hl),a
 dec e
 ld a,h
 add a,0x20
 ld h,a
 ld a,(de)
 ld (hl),a
 ld a,e
 add a,5
 ld e,a
 ld a,h
 sub 0x40
 ld h,a
 dec l
 ENDR
jn_restore_first_end:
 jp jn_restore_last
 ENT
joe_end0:
 ASSERT joe_end0-joe_source0 <= 160
joe_source2:
joe_runtime2 equ 0xFD30
 DISP joe_runtime2
jn_restore_last:
 REPT 4
 ld a,(de)
 ld (hl),a
 dec e
 ld a,h
 add a,0x20
 ld h,a
 ld a,(de)
 ld (hl),a
 dec e
 ld a,h
 add a,0x20
 ld h,a
 ld a,(de)
 ld (hl),a
 ld a,e
 add a,5
 ld e,a
 ld a,h
 sub 0x40
 ld h,a
 dec l
 ENDR
jn_restore_end:
 ret
 ENT
joe_end2:
 ASSERT joe_end2-joe_source2 <= 160
joe_source1:
joe_runtime1 equ 0xFC30
 DISP joe_runtime1
jn_restore_two:
 REPT 8
 ld a,(de)
 ld (hl),a
 dec e
 ld a,h
 add a,0x20
 ld h,a
 ld a,(de)
 ld (hl),a
 ld a,e
 add a,4
 ld e,a
 ld a,h
 sub 0x20
 ld h,a
 dec l
 ENDR
jn_restore_two_end:
 ret
 ENT
joe_end1:
 ASSERT joe_end1-joe_source1 <= 160
 ASSERT jn_restore_two_end-jn_restore_two == 8*18
 ASSERT jn_restore_end-jn_restore_last == 4*25
