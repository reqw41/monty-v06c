; NES sprite_source is empty above name 30h. Keep the lower 32 trim records
; (00h..7Ch); the unused upper half is permanent code, outside every allocator.
cheat_low_return equ $
 ORG spr_trim+128
NES_CHEAT_PACKED equ 1
cheat_code_begin:
 INCLUDE "nes_cheat_keys.asm"
; Poll at a completed main-step boundary, never in the IRQ or the renderer.
; Outside trainer mode this costs only the flag test. L is edge-triggered.
cheat_step:
 ld a,(cheat_mode)
 or a
 ret z
 ld a,(kbmat+5)
 and 0x10                 ; Latin L / Vector Л
 ld hl,cheat_l_down
 cp (hl)
 ld (hl),a
 ret z
 ret c                    ; changed 16 -> 0 is a release, 0 -> 16 a press
 ld a,(0x705F)
 and 0xD7                 ; leave bonus and any pending room build
 ld (0x705F),a
 ld a,(0x71A6)
 cp 9
 jp c,nes_level_number
 xor a                    ; 9 -> 1, via the ordinary level-advance path
 jp nes_level_number

; Permanent even before boot relocation, for ordinary collision entry points.
cheat_lose_life:
 ld a,(cheat_mode)
 or a
 ret nz
 dec (hl)
 ret

; The test-only wait adapter also needs no low-memory cache space.
unit_fw:
 push af
 push bc
 push de
 push hl
 call frame_handler
 pop hl
 pop de
 pop bc
 pop af
 ret
 INCLUDE "nes_joystick.asm"
cheat_code_end:
 ASSERT cheat_code_end <= spr_trim+256
 ORG cheat_low_return
