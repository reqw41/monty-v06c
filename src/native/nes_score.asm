; Choose the final colour before any score byte reaches VRAM. Shared glyphs
; use the floor accent above and fixed red below, including the level number.
NES_SCORE_TWO_TONE equ 1
NES_LEVEL_TWO_TONE equ 1
 ASSERT nes_chain_low_end <= 0xFE4E
 ORG 0xFE4E
score_blit_select:
 ld a,l
 xor SCREEN_TOP-HUD_YSHIFT-3*8
 ret nz                    ; XOR clears carry outside the lower HUD row
 ld a,h
 and 0x9F                 ; either 8000 or C000: red now uses A000 only
 sub 0x80+14
 cp 2                     ; the two lower level-number cells
 ret c
 sub 4                    ; skip the black gap and the HUD frame at 16/17
 cp 12                     ; carry: one of the six score digits
 ret
 ASSERT $ <= 0xFE60
 ASSERT nes_chain_descent_end <= 0xF5F0
 ORG nes_chain_descent_end
score_blit_zero:
 push bc
 ld b,8
 xor a
score_blit_zero_row:
 ld (hl),a
 inc de
 dec l
 dec b
 jp nz,score_blit_zero_row
 pop bc
 ld a,h
 add a,a
 jp m,da_blit_last_advance
 jp da_blit_first_advance
; ms_keys (nes_mute.asm): A = только что нажатые УС (40h, порт 01, как в Bruce Lee) и ВК (04h, ряд 0), Z — нет.
ms_keys:
 in a,(0x01)                ; УС — бит 6 порта C (0 = нажата); верх порта C всегда на вводе (8Ah/88h)
 cpl
 and 0x40
 ld b,a
 ld a,(kbmat)
 and 4
 or b
 jp ms_edge
 ASSERT $ <= 0xF600
