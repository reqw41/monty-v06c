; Cache-time colour separation only. Live phases change C000; A000 is fixed.
; In discarded legacy restore source; joe_band_free_source protects these bytes.
CONVEYOR_TWO_INKS equ 1
nes_terrain_image:
 ld a,(rr_t)
 cp 0xE8
 jp z,nes_platform_image
 ld a,c                    ; dc_tile/da_img preserve the lighting mode
 or a
 ret z
 ld a,(rr_t)
 sub 4
 cp 3
 jp c,nci_tile
 sub 0xB4
 cp 3
 ret nc
nci_tile:
 add a,a
 add a,a
 add a,a
 ld hl,nes_conveyor_body
 call add_hl_a
 ex de,hl
 ld hl,(tile_dst)
 ld bc,16
 add hl,bc
 ld b,8
nci_row:
 ld a,(de)
 ld c,(hl)                 ; the ordinary white silhouette
 ld a,c                    ; C000 holds white hooks plus the skin body bit
 ld (hl),a                 ; white hooks in C000, no 8000 colour mixing
 ld a,(de)
 push hl
 push bc
 ld bc,-8
 add hl,bc
 ld (hl),a                 ; stationary belt body in A000
 pop bc
 pop hl
 inc de
 inc hl
 dec b
 jp nz,nci_row
 ret
nes_conveyor_body:
 ; CHR colour 1 is identical in all four original NES conveyor poses.
 db 0,0,15,63,63,15,0,0
 db 0,0,255,255,255,255,0,0
 db 0,0,240,252,252,240,0,0
nes_conveyor_end:
 ASSERT $ <= joe_latch_source
