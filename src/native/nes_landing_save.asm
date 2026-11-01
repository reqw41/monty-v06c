; First landing still has a pending Y correction in C. Preserve game flow,
; but store the aligned checkpoint and a standing state for the next life.
 ORG 0xFB90
nes_landing_save:
 call L_8E7E
 ld a,c
 jp nes_landing_y
 ASSERT $ <= 0xFB97
