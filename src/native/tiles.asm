; Нативно: тайлы под объектом (9156, 9159, 916C) — по src/model/vram.js. Читает копию таблицы имён VNT прямо.
; Входная метка L_9156 — от транслятора (или нативной сборки).
; 9156: герой (второй слой, 7304). 9159: HL -> Y, X объекта: 7084, 7085 := Y, X; тайлы 3x2 вокруг -> 7057..705C.
		ld	hl,0x7304
L_9159:		ld	a,(hl)
		ld	(0x7084),a
		inc	hl
		ld	a,(hl)
		ld	(0x7085),a
		ld	bc,0x1202
		ld	hl,0x7057
; 916C: клетка (строка ceil((7084 + B) / 8), столбец ceil((7085 - 1 + C) / 8)) - 21h -> 71B0;
; тайлы 2 строки по 3 начиная с неё -> (HL). Выход: HL = 7000, DE = клетка, BC = 0203h.
L_916C:		push	hl
		ld	a,(0x7084)		; строка = ceil(Y' / 8) & 1F
		add	a,b
		dec	a			; (ceil(Y'/8)&31)-1, including 00/F9..FF -> FF
		cp	0xF8
		jp	nc,tl_row_wrap
		and	0xF8
		ld	l,a
		ld	h,0
		add	hl,hl
		add	hl,hl
		jp	tl_row_done
tl_row_wrap:	ld	hl,0x1FE0
tl_row_done:
		ld	a,(0x7085)		; столбец = ceil(X' / 8) (до 32)
		dec	a
		add	a,c
		add	a,7			; 9-bit sum, ceil(X'/8) = 0..32
		rra
		rrca
		rrca
		and	0x3F
		ld	e,a
		ld	d,0
		add	hl,de
		ld	de,0xFFDF		; - 21h
		add	hl,de
		ld	(0x71B0),hl
		ex	de,hl			; DE = клетка
		ld	a,d			; клетка .. клетка + 22h внутри таблицы имён (0..2FF)? (клетка <= 2DDh)
		cp (NT_CELLS-35)/256
		jp c,tl_f
		jp	nz,tl_slow
		ld	a,e
		cp (NT_CELLS-34)&255
		jp nc,tl_slow
tl_f:
		pop	hl			; HL = приёмник
		push	de
		ex	de,hl
		ld	bc,VNT
		add	hl,bc			; HL = VNT + клетка, DE = приёмник
 IFDEF NES_FULL
 call nf_read_tile
 ELSE
		ld a,(hl)
 ENDIF
		ld (de),a
		inc	hl
		inc	de
 IFDEF NES_FULL
 call nf_read_tile
 ELSE
		ld a,(hl)
 ENDIF
		ld (de),a
		inc	hl
		inc	de
 IFDEF NES_FULL
 call nf_read_tile
 ELSE
		ld a,(hl)
 ENDIF
		ld (de),a
		inc	de
		ld	bc,30
		add	hl,bc
 IFDEF NES_FULL
 call nf_read_tile
 ELSE
		ld a,(hl)
 ENDIF
		ld (de),a
		inc	hl
		inc	de
 IFDEF NES_FULL
 call nf_read_tile
 ELSE
		ld a,(hl)
 ENDIF
		ld (de),a
		inc	hl
		inc	de
 IFDEF NES_FULL
 call nf_read_tile
 ELSE
		ld a,(hl)
 ENDIF
		ld (de),a
		pop	de
tl9:		ld	a,(0x70AF)		; no callbacks in the read: apply only the final flag effect
		or	a
		ld	a,(0x705F)
		jp	nz,tl_nested
		and	0xFD
		jp	tl_flags
tl_nested:	or	2
tl_flags:	ld	(0x705F),a
tl10:		ld	hl,0x7000
		ld	bc,0x0203
		ret
tl_slow:	pop	hl			; у края: через общий путь чтения (nt_read3: DE = клетка, HL = приёмник)
		push	de
		call	nt_read3
		ex	de,hl
		ld	bc,0x20
		add	hl,bc
		ex	de,hl
		ld	bc,3
		add	hl,bc
		call	nt_read3
		pop	de
		jp	tl9
