; 9156-9199 — нативный модуль src/native/tiles.asm
		INCLUDE	"../native/tiles.asm"
; nt_read3: 3 байта VRAM 1800 + DE -> (HL) через слой OS7 (у края таблицы имён); HL, DE сохраняются
nt_read3:	push	hl
		push	de
		push	bc
		ex	de,hl			; DE = приёмник
		ld	bc,0x1800
		add	hl,bc			; HL = адрес VDP
		ld	bc,3
		call	vread
		pop	bc
		pop	de
		pop	hl
		ret
