; In the code chain (FE00..FE2F is sprite slot 5's background buffer).
 IFDEF NES_STABLE_COLORS
nes_conveyor_mode equ fsm_white
 ELSE
nes_conveyor_mode equ fsm_accent
 ENDIF
; A/B = tile. Darkness has already been handled in full_style_modes.
nes_color_modes:
 cp 0xD6
 IFDEF NES_STABLE_COLORS
 jp nc,nes_object_upper_ink
 ELSE
 jp nc,fsm_default
 ENDIF
 cp 0xD2
 ld c,4                   ; foreground index 2: Joe's red clothing
 ret nc
 cp 0x9C                  ; red-door foot shares the jewel colour group
 ret z
 ; 00..03 are empty. Coloured conveyors animate only the white hook plane.
 cp 7
 jp c,nes_conveyor_mode
 sub 0xB8
 cp 3
 jp c,nes_conveyor_mode
 ld a,b                   ; restore the tile for ordinary colour selection
nes_color_modes_end:                 ; falls through into fsm_default (style.asm)
