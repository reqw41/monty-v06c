; AEA7-AEFD — нативный модуль src/native/block.asm
		INCLUDE	"../native/block.asm"
; nt_put / nt_get: C байт (B = 0) между (HL) и VRAM 1800 + DE через слой OS7 (у края таблицы имён)
nt_put:		push	hl
		push	de
		push	bc
		ex	de,hl			; DE = источник
		push	bc
		ld	bc,0x1800
		add	hl,bc
		pop	bc
		call	vwrite
		pop	bc
		pop	de
		pop	hl
		ret
nt_get:		push	hl
		push	de
		push	bc
		ex	de,hl			; DE = приёмник
		push	bc
		ld	bc,0x1800
		add	hl,bc
		pop	bc
		call	vread
		pop	bc
		pop	de
		pop	hl
		ret
