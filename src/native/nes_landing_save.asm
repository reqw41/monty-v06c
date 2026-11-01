; First landing still has a pending Y correction in C. Preserve game flow,
; but store the aligned checkpoint and a standing state for the next life.
 ORG 0xFB90
nes_landing_save:
 call L_8E7E
 ld a,c
 jp nes_landing_y
 ASSERT $ <= 0xFB97
 ORG nes_player_end
nes_landing_idle:
 xor a
 ld (0x707D),a              ; saved vertical motion
 ld (0x707F),a              ; saved standing state, not the initial free-fall
 ret
nes_landing_idle_end:
 ASSERT $ <= 0xF8D0
