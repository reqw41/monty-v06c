; kbmat comes from the VBlank scan; digit decoding is in the installed image.
; CY = menu choice, B = level. F1+F3 starts level 1 with the trainer.
; Choosing an ordinary digit always starts a fresh game without cheats.
cheat_menu_keys:
 ld a,(kbmat+1)
 and 0x28                 ; Vector F1 = row 1 bit 3, F3 = bit 5
 cp 0x28
 jp nz,menu_scan
cheat_menu_on:
 ld b,1
 ld a,b
 jp cheat_menu_store
cheat_menu_store:
 ld (cheat_mode),a
 scf
 ret

