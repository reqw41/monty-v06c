; NES 00 is a wall; 01 is a floor surface which permits a sideways jump.
; Preserve the old semantic vocabulary for climbing and hazards. Only the
; hero's wall/floor decisions inspect the original decorative tile here.
; NES $9F7A gives two walking updates over the edge before gravity starts.
nphys_ground_floor:
 ld hl,0x7072
 call L_911E
 jp nc,npg_floor
 inc (hl)
 ld a,(hl)
 cp 3
 ccf
 ret
npg_floor:
 ld (hl),0
 ret
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
; The ascent counter is otherwise zero throughout a fall. Its high bit marks
; preserved jump momentum; standing already clears it at h929_floor.

nt_jump_ended:
 ld a,0x81                  ; бит 7 — инерция прыжка, бит 0 — первый шаг падения
 ld (0x7072),a
 ld a,6
 ld (0x7079),a
 ret

nes_terrain_end:
