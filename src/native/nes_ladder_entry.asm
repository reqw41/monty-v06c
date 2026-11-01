ld_lad:
 ld c,18
 ld a,(nphys_box_right)
 sub 3
 ld b,a
 ld d,0x11
 ld a,(0x7078)
 and 128
 jp z,npl_probe
 ld a,(nphys_box_left)
 add a,2
 ld b,a
 dec d
 jp npl_probe
ld_up:
 ld c,16
 ld a,(nphys_box_right)
 dec a
 ld b,a
 ld d,0x89
 ld a,(0x7078)
 and 128
 jp z,npl_probe
 ld a,(nphys_box_left)
 ld b,a
 dec d
npl_probe:
 ld a,(0x7305)
 add a,b
 ld b,a
 ld a,(0x7304)
 add a,c
 ld c,a
 call nphys_read
 cp d
 ld bc,0
 ret
nphys_ladder_snap:
 ld a,(0x73EE)
 and 1
 add a,a
 add a,3
 ld b,a
 ld a,(0x7078)
 and 128
 jp z,npl_snap
 ld a,7
 sub b
 ld b,a
npl_snap:
 ld a,(0x7305)
 add a,b
 and 248
 ld (0x7301),a
 ld (0x7305),a
 ld bc,0
 scf
 ret
