; Cold source installed after game_init clears game RAM, before the first IRQ.
; 7308..7328 is the complete old actor-clear span. The native main stack
; descends from 73C0; 7380..73BF remains reserved for it, never for this image.
nt_motion_return equ $
 ORG 0xE320
nt_motion_source:
 DISP 0x7329
nt_jump_curve:
 ; -NES $C5DF[1..16], indexed by the decremented ascent counter.
 db 0,0,0,0,0,0,0,-1,-1,-2,-2,-2,-2,-3,-3,-3
nt_jump_start:
 jp nt_jump_dispatch
nt_jump_finish:
 cp 15
 jp nz,nt_jump_test_end
 ld a,(0x7078)
 ld (0x7076),a              ; restore only after the rope key step
nt_jump_test_end:
 ld a,(0x7072)
 or a
 ret nz
 jp nt_jump_ended           ; mark the subsequent fall as a jump, not a walk-off
nt_jump_can_catch:
 ld a,(0x7079)
 cp 2
 scf
 ret nz
 ld a,(0x7072)
 cp 13                     ; original $A6B7: ignore rope grabs for first 3 rises
 ret
; Shared cold/warm menu scanner in the spare tail, outside the cleared actors.
cheat_menu_digits:
 ld a,(kbmat+2)
 and 14
 ret z
 ld b,255
cheat_menu_digit_next:
 inc b
 rrca
 jp nc,cheat_menu_digit_next
cheat_menu_normal:
 xor a
 jp cheat_menu_store
; HL already points into kbmat. Only joystick Fire selects level 1 in menus.
joy_menu_fire:
 ld l,(kbmat+2)&255
 ld a,(hl)
 and 14
 ret nz                    ; an explicit keyboard level takes priority
 ld a,(hl)
 or 2
 ld (hl),a
 ret
nt_motion_end:
 ASSERT $ <= 0x7380
 ENT
nt_motion_source_end:
 ASSERT $ <= 0xE400
 ORG nt_motion_return
