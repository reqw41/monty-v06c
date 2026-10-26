; Утилиты (общие для просмотра комнат и игры)
; fillb: HL, B байт (B = 0 — ничего) := A; HL продвигается
fillb:		inc	b
		dec	b
		ret	z
fb1:		ld	(hl),a
		inc	hl
		dec	b
		jp	nz,fb1
		ret
; memcpyb: (HL) <- (DE), B байт (B = 0 — ничего); HL, DE продвигаются
memcpyb:	inc	b
		dec	b
		ret	z
mc1:		ld	a,(de)
		ld	(hl),a
		inc	hl
		inc	de
		dec	b
		jp	nz,mc1
		ret
; memfill: HL, BC байт := E
memfill:	ld	a,b
		or	c
		ret	z
		ld	(hl),e
		inc	hl
		dec	bc
		jp	memfill
add_hl_a:	add	a,l
		ld	l,a
		ld	a,h
		adc	a,0
		ld	h,a
		ret
