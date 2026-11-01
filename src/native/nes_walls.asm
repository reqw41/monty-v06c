; Original NES $A122: the lower side probe snaps to the eight-pixel grid;
; horizontal jump momentum stops only when both head and foot meet a wall.
; B/C are the requested step, E is its horizontal component.
 push bc
 ld a,(0x7079)
 cp 2
 jp c,nphys_walk_wall
 ld a,(0x7078)
 and 128
 ld a,(nphys_box_right)
 jp nz,npw_left
 dec a
 jp npw_side
npw_left:
 ld a,(nphys_box_left)
npw_side:
 ld b,a
 ld a,(0x7305)
 add a,b
 ld b,a
 ld a,(0x7304)
 add a,16
 ld c,a
 call nphys_read
 call nphys_wall
 jp nz,npw_done
 ld a,(0x7079)
 sub 3
 cp 3
 jp nc,npw_lower
 ld a,(0x7078)
 and 128
 jp nz,npw_mid
 dec b
 dec b
npw_mid:
 ld a,c
 sub 6
 ld c,a
 call nphys_read
 cp 8                      ; NES $A017: a climb snaps only at a torso wall
 jp nz,npw_done
npw_lower:
 ld a,(nphys_box_top)
 ld c,a
 ld a,(0x7304)
 add a,c
 sub 7
 ld c,a
npw_head:
 ld a,e
 and 128
 jp nz,npw_head_read
 inc b
npw_head_read:
 call nphys_read
 call nphys_wall
 jp nz,npw_snap
 ld a,(0x7079)
 cp 2
 jp z,npw_cancel
 cp 6
 jp nz,npw_snap
npw_cancel:
 ld e,0
npw_snap:
 ld a,(0x7078)
 and 128
 ld b,2
 jp z,npw_snap_pos
 ld b,6
npw_snap_pos:
 ld a,(0x7305)
 and 248
 or b
 ld (0x7305),a
 ld (0x7301),a
npw_done:
 pop bc
 ld a,e                    ; фактический dX: упёрся в стену — запрос гасится (ни топота, ни щелчков шагов)
 ld (0x7076),a
 ld b,e
 call L_8DD4
 push af
 call nphys_hazards
 call nphys_box_step
 pop af
 ret
nphys_wall:
 cp 8
 ret z
 cp 0x38
 ret z
 cp 0x40
 ret c                      ; NES 01 is a thin floor, never an airborne wall
 jp L_A894
