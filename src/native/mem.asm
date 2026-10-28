; Память только нативной сборки. ОЗУ игры и видимые плоскости неизменны.
VSPR equ 0x7400
 IFDEF NES_FULL
VNT equ 0x7B40
NT_CELLS equ 960
SCREEN_ROWS equ 30
SCREEN_HEIGHT equ 240
SCREEN_TOP equ 0xFF
HUD_ROWS equ 6
FIELD_VNT equ 0x7C00
 ELSE
VNT equ 0x7C00
NT_CELLS equ 768
SCREEN_ROWS equ 24
SCREEN_HEIGHT equ 192
SCREEN_TOP equ 0xDF
HUD_ROWS equ 5
FIELD_VNT equ VNT+160
 ENDIF
room_colors equ 0x7F80
NT equ VNT
TILE_IMAGES equ 0xE000
 IFDEF STRICT
TILE_CAP equ 120
 ELSE
TILE_CAP equ 87
 ENDIF
 IFDEF NES_FULL
NTS equ 0xEB40
 ELSE
NTS equ 0xEC00
 ENDIF
tile_changed equ 0xF000
spr_trim equ 0xF200
live_list equ 0xFF00
ISR_STACK equ 0x7F80
DISP_STACK equ 0xF900
SPR_SLOTS equ 0xF900
; The 23-row Joe image can cross F9FF. Background remains inside page FA.
JOE_PICTURE equ SPR_SLOTS
JOE_BACKGROUND equ 0xFA20

joe_attr_runtime equ 0xF500
