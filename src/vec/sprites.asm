; Программные спрайты 16x16 по таблице атрибутов VSAT (TMS9918: Y, X, имя, цвет | EC). Каждый кадр:
; spr_erase — клетки под прошлыми прямоугольниками к перерисовке (до draw_rows), spr_draw — вывод поверх
; в обратном порядке (меньший номер сверху). Y = D0 — конец списка. Цвет 0 — спрайт не виден.
SPR_MAX		equ	8

; spr_changed: NZ — атрибуты первых SPR_MAX спрайтов (VSAT) не те, что в прошлый раз; spr_last := VSAT
spr_changed:
		ld	hl,VSAT
		ld	de,spr_last
		ld	b,4*SPR_MAX
		ld	c,0
sc1:		ld	a,(de)
		cp	(hl)
		jp	z,sc2
		ld	a,(hl)
		ld	(de),a
		ld	c,1
sc2:		inc	hl
		inc	de
		dec	b
		jp	nz,sc1
		ld	a,c
		or	a
		ret

spr_erase:
		ld	a,(spr_n)
		or	a
		ret	z
		ld	b,a
		ld	hl,spr_prev		; пары (Y экрана 0..255, X 0..255) прошлого кадра
se1:		ld	d,(hl)			; D = верхняя строка
		inc	hl
		ld	e,(hl)			; E = X
		inc	hl
		push	hl
		push	bc
		call	force_rect
		pop	bc
		pop	hl
		dec	b
		jp	nz,se1
		ret

; force_rect: D = верхняя строка (0..191, может быть > 191 — снизу/сверху за краем), E = X: клетки 3x3
force_rect:
		ld	a,d			; строки клеток: D>>3 .. (D+15)>>3, только 0..23
		rrca
		rrca
		rrca
		and	0x1F
		ld	c,a			; первая строка клеток
		ld	b,3
fr1:		ld	a,c
		cp	24
		jp	nc,fr4
		push	bc
		push	de
		ld	l,a			; HL = 32 * строка + столбец
		ld	h,0
		add	hl,hl
		add	hl,hl
		add	hl,hl
		add	hl,hl
		add	hl,hl
		ld	a,e
		rrca
		rrca
		rrca
		and	0x1F
		ld	d,a			; столбец
		call	add_hl_a
		push	hl
		ld	hl,row_dirty
		ld	a,c
		call	add_hl_a
		ld	(hl),1
		pop	hl
		ld	b,3
fr2:		ld	a,d
		cp	32
		jp	nc,fr3
		push	hl
		push	de
		ex	de,hl
		ld	hl,VNT
		add	hl,de
		ld	a,(hl)
		cpl
		ld	hl,NTS
		add	hl,de
		ld	(hl),a
		pop	de
		pop	hl
fr3:		inc	hl
		inc	d
		dec	b
		jp	nz,fr2
		pop	de
		pop	bc
fr4:		inc	c
		dec	b
		jp	nz,fr1
		ret

spr_draw:
		ld	hl,VSAT			; число спрайтов до Y = D0
		ld	b,0
sd0:		ld	a,(hl)
		cp	0xD0
		jp	z,sd1
		inc	hl
		inc	hl
		inc	hl
		inc	hl
		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,sd0
sd1:		xor	a
		ld	(spr_n),a
		ld	a,b
		or	a
		ret	z
sd2:		dec	b			; с последнего
		push	bc
		ld	l,b
		ld	h,0
		add	hl,hl
		add	hl,hl
		ld	de,VSAT
		add	hl,de
		call	spr_one
		pop	bc
		ld	a,b
		or	a
		jp	nz,sd2
		ret

; spr_one: HL -> атрибуты спрайта
spr_one:
		ld	a,(hl)			; Y: верхняя строка = Y + 1
		inc	a
		ld	(sp_y),a
		inc	hl
		ld	a,(hl)
		ld	(sp_x),a
		inc	hl
		ld	a,(hl)
		and	0xFC
		ld	(sp_name),a
		inc	hl
		ld	a,(hl)
		and	0x80			; EC: X - 32 (не поддерживаем: спрайт не рисуется)
		ret	nz
		ld	a,(hl)
		and	0x0F
		ret	z
		ld	hl,cmap			; индекс Вектора
		call	add_hl_a
		ld	a,(hl)
		ld	(sp_ci),a
		ld	hl,spr_n		; запомнить прямоугольник для стирания
		ld	a,(hl)
		inc	(hl)
		add	a,a
		ld	hl,spr_prev
		call	add_hl_a
		ld	a,(sp_y)
		ld	(hl),a
		inc	hl
		ld	a,(sp_x)
		ld	(hl),a
		ld	a,(sp_name)		; шаблон: VSPR + 8 * имя
		ld	l,a
		ld	h,0
		add	hl,hl
		add	hl,hl
		add	hl,hl
		ld	de,VSPR
		add	hl,de
		ld	(sp_pat),hl
		xor	a
		ld	(sp_line),a
so1:		ld	a,(sp_y)		; строка экрана
		ld	b,a
		ld	a,(sp_line)
		add	a,b
		cp	192
		jp	nc,so9			; за нижним краем или «отрицательная» (Y > 191)
		ld	b,a
		ld	a,0xDF
		sub	b
		ld	(sp_lo),a
		ld	hl,(sp_pat)		; левая половина — +line, правая — +16+line
		ld	a,(sp_line)
		call	add_hl_a
		ld	d,(hl)
		ld	a,16
		call	add_hl_a
		ld	e,(hl)
		ld	a,d			; пустая строка — пропустить
		or	e
		jp	z,so9
		ld	a,(sp_x)		; сдвиг на X & 7: D E 0 -> три байта sb0 sb1 sb2
		and	7
		ld	c,0
		ld	b,a
so2:		ld	a,b
		or	a
		jp	z,so3
		ld	a,d
		or	a
		rra
		ld	d,a
		ld	a,e
		rra
		ld	e,a
		ld	a,c
		rra
		ld	c,a
		dec	b
		jp	so2
so3:		ld	a,d
		ld	(sb0),a
		ld	a,e
		ld	(sb1),a
		ld	a,c
		ld	(sb2),a
		ld	a,(sp_x)		; первый столбец
		rrca
		rrca
		rrca
		and	0x1F
		ld	c,a
		ld	hl,sb0
		ld	b,3
so4:		ld	a,c
		cp	32
		jp	nc,so9
		ld	a,(hl)
		or	a
		jp	z,so8
		push	hl
		push	bc
		ld	e,a			; E = маска
		ld	a,(sp_lo)
		ld	l,a
		ld	a,c
		add	a,0x80
		ld	h,a
		ld	a,(sp_ci)
		ld	d,a
		ld	b,3			; плоскости 8000 (бит 2), A000 (бит 1), C000 (бит 0)
		ld	a,d
		rlca
		rlca
		rlca
		rlca
		rlca
		ld	d,a			; бит 2 индекса -> бит 7
so5:		ld	a,d
		rlca
		ld	d,a
		jp	nc,so6
		ld	a,(hl)
		or	e
		ld	(hl),a
		jp	so7
so6:		ld	a,e
		cpl
		and	(hl)
		ld	(hl),a
so7:		ld	a,h
		add	a,0x20
		ld	h,a
		dec	b
		jp	nz,so5
		pop	bc
		pop	hl
so8:		inc	hl
		inc	c
		dec	b
		jp	nz,so4
so9:		ld	a,(sp_line)
		inc	a
		ld	(sp_line),a
		cp	16
		jp	nz,so1
		ret
