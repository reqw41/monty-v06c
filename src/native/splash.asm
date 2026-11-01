; Cold-only 16-colour splash. The complete game is restored byte-for-byte
; after Space; no splash code or pixels consume game-time cache memory.
 DEVICE NOSLOT64K
 INCLUDE "splash_config.asm"
 ORG 0
 di
 ld sp,0x7FFE
 jp splash_entry
 ORG 0x38
 ret                       ; wake HALT; the main loop scans inside vertical blank
 ORG 0x40
splash_entry:
 ld a,0x88
 out (0),a
 xor a
 out (1),a
 out (2),a
 ld a,255
 out (3),a
 ld a,0x83
 out (4),a
 ld a,0x9F
 out (5),a
 ; Vector latches OUT 0Ch into the colour under the beam. Sync to the
 ; frame interrupt so the border index from OUT 2 is still current.
 ei
 halt
 di
 ld hl,splash_palette
 call splash_pal
 ld a,0x8A
 out (0),a
splash_wait:
 ei
 halt
 di
 ; Re-arm every frame: 8080/Z80 wait-state differences move the beam
 ; enough that a one-shot boot write can land in the wrong slots on Emu80
 ; while vector06js still looks fine.
 ld hl,splash_palette
 call splash_pal
 ld a,0x7F
 out (3),a
 in a,(2)
 ld b,a
 ld a,255
 out (3),a
 ld a,b
 and 0x80
 jp z,splash_start
 in a,(6)
 ld b,a
 in a,(0x0E)
 and b
 and 0xC0
 cp 0xC0
 jp z,splash_wait
splash_start:
 ld a,0x88
 out (0),a
 ei
 halt
 di
 ld hl,splash_black
 call splash_pal
 ld de,splash_resume_source
 ld hl,splash_resume
 ld bc,splash_resume_source_end-splash_resume_source
 call splash_copy
 jp splash_resume
splash_pal:
 ; Write 15→0. OUT 0Ch latches into the colour under the beam; if the
 ; write spills into the picture, the dominant idx0 background would
 ; otherwise absorb the last colour (white) and the real slot0 is lost.
 push hl
 ld de,15
 add hl,de                 ; HL -> table[15]
 ld e,15
splash_pal_loop:
 ld a,e
 out (2),a
 ld a,(hl)
 dec hl
 out (12),a
 out (12),a
 out (12),a
 out (12),a
 ; Settle before the next OUT 2 (Gorodetsky / real Vector quirk).
 dec e
 jp p,splash_pal_loop      ; e = 15..0
 ; Slot 0 again: after a spill it is the one most often overwritten.
 pop hl
 xor a
 out (2),a
 ld a,(hl)
 out (12),a
 out (12),a
 out (12),a
 out (12),a
 ret
splash_copy:
 ld a,(de)
 ld (hl),a
 inc de
 inc hl
 dec bc
 ld a,b
 or c
 jp nz,splash_copy
 ret
 ASSERT $ <= 0x100
 ORG 0x100
splash_payload: INCBIN "payload.zx0"
splash_resume_source:
 DISP 0xFEC0
splash_resume:
 ld sp,0xFFFE
 ; Moving input down leaves 256 bytes more than ZX0's in-place safety delta.
 ld de,splash_payload
 ld hl,0
 ld bc,PAYLOAD_BYTES
 call splash_move
 ld hl,PAYLOAD_BYTES-1
 ld de,CORE_END-1
 call splash_zx0_back
 ; The loaded game's forward decoder restores its small bootstrap page.
 ld hl,splash_prefix
 ld de,0
 call CORE_ZX0
splash_jump_game:
 jp 0
splash_move:
 ld a,(de)
 ld (hl),a
 inc de
 inc hl
 dec bc
 ld a,b
 or c
 jp nz,splash_move
 ret

; Backwards ZX0 v2: positive match offsets, reversed byte traversal,
; and zero-terminated interlaced Elias codes (Einar Saukas format).
splash_zx0_back:
 ld bc,1
 push bc
 ld bc,0
 ld a,0x80
sb_literals:
 call sb_elias
 push af
 call sb_copy
 pop af
 add a,a
 jp c,sb_offset
 call sb_elias
sb_match:
 ex (sp),hl
 push hl
 add hl,de
 push af
 call sb_copy
 pop af
 pop hl
 ex (sp),hl
 add a,a
 jp nc,sb_literals
sb_offset:
 pop bc
 ld bc,0
 call sb_elias
 inc c
 dec c
 ret z
 dec c
 ld b,c
 ld c,(hl)
 dec hl
 push af
 ld a,b
 or a
 rra
 ld b,a
 ld a,c
 rra
 ld c,a
 inc bc
 jp c,sb_long_length
 pop af
 push bc
 ld bc,2
 jp sb_match
sb_long_length:
 pop af
 push bc
 ld bc,1
 call sb_backtrack
 inc bc
 jp sb_match
sb_elias:
 inc c
sb_elias_loop:
 add a,a
 jp nz,sb_elias_bit
 ld a,(hl)
 dec hl
 rla
sb_elias_bit:
 ret nc
sb_backtrack:
 add a,a
 push af
 ld a,c
 rla
 ld c,a
 ld a,b
 rla
 ld b,a
 pop af
 jp sb_elias_loop
sb_copy:
 ld a,(hl)
 ld (de),a
 dec hl
 dec de
 dec bc
 ld a,b
 or c
 jp nz,sb_copy
 ret
splash_prefix: INCBIN "prefix.zx0"
splash_resume_end:
 ASSERT $ <= 0xFFE0       ; thirty bytes for the temporary decoder stack
 ENT
splash_resume_source_end:
 ; Keep tables below the screen bitplanes and below the splash stack at 7FFE.
splash_palette: INCBIN "palette.bin"
splash_black: ds 16,0
 ASSERT $ <= 0x7F00
 ORG 0x8000
splash_pixels: INCBIN "screen.bin"
 ASSERT $ == 0x10000
 SAVEBIN "splash.rom",0,0x10000
