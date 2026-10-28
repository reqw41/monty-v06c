; Память только нативной сборки. ОЗУ игры и видимые плоскости неизменны.
VSPR equ 0x7400
VNT equ 0x7C00
room_colors equ 0x7F80
NT equ VNT
TILE_IMAGES equ 0xE000
TILE_CAP equ 120
NTS equ 0xEC00
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
