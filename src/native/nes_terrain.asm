; NES 00 is a wall; 01 is a floor surface which permits a sideways jump.
; Preserve the old semantic vocabulary for climbing and hazards. Only the
; hero's wall/floor decisions inspect the original decorative tile here.
; NES $9F7A gives two walking updates over the edge before gravity starts.
; nphys_ground_floor — в nes_column.asm (хвост dlist), место здесь — под рост кадров Джо.
nes_floor_at:
 ; Original NES left/right foot points; raw cap 0C is a floor, rope 0D is not.
 push bc
 push hl
 ld hl,0x7305
 ld a,(nphys_box_left)
 add a,(hl)
 add a,2
 ld b,a
 ld a,(0x7304)
 add a,18
 ld c,a
 call nphys_read
 call nphys_floor_class
 jp nc,nfp_return
 ld a,(nphys_box_right)
 add a,(hl)
 sub 3
 ld b,a
 call nphys_read
 call nphys_floor_class
 jp nc,nfp_return
 ld a,(hl)
 add a,8
 ld b,a
 call nphys_read
 call nphys_floor_class
nfp_return:
 pop hl
 pop bc
 ret
nes_terrain_end:
