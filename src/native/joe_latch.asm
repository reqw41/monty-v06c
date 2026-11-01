; Latch a completed pure-Y translation immediately before painting. The cached
; picture and both cell bounds stay identical, so the prepared atomic groups
; and pending background cells remain valid. Never sample half-finished logic.
joe_latch_source:
 IFDEF STRICT
 DISP 0xF600
 ENDIF
joe_latch_y:
 ld a,(jn_wait)
 or a
 ret z
 ld a,(spr_rec+13)
 or a
 ret z
 ld a,(jn_epoch)
 ld hl,jn_ready_epoch
 cp (hl)
 ret z
 xor a
 call obj_ptr
 ld hl,spr_new+1
 ld a,(de)
 sub (hl)
 ld (jn_delta),a
 inc hl
 inc de
 ld b,3
 call jl_same
 ret nz
 ld a,1
 call obj_ptr
 ld hl,spr_new+17
 ld a,(de)
 sub (hl)
 ld hl,jn_delta
 cp (hl)
 ret nz
 ld hl,spr_new+18
 inc de
 ld b,3
 call jl_same
 ret nz
 ld a,(spr_new+9)
 ld hl,jn_delta
 sub (hl)
 ld e,a
 IFDEF NES_FULL
 ld a,SCREEN_TOP-FIELD_YSHIFT
 ELSE
 ld a,SCREEN_TOP
 ENDIF
 sub e
 ld c,a
 rrca
 rrca
 rrca
 and 31
 ld hl,spr_new+5
 cp (hl)
 ret nz
 ld a,(spr_new+11)
 add a,c
 dec a
 rrca
 rrca
 rrca
 and 31
 inc hl
 cp (hl)
 ret nz
 ld a,e
 ld (spr_new+9),a
 ld a,(jn_delta)
 ld hl,spr_new+1
 add a,(hl)
 ld (hl),a
 ld a,(jn_delta)
 ld hl,spr_new+17
 add a,(hl)
 ld (hl),a
 ld a,(jn_epoch)
 ld (jn_ready_epoch),a
 ret
jl_same:
 ld a,(de)
 cp (hl)
 ret nz
 inc de
 inc hl
 dec b
 jp nz,jl_same
 ret
; Bound completed logic steps, including paths that finish after a mid-step wait.
joe_gate:
 ld a,(video_dirty)
 and DIRTY_ROOM
 ret nz
 ld a,(0x7079)
 cp 8
 ret nc
 ld a,(spr_rec)
 ld hl,spr_new
 or (hl)
 ret z
 ld a,(spr_rec+13)
 or a
 jp nz,joe_gate
 call joe_motion_pending
 ret z
 ld a,(jn_epoch)
 ld hl,jn_last_epoch
 sub (hl)
 cp 2
 ret c

 xor a
 ld (jn_wait),a
 ; The published list includes enemies after Joe. Let the next IRQ finish it;
 ; cancelling its tail here would starve them during continuous hero motion.
 ld a,(crit_pend)
 or a
 jp nz,joe_gate
 call disp_prep
 ld a,1
 ld (jn_wait),a
 jp joe_gate
 IFDEF STRICT
 ENT
 ENDIF
joe_latch_end:
 ASSERT joe_latch_end-joe_latch_source <= 256
 ASSERT $ <= 0x7000
