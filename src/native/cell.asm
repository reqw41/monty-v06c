; Вывод клетки: тайл rr_t в клетку (rr_r, rr_c) — прямо из графики тайла в три плоскости экрана.
; Графика тайла — 8 байт точек: у анимированных — кадр tile_hi (dstore: 24 байта на тайл, кадры 1-3 по 8),
; у остальных — E000 + 8 * тайл. Цвет — байт цвета группы (8 тайлов, VCOL): cmodes[цвет] — что писать в
; плоскости 8000, A000, C000 (биты 5-4, 3-2, 1-0: 0 — 00, 1 — точки, 2 — точки инверсно, 3 — FF).
; Экран: L = 0DFh - 8 * строка (вниз — dec l), H = 80h + столбец (+20h — следующая плоскость).
draw_cell:
		ld	a,(rr_t)		; цвет группы -> режимы плоскостей (C)
		ld	b,a
		rrca
		rrca
		rrca
		and	0x1F
		add	a,VCOL&0xFF
		ld	l,a
		ld	h,VCOL/256
		ld	l,(hl)
		ld	h,cmodes/256
		ld	c,(hl)
		ld	a,(tile_hi)		; графика: кадр анимации tile_hi (если у тайла есть кадры) или E000
		or	a
		jp	z,dcg0
		ld	l,b
		ld	h,dslot/256
		ld	a,(hl)
		cp	0xFF
		jp	z,dcg0
		ld	e,a			; dstore + 24 * номер + 8 * (кадр - 1)
		ld	d,0
		ld	h,d
		ld	l,e
		add	hl,hl
		add	hl,de
		add	hl,hl
		add	hl,hl
		add	hl,hl
		ld	de,dstore-8
		add	hl,de
		ld	a,(tile_hi)
		add	a,a
		add	a,a
		add	a,a
		call	add_hl_a
		ex	de,hl
		jp	dcg1
dcg0:		ld	l,b			; E000 + 8 * тайл
		ld	h,0
		add	hl,hl
		add	hl,hl
		add	hl,hl
		ld	a,h
		add	a,0xE0
		ld	d,a
		ld	e,l
dcg1:		ld	a,(rr_r)		; экран
		add	a,a
		add	a,a
		add	a,a
		cpl
		add	a,0xE0			; 0DFh - 8 * строка
		ld	l,a
		ld	a,(rr_c)
		add	a,0x80
		ld	h,a
		ld	a,c			; 8000
		rrca
		rrca
		rrca
		rrca
		call	dc_pl
		ld	a,c			; A000
		rrca
		rrca
		call	dc_pl
		ld	a,c			; C000
; dc_pl: A & 3 — режим плоскости: 8 байт в столбец HL (вниз), DE — точки; затем H += 20h (L, DE — как были)
dc_pl:		and	3
		jp	z,dcp_0
		dec	a
		jp	z,dcp_p
		dec	a
		jp	z,dcp_n
		ld	a,0xFF
		jp	dcp_f
dcp_0:		xor	a
dcp_f:		REPT	8
		ld	(hl),a
		dec	l
		ENDR
		jp	dcp_x
dcp_p:		REPT	8
		ld	a,(de)
		ld	(hl),a
		inc	e
		dec	l
		ENDR
		jp	dcp_e
dcp_n:		REPT	8
		ld	a,(de)
		cpl
		ld	(hl),a
		inc	e
		dec	l
		ENDR
dcp_e:		ld	a,e
		sub	8
		ld	e,a
dcp_x:		ld	a,l
		add	a,8
		ld	l,a
		ld	a,h
		add	a,0x20
		ld	h,a
		ret
