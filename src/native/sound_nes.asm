; Full NES game uses NES effects directly; STRICT retains the MSX sequencer.

L_AC06:		push	hl
		push	bc
		ld	hl,0x71B2
		ld	b,7
ac0:		ld	(hl),0xFF
		inc	hl
		dec	b
		jp	nz,ac0
		pop	bc
		pop	hl
		ret


L_AC1A:
 push af
 push bc
 push de
 push hl
 ld b,a
 ld a,1
 ld (snd_busy),a
 call nes_event
 xor a
 ld (snd_busy),a
 pop hl
 pop de
 pop bc
 pop af
 ret
L_AC6D:
L_AC77:
snd_quiet:
snd_off:
snd_off0:
sn_out:
 ret
 INCLUDE "gen/music_low.asm"
 INCLUDE "nes_queue.asm"
vi_off:
 ld a,0x30
 out (0x08),a
 ld a,0x70
 out (0x08),a
 ld a,0xB0
 out (0x08),a
 ret
