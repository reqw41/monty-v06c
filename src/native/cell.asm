; Вывод клетки: тайл rr_t в клетку (rr_r, rr_c) — прямо из графики тайла в три плоскости экрана.
; Графика тайла — 8 байт точек: у анимированных — кадр tile_hi (dstore: 24 байта на тайл, кадры 1-3 по 8),
; у остальных — E000 + 8 * тайл. Цвет — байт цвета группы (8 тайлов, VCOL): cmodes[цвет] — что писать в
; плоскости 8000, A000, C000 (биты 5-4, 3-2, 1-0: 0 — 00, 1 — точки, 2 — точки инверсно, 3 — FF).
; Экран: L = 0DFh - 8 * строка (вниз — dec l), H = 80h + столбец (+20h — следующая плоскость).
; DCP sh: плоскость по режиму (dc_m >> sh) & 3 — без вызовов (SP занят)
		MACRO	DCP sh
		ld	a,(dc_m)
		IF	sh > 0
		REPT	sh
		rrca
		ENDR
		ENDIF
		and	3
		jp	z,.z
		dec	a
		jp	z,.p
		dec	a
		jp	z,.i
		ld	a,0xFF
		jp	.f
.z:		xor	a
.f:		ld	b,a			; 00/FF: стек — на строку выше верхней, 4 x PUSH
		ld	c,a
		inc	l
		ld	sp,hl
		dec	l
		REPT	4
		push	bc
		ENDR
		jp	.x
.p:		ex	de,hl			; точки: стек — на графику, 4 x POP
		ld	sp,hl
		ex	de,hl
		REPT	4
		pop	bc
		ld	(hl),c
		dec	l
		ld	(hl),b
		dec	l
		ENDR
		jp	.e
.i:		ex	de,hl			; точки инверсно
		ld	sp,hl
		ex	de,hl
		REPT	4
		pop	bc
		ld	a,c
		cpl
		ld	(hl),a
		dec	l
		ld	a,b
		cpl
		ld	(hl),a
		dec	l
		ENDR
.e:		ld	a,l
		add	a,8
		ld	l,a
.x:
		ENDM
; dc_tile: rr_t -> C = режимы плоскостей, DE = графика (8 байт)
dc_tile:
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
dcg1:
		ret
; dc_scr: rr_r, rr_c -> HL = экран (плоскость 8000, верхняя строка клетки)
dc_scr:		ld	a,(rr_r)
		add	a,a
		add	a,a
		add	a,a
		cpl
		add	a,0xE0			; 0DFh - 8 * строка
		ld	l,a
		ld	a,(rr_c)
		add	a,0x80
		ld	h,a
		ret
; draw_cell: тайл rr_t в клетку (rr_r, rr_c)
draw_cell:	call	dc_tile
		call	dc_scr
; dc_draw: C = режимы, DE = графика, HL = экран — три плоскости. Через стек (прерывания на время запрещены):
; 00/FF — PUSH (стек сверху столбца вниз), точки — POP из графики, запись в столбец. DE, HL — не меняются
dc_draw:	ld	a,c
		ld	(dc_m),a
		di
		push	hl			; SP — сохранить
		ld	hl,2
		add	hl,sp
		ld	(dc_sp),hl
		pop	hl
		DCP	4
		ld	a,h
		add	a,0x20
		ld	h,a
		DCP	2
		ld	a,h
		add	a,0x20
		ld	h,a
		DCP	0
		ld	a,h
		sub	0x40
		ld	h,a
		ex	de,hl
		ld	hl,(dc_sp)
		ld	sp,hl
		ex	de,hl
		ld	a,(in_isr)		; из прерывания (короткая часть) — не разрешать
		or	a
		ret	nz
		ei
		ret
