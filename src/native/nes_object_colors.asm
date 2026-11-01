; Permanent images reuse only the unused three-plane restore destinations.
 ASSERT JOE_BACKGROUND_STRIDE == 2
 INCLUDE "gen/object_colors.asm"
 ORG JOE_BACKGROUND+6*joe_nes_rows
; A compact mask reference: ordinary full_raw index, or C0..CB / D0..DB.
object_mask_address:
 cp 0xC0
 jp nc,oma_extra
 ld l,a
 ld h,0
 add hl,hl
 add hl,hl
 add hl,hl
 ld bc,full_raw
 add hl,bc
 ret
oma_extra:
 ld l,a
 rrca
 rrca
 rrca
 rrca
 and 1
 add a,a
 add a,0xFB
 ld h,a
 ld a,l
 and 15
 rlca
 rlca
 rlca
 add a,0x30
 ld l,a
 ret
object_image_select:
 ld a,(rr_t)
 cp 0x62
 ccf
 ret nc
 cp 0xD2
 ret nc
 cp 0xAE
 ld b,0xF4
 jp z,ois_phase
 cp 0xA8
 jp nz,object_image_find
 ld b,0xF0
ois_phase:
 ld a,(tile_phase)
 add a,b
 jp object_image_find
 ASSERT $ <= JOE_BACKGROUND+9*joe_nes_rows
 ORG 0xFCA1
; HL -> three mask references. Cache keeps its ordinary 24-byte format.
object_image_copy:
 push hl
 ld hl,(tile_dst)
 ex de,hl
 pop hl
 ld b,3
oic_plane:
 push bc
 ld a,(hl)
 inc hl
 push hl
 call object_mask_address
 ex de,hl
 ld bc,8
 call copy_de_hl
 ex de,hl
 pop hl
 pop bc
 dec b
 jp nz,oic_plane
 scf
 ret
object_image_copy_end:
 ASSERT $ <= 0xFCC1

; The former one-sided chain exit gap, outside the shifted-sprite pool.
 ORG 0x7B10
object_image_find:
 ld c,a
 ld hl,object_color_records
ois_next:
 ld a,(hl)
 cp 255
 ret z
 cp c
 inc hl
 jp z,object_image_copy
 inc hl
 inc hl
 inc hl
 jp ois_next

nes_object_upper_ink:
 cp 0xD8
 jp c,fsm_default
 cp 0xDA
 jp nc,fsm_default
 ld a,(full_modes+19)
 ld c,a
 ret
nes_object_upper_ink_end:
 ASSERT $ <= VNT-12
