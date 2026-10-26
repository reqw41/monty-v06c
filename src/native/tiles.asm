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
		ld	b,a
		rrca
		rrca
		rrca
		and	0x1F
		ld	e,a
		ld	a,b
		and	7
		jp	z,tl1
		inc	e
tl1:		ld	a,e
		and	0x1F
		dec	a			; строка - 1 (0 -> FF, как у оригинала: 32 * 255)
		ld	l,a
		ld	h,0
		add	hl,hl
		add	hl,hl
		add	hl,hl
		add	hl,hl
		add	hl,hl
		ld	a,(0x7085)		; столбец = ceil(X' / 8) (до 32)
		dec	a
		add	a,c
		ld	b,a
		rrca
		rrca
		rrca
		and	0x1F
		ld	e,a
		ld	a,b
		and	7
		jp	z,tl2
		inc	e
tl2:		ld	d,0
		add	hl,de
		ld	de,0xFFDF		; - 21h
		add	hl,de
		ld	(0x71B0),hl
		ex	de,hl			; DE = клетка
		ld	hl,0x70AF		; вложенность вывода (A8B7/A8C3 оригинала)
		inc	(hl)
		ld	a,(0x705F)
		or	2
		ld	(0x705F),a
		ld	a,d			; клетка + 22h внутри таблицы имён (0..2FF)?
		cp	2
		jp	nc,tl_slow
		pop	hl			; HL = приёмник
		push	de
		ex	de,hl
		ld	bc,VNT
		add	hl,bc			; HL = VNT + клетка, DE = приёмник
		ld	a,(hl)
		ld	(de),a
		inc	hl
		inc	de
		ld	a,(hl)
		ld	(de),a
		inc	hl
		inc	de
		ld	a,(hl)
		ld	(de),a
		inc	de
		ld	bc,30
		add	hl,bc
		ld	a,(hl)
		ld	(de),a
		inc	hl
		inc	de
		ld	a,(hl)
		ld	(de),a
		inc	hl
		inc	de
		ld	a,(hl)
		ld	(de),a
		pop	de
tl9:		ld	hl,0x70AF
		dec	(hl)
		jp	nz,tl10
		ld	a,(0x705F)
		and	0xFD
		ld	(0x705F),a
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
