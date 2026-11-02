; MSX E8: static cyan chain body (6), animated light row 2 (1).
; Only C000 changes during phase updates; bank changes rebuild the whole tile.
; Install after the title music stops, as before; F8C0 later becomes display SP.
 ORG nes_player_end
nes_platform_source:
 DISP nes_effect_end
NES_INK_SWAP23 equ 1
NES_SHARED_WHITE equ 1
NES_WHITE_CHAINS equ 1
NES_MONO_SNAKE equ 1
style_pal: db 0,0,255,255,4,4,102,102,32,32,173,173,160,160,102,102   ; слот 3 — кожа Джо 66h (было 67h, ярче); слот 5 — серый ADh; слот 7 по умолчанию = кожа (в сокровищнице: кожа поверх золота)
MSX_PLATFORM_ROWS equ 4
MSX_PLATFORM_INK equ 1
MSX_PLATFORM_BODY_INK equ 6
nes_platform_select:
 ld hl,nes_platform_line
 ld (fl_write+1),hl
 ret
nes_platform_line:
 inc de
 inc de
 dec l
 dec l
 ld a,(de)
 ld (hl),a
 jp flt5
nes_platform_image:
 ld hl,(tile_dst)
 inc hl
 inc hl
 ld a,(hl)
 ld (hl),0               ; remove the cyan 8000 bit from the moving row
 ld de,8
 add hl,de
 ld (hl),0
 add hl,de
 ld (hl),a               ; only C000: light middle, cyan static body
 ret
copy_de_hl_swap:
 ex de,hl
 jp copy_de_hl
nes_platform_end:
 ASSERT $ <= tile_changed
 ENT
nes_platform_source_end:
 ASSERT nes_platform_source_end <= 0xF900
