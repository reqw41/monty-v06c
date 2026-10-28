joe_attr_source:
 DISP 0xF500
; The two MSX layers supply attributes only; a single native rectangle is built
; below. Avoid the legacy visibility/rectangle walk for both invisible layers.
joe_attrs:
 xor a
 ld (spr_rec+13),a
 ld (spr_rec+15),a
 ld (spr_rec+29),a
 ld (spr_rec+31),a
 ld a,(spr_force)
 or a
 jp nz,ja_fetch
 ld a,(0x7079)
 cp 1
 jp nz,ja_fetch
 ld a,(spr_rec)
 or a
 jp z,ja_fetch
 ld a,(jn_epoch)
 ld hl,jn_last_epoch
 sub (hl)
 cp 2
 jp nc,ja_fetch
 ld a,1
 ld (jn_hold),a
 ret
ja_fetch:
 ld hl,spr_rec+1
 xor a
 call obj_ptr
 call ja_one
 ld hl,spr_rec+17
 ld a,1
 call obj_ptr
ja_one:
 ld a,(obj_end)
 or a
 jp nz,ja_end
 ld a,(de)
 cp 0xD0
 jp nz,ja_compare
 ld a,1
 ld (obj_end),a
ja_end:
 ld de,spl_z
ja_compare:
 push hl
 push de
 ld a,(de)
 cp (hl)
 jp nz,ja_changed_y
 ld a,(spr_force)
 or a
 jp nz,ja_changed
 REPT 3
 inc de
 inc hl
 ld a,(de)
 cp (hl)
 jp nz,ja_changed
 ENDR
 pop de
 pop hl
 ret
ja_changed_y:
ja_changed:
 pop de
 pop hl
 ld a,1
 ld (spr_rec+13),a
 ld (spr_rec+15),a
 ld a,l
 or 0x80
 ld l,a
 ld b,4
 jp memcpyb


 ; Cache enemy Y pairs independently of the moving hero. Only the hero union
 ; needs rebuilding each plan; enemy X unions are read directly from descriptors.
band_joe_check:
 xor a
 call ub_one
 xor a
 call ub_ld
 ld b,2
bj_next:
 ld a,b
 add a,a
 add a,a
 add a,ubr&255
 ld l,a
 ld h,ubr/256
 ld a,e
 cp (hl)
 jp c,bj_separate
 inc l
 ld a,(hl)
 cp d
 jp c,bj_separate
 push de
 ld a,b
 call band_xrange
 ld a,e
 cp c
 jp c,bj_pop_separate
 ld a,(ub_c1)
 cp d
 jp c,bj_pop_separate
 pop de
 xor a
 ret
bj_pop_separate:
 pop de
bj_separate:
 inc b
 ld a,b
 cp SPR_MAX
 jp nz,bj_next
 ld a,1
 or a
 ret

; A source position held by the visual rate limiter does not change any union.
band_invalidate_y:
 ld a,l
 and 0xF0
 or 1
 ld l,a
 ld a,(de)
 cp (hl)
 ret z
 xor a
 ld (band_valid),a
 ret
 IFDEF NES_JOE_PALETTE
joe_palette:
 ld hl,0x1F1F ; orange, RGB 255/109/0
 ld (pal+2),hl
 ld hl,0x0303 ; dark red, RGB 109/0/0
 ld (pal+6),hl
 IFDEF NES_JOE_3COLOR
 ld hl,0x9F9F ; pink, RGB 255/109/170
 ld (pal+4),hl
 ENDIF
 ret
 ENDIF
 ENT
joe_attr_end:
 ASSERT joe_attr_end-joe_attr_source <= 256
