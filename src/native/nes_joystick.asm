; P joystick (PPI2 B, 06h), plus direct A-compatible port 0Eh.
; Both are active-low: R,L,U,D,--,--,Fire1,Fire2. Merge once per VBlank
; into the existing keyboard snapshot: gameplay and GAME OVER share the path.
NES_JOYSTICK_P equ 1
joy_merge:
 in a,(6)
 ld c,a
 in a,(0x0E)
 and c
 cpl
 ld c,a
 or 0xF0                   ; lower nibble indexes F2F0..F2FF; ignore bits4/5
 ld l,a
 ld h,joy_directions/256
 ld a,(hl)
 ld hl,kbmat
 or (hl)
 ld (hl),a
 ld a,c
 and 0xC0
 ret z
 ld l,(kbmat+7)&255
 ld a,(hl)
 or 0x80
 ld (hl),a
 jp joy_menu_fire
 ASSERT kbmat/256 == (kbmat+7)/256
 ASSERT $ <= 0xF2F0
 ORG 0xF2F0
joy_directions:
 db 0,64,16,80,32,96,48,112,128,192,144,208,160,224,176,240
 ASSERT $ == spr_trim+256
