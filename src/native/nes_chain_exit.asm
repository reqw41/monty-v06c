; NES chain caps: enter and leave a platform on either side.
; The MSX state machine otherwise interprets Up at these caps as a fall.
; Permanent high RAM, excluded from the VI53 stream allocator.
 ORG 0xFE30
nphys_box_install:
 ld hl,nphys_box_pose
 cp (hl)
 ret z
 ld (hl),a
 ld b,a
 ld c,a
 add a,a
 add a,(hl)
 ld hl,nphys_box_data
 call add_hl_a
 ld d,0
 ld a,(0x7078)
 rla
 jp nc,npb_copy
 jp npb_flip
nes_chain_low_end:
 ASSERT $ <= 0xFE4E
 ORG 0xFE60
npb_flip:
 ld a,c
 cp 3
 jp z,npb_copy
 cp 5
 jp nc,npb_copy
 ld d,2
npb_copy:
 ld a,(hl)
 add a,d
 ld (nphys_box_left),a
 inc hl
 ld a,(hl)
 ld (nphys_box_top),a
 inc hl
 ld a,(hl)
 add a,d
 ld (nphys_box_right),a
 ret
 ASSERT $ <= 0xFE80
 ORG joe_high_free_end
; These helpers are excluded from every sprite-mask allocation range.
nes_chain_catch:
 jp nt_jump_can_catch      ; NES permits vertical catches in ordinary rooms too
nphys_floor_class:
 cp 0x90
 ret z
 cp 0xD2
 scf
 ret z
 call nf_semantic
 jp L_9122
nphys_hazard_class:
 cp 0xD2
 ret z
 cp 0x38
 ret z
 cp 0xE0
 ret nz
 ld a,(0x7000)
 and 0x20
 ret
nes_chain_catch_end:
 ASSERT nes_chain_catch_end <= VNT-0x44
 ORG 0xFE80
; NES $AB96/$ABD8 checks one point before a walking step, without a jump snap.
nphys_walk_wall:
 ld a,(0x73EE)
 and 10
 jp z,npw_done               ; a conveyor applies before walking wall checks
 ld hl,0x7305
 ld a,e
 and 128
 jp nz,npww_left
 ld a,(hl)
 cp 238
 jp nc,npw_done              ; permit returning through an obstructed entry
 ld a,(nphys_box_right)
 add a,(hl)
 inc a
 ld b,a
 jp npww_probe
npww_left:
 ld a,(hl)
 cp 3
 jp c,npw_done
 ld a,(nphys_box_left)
 add a,(hl)
 dec a
 ld b,a
npww_probe:
 ld a,(0x7304)
 add a,14
 ld c,a
 call nphys_read
 call nphys_solid
 jp nz,npw_done
 ld e,0
 jp npw_done
nes_chain_exit_end:
 ASSERT nes_chain_exit_end <= 0xFEC0
