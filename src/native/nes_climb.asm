NES_PHYSICS_COORDS equ 1
; NES $A8B7/$A96E: rope up every other step, rope/ladder down every step.
; Collision coordinates are the original top anchor + offsets (layer 2 = top+7).
hs_8CC5 equ hs_8A83
hs_8C59:
 ld a,(0x7305)
 add a,3
 ld b,a
 ld a,(0x7304)
 add a,18
 ld c,a
 call nphys_read
 cp 0x10
 jp z,ncl_ladder_body
 cp 0x11
 jp z,ncl_ladder_body
 call nphys_floor_class
 jp nc,ncl_ladder_exit
ncl_ladder_body:
 ld bc,0
 ld a,(0x73EE)
 and 5
 jp z,hs_8C39
 ld c,0
 rra
 jp nc,ncl_ladder_down
 dec c
ncl_ladder_down:
 ld a,(0x73EE)
 and 4
 jp z,ncl_ladder_move
 inc c
ncl_ladder_move:
 push bc
 ld a,(0x7305)
 add a,3
 ld b,a
 ld a,(0x7304)
 add a,16
 add a,c
 ld c,a
 call nphys_read
 pop bc
 or a
 jp nz,hs_8C39
 call L_8DD4
 ld a,1
 ld (nphys_box_defer),a
 jp ncl_ladder_exit
ncl_ladder_exit:
 call nphys_align_y
ncl_zero:
 xor a
ncl_bc0:                    ; общий хвост: hs_8B0E, ncl_rope_detach
 ld bc,0
 jp hs_8992
hs_8D02:
 call nphys_rope_fire
 jp nc,ncl_rope_keys
 ld a,(0x73EE)
 and 8
 ld bc,0xFE00
 jp nz,hs_8D14
 ld a,(0x73EE)
 and 2
 ld bc,0x0200
 jp nz,hs_8D14
ncl_rope_keys:
 ld a,(0x73EE)
 and 5
 jp z,hs_8C36
 ld c,0
 and 1
 jp z,ncl_rope_down
 ld a,(0x705F)
 and 0x20
 jp z,ncl_rope_up_phase
 push bc
 ld a,(0x7305)
 add a,8
 ld b,a
 ld a,(0x7304)
 add a,9
 ld c,a
 call nphys_read
 or a
 pop bc
 jp z,ncl_rope_down
ncl_rope_up_phase:
 call nphys_up_tick
 jp c,ncl_rope_down
 dec c
ncl_rope_down:
 ld a,(0x73EE)
 and 4
 jp z,ncl_rope_move
 inc c
ncl_rope_move:
 ld b,0
 push bc
 ld a,(0x7304)
 add a,17
 add a,c
 ld c,a
 ld a,(0x7305)
 add a,8
 ld b,a
 call nphys_read
 ld b,a
 ld a,(0x705F)
 and 0x20
 ld a,b
 pop bc
 jp z,ncl_rope_ordinary
 or a
 jp z,hs_8C36               ; bonus ropes hold at both ends
 jp hs_8C39
ncl_rope_ordinary:
 or a
 jp nz,hs_8C39
 ld a,1
 ld (nphys_box_defer),a
 call L_8DD4
 ld a,(0x73EE)
 and 4
 ld a,3
 jp nz,ncl_rope_detach
 call nphys_align_y
 xor a
ncl_rope_detach:
 ld (0x7072),a
 jp ncl_zero
hs_8D14:
 ld a,(0x705F)
 and 0x20
 jp z,hs_89DC
 ld a,(0x70AC)
 cp 1
 jp nz,hs_89DC
 ld a,(0x705F)
 or 8
 ld (0x705F),a
 ld a,b
 and 0x80
 ld b,4
 jp z,hs_89DC
 ld b,252
 jp hs_89DC
nphys_rope_probe:
 push bc
 ld a,(0x7305)
 add a,8
 ld b,a
 ld a,(0x7304)
 add a,17
 ld c,a
 call nphys_read
 call nf_semantic
 cp 0x90
 jp z,npr_cap_done
 ld h,a
 inc c                     ; original $9D89 also accepts a cap at top+25
 call nphys_read
 cp 0x90
 jp z,npr_cap_done
 ld a,h
npr_cap_done:
 pop bc
 ret
; B/C = pixel X/Y. Native field data; no VDP operation or actor scratch.
nphys_read:
 push hl
 push bc
 ld a,b
 rrca
 rrca
 rrca
 and 31
 ld b,a
 ld a,c
 rrca
 rrca
 rrca
 and 31
 cp 6
 jp nc,npr_field
 ld a,6
npr_field:
 ld c,b
 call nf_row_addr
 ld a,(hl)
 pop bc
 pop hl
 ret

