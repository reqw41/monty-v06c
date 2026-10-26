; Быстрый вывод клетки (игра): тайл rr_t в (rr_r, rr_c); режимы плоскостей — cmodes[цвет группы] (modes_build).
draw_cell:
		ld	a,(rr_t)		; цвет группы тайла -> режимы плоскостей
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
		ld	a,(rr_t)		; шаблон: (tile_hi << 8) + 8 * тайл
		ld	l,a
		ld	h,0
		add	hl,hl
		add	hl,hl
		add	hl,hl
		ld	a,(tile_hi)
		add	a,h
		ld	d,a
		ld	e,l
		ld	a,(rr_r)		; экран: L = 0DFh - 8 * ряд, H = 80h + столбец
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
		ld	a,(dc_m)		; 8000
		rrca
		rrca
		rrca
		rrca
		and	3
		call	pm_go
		ld	a,h
		add	a,0x20
		ld	h,a
		ld	a,(dc_m)		; A000
		rrca
		rrca
		and	3
		call	pm_go
		ld	a,h
		add	a,0x20
		ld	h,a
		ld	a,(dc_m)		; C000
		and	3
pm_go:		or	a
		jp	z,pm_0
		dec	a
		jp	z,pm_p
		dec	a
		jp	z,pm_n
		ld	a,0xFF
		jp	pm_f
pm_0:		xor	a
pm_f:		REPT	8
		ld	(hl),a
		dec	l
		ENDR
		ld	a,l
		add	a,8
		ld	l,a
		ret
pm_p:		REPT	8
		ld	a,(de)
		ld	(hl),a
		inc	e
		dec	l
		ENDR
		jp	pm_r
pm_n:		REPT	8
		ld	a,(de)
		cpl
		ld	(hl),a
		inc	e
		dec	l
		ENDR
pm_r:		ld	a,l
		add	a,8
		ld	l,a
		ld	a,e
		sub	8
		ld	e,a
		ret
