; Вывод клетки (игра): тайл rr_t в (rr_r, rr_c) через кэш изображений тайлов.
; Изображение — 24 байта: плоскость 8000 (8 строк сверху вниз), A000, C000. Кэш: tslot[тайл] = номер ячейки
; (FF — нет), ячеек TC_N по 24 байта; при заполнении — сброс целиком. Сброс по тайлам — cache_drop_flags.
; Вывод: SP на изображение, POP BC — два байта; HL идёт по столбцу вниз (прерывания на время запрещены).
TC_N		equ	48

draw_cell:
		ld	a,(rr_t)
		ld	l,a
		ld	h,tslot/256
		ld	a,(hl)
		cp	0xFF
		jp	nz,dc_hit
		call	tc_alloc		; A = ячейка, изображение отрисовано
dc_hit:		ld	l,a			; HL = tcache + 24 * A
		ld	h,0
		add	hl,hl
		add	hl,hl
		add	hl,hl
		ld	d,h
		ld	e,l
		add	hl,hl
		add	hl,de
		ld	de,tcache
		add	hl,de
		ex	de,hl			; DE = изображение
		ld	a,(rr_r)		; HL = экран: L = 0DFh - 8 * ряд, H = 80h + столбец
		add	a,a
		add	a,a
		add	a,a
		ld	b,a
		ld	a,0xDF
		sub	b
		ld	l,a
		ld	a,(rr_c)
		add	a,0x80
		ld	h,a
		di
		ld	(dc_hl),hl		; SP -> изображение (SP сохранить)
		ld	hl,0
		add	hl,sp
		ld	(dc_sp),hl
		ex	de,hl
		ld	sp,hl
		ld	hl,(dc_hl)
		REPT	3			; плоскости
		REPT	4
		pop	bc
		ld	(hl),c
		dec	l
		ld	(hl),b
		dec	l
		ENDR
		ld	a,l			; следующая плоскость: L + 8, H + 20h
		add	a,8
		ld	l,a
		ld	a,h
		add	a,0x20
		ld	h,a
		ENDR
		ld	hl,(dc_sp)
		ld	sp,hl
		ei
		ret

; tc_alloc: тайл rr_t — новая ячейка (при заполнении — сброс кэша), изображение; A = ячейка
tc_alloc:
		ld	a,(tc_next)
		cp	TC_N
		jp	c,tca1
		call	cache_flush
		xor	a
tca1:		ld	b,a
		inc	a
		ld	(tc_next),a
		ld	a,(rr_t)
		ld	l,a
		ld	h,tslot/256
		ld	(hl),b
		ld	a,b
		push	af
		ld	l,a			; DE = tcache + 24 * ячейка
		ld	h,0
		add	hl,hl
		add	hl,hl
		add	hl,hl
		ld	d,h
		ld	e,l
		add	hl,hl
		add	hl,de
		ld	de,tcache
		add	hl,de
		call	tile_render
		pop	af
		ret

; cache_flush: кэш пуст
cache_flush:
		push	hl
		push	bc
		push	de
		ld	hl,tslot
		ld	bc,256
		ld	e,0xFF
		call	memfill
		xor	a
		ld	(tc_next),a
		pop	de
		pop	bc
		pop	hl
		ret

; cache_drop_flags: H = страница таблицы флагов по тайлам — отмеченные тайлы из кэша убрать
cache_drop_flags:
		ld	l,0
		ld	d,tslot/256
cdf1:		ld	a,(hl)
		or	a
		jp	z,cdf2
		ld	e,l
		ld	a,0xFF
		ld	(de),a
cdf2:		inc	l
		jp	nz,cdf1
		ret

; tile_render: изображение тайла rr_t в (HL): 3 плоскости по 8 байт; режимы — cmodes[цвет группы]
tile_render:
		push	hl
		ld	a,(rr_t)		; цвет группы -> режимы плоскостей
		rrca
		rrca
		rrca
		and	0x1F
		add	a,VCOL&0xFF
		ld	l,a
		ld	h,VCOL/256
		ld	l,(hl)
		ld	h,cmodes/256
		ld	a,(hl)
		ld	(dc_m),a
		ld	a,(rr_t)		; шаблон: различие банка tile_hi (если есть) или банк 0
		ld	l,a
		ld	h,dslot/256
		ld	a,(tile_hi)
		or	a
		jp	z,trb0
		ld	a,(hl)
		cp	0xFF
		jp	z,trb0
		ld	e,a			; dstore + 24 * номер + 8 * (банк - 1)
		ld	d,0
		ld	h,d
		ld	l,e
		add	hl,hl
		add	hl,de
		add	hl,hl
		add	hl,hl
		add	hl,hl
		ld	de,dstore
		add	hl,de
		ld	a,(tile_hi)
		dec	a
		add	a,a
		add	a,a
		add	a,a
		call	add_hl_a
		ex	de,hl
		jp	trb1
trb0:		ld	a,(rr_t)		; банк 0: E000 + 8 * тайл
		ld	l,a
		ld	h,0
		add	hl,hl
		add	hl,hl
		add	hl,hl
		ld	a,h
		add	a,0xE0
		ld	d,a
		ld	e,l
trb1:
		pop	hl
		ld	a,(dc_m)		; 8000
		rrca
		rrca
		rrca
		rrca
		and	3
		call	tr_go
		ld	a,(dc_m)		; A000
		rrca
		rrca
		and	3
		call	tr_go
		ld	a,(dc_m)		; C000
		and	3
tr_go:		or	a
		jp	z,tr_0
		dec	a
		jp	z,tr_p
		dec	a
		jp	z,tr_n
		ld	a,0xFF
		jp	tr_f
tr_0:		xor	a
tr_f:		REPT	8
		ld	(hl),a
		inc	hl
		ENDR
		ret
tr_p:		push	de
		REPT	8
		ld	a,(de)
		ld	(hl),a
		inc	hl
		inc	e
		ENDR
		pop	de
		ret
tr_n:		push	de
		REPT	8
		ld	a,(de)
		cpl
		ld	(hl),a
		inc	hl
		inc	e
		ENDR
		pop	de
		ret
