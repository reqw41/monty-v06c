; Permanent gap after GAME OVER glyphs, before the permanent climb helpers at FE30.
 ORG 0xFE06
; Grounded walking phases 0/2 plant a foot. A wall cancels dX.
joe_footstep:
 rrca
 ret c
 ld a,(0x7076)
 or a
 ret z
 jp nes_step_sfx          ; шумовой щелчок (раньше — едва слышный BSR PC0)
 ASSERT $ <= 0xFE30
