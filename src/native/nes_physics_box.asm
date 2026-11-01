; Reuse the retired MSX VDP descriptor bytes; native video never reads these.
nphys_box_pose equ 0x73F2
nphys_box_left equ 0x73F3
nphys_box_top equ 0x73F4
nphys_box_right equ 0x73F5
nphys_box_defer equ 0x73F6
nphys_previous_keys equ 0x73F7
nphys_up_phase equ 0x73F8
nphys_box_reset:
 ld a,255
 ld (nphys_box_pose),a
 xor a
 ld (nphys_box_defer),a
 ld (nphys_previous_keys),a
 ld (nphys_up_phase),a
 call nphys_box_install
 jp nphys_box_state
nphys_box_step:
 push bc
 push de
 push hl
 call npb_step
 pop hl
 pop de
 pop bc
 ret
npb_step:
 ld a,(0x73EE)
 and 10
 ld (nphys_previous_keys),a
 ld a,(nphys_box_defer)
 or a
 jp z,nphys_box_state
 xor a
 ld (nphys_box_defer),a
 ret
nphys_box_state:
 ld a,(0x7079)
 cp 6
 ret z                      ; a fall retains the current NES metasprite bounds
 cp 8
 ret nc
 cp 2
 ccf
 adc a,0
 cp 4
 jp nz,nphys_box_install
 ld a,(0x7305)
 add a,3
 ld b,a
 ld a,(0x7304)
 add a,16
 ld c,a
 call nphys_read
 cp 0x10
 ld a,4
 jp nz,npb_ladder
 ld a,7                     ; NES ladder-top pose has the full 16-pixel width
npb_ladder:
 jp nphys_box_install
