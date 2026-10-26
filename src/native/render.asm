; Цвета комнаты, палитра и вывод теневой таблицы имён в 3 плоскости (8000 — бит 2 индекса, A000 — бит 1,
; C000 — бит 0; E000 невидима: палитра Вектора парами). Поле MSX 256x192: строка Y -> младший байт 0DFh - Y.

		IFDEF	VIEWER
; --- col_build: coltab := colors_base, элементы 1..7 := палитра этажа (row_cur), темнота (FLOOR_PALETTE 8EB0)
col_build:
		ld	hl,coltab
		ld	de,colors_base
		ld	b,32
		call	memcpyb
		ld	a,(row_cur)
		cp	8
		jp	c,cb1
		ld	a,8
cb1:		ld	b,a			; floors + 7 * этаж
		add	a,a
		add	a,a
		add	a,a
		sub	b
		ld	e,a
		ld	d,0
		ld	hl,floors
		add	hl,de
		ex	de,hl
		ld	hl,coltab+1
		ld	b,7
		call	memcpyb
		ld	a,(lv_cur)		; темнота: ряд >= 9 - уровень
		ld	b,a
		ld	a,9
		sub	b
		ld	b,a
		ld	a,(row_cur)
		cp	b
		ret	c
		ld	hl,dark_groups
cb2:		ld	a,(hl)
		cp	0xFF
		ret	z
		inc	hl
		ld	e,a
		ld	d,0
		push	hl
		ld	hl,coltab
		add	hl,de
		ld	(hl),0
		pop	hl
		jp	cb2
dark_groups:	db	0x00,0x01,0x02,0x10,0x11,0x12,0x13,0x15,0x16,0x17,0x18,0xFF

		ENDIF

; --- pal_build: какие цвета MSX видны (таблица имён + герой 6, 11 + фон 1), слияние до 8, индексы ----
pal_build:
		ld	hl,used
		ld	bc,64			; used, repl, cmap, pal
		ld	e,0
		call	memfill
		ld	a,1
		ld	(used+1),a
		ld	(used+6),a
		ld	(used+11),a
		call	spr_ecolor		; цвет врагов комнаты — в палитре на индексе 4 (только плоскость 8000)
		ld	(spr_E),a
		ld	hl,used
		call	add_hl_a
		ld	(hl),1
		ld	hl,NT
		ld	bc,768
pb1:		push	bc
		ld	a,(hl)
		inc	hl
		push	hl
		call	cell_colors		; D = цвет точек, E = цвет фона (0 -> 1)
		ld	hl,used
		ld	a,d
		call	add_hl_a
		ld	(hl),1
		ld	hl,used
		ld	a,e
		call	add_hl_a
		ld	(hl),1
		pop	hl
		pop	bc
		dec	bc
		ld	a,b
		or	c
		jp	nz,pb1
		ld	hl,repl			; repl[c] := c
		xor	a
pb2:		ld	(hl),a
		inc	hl
		inc	a
		cp	16
		jp	nz,pb2
pb3:		call	used_count		; пока больше 8 — слить ближайшую пару из видимых
		cp	9
		jp	c,pb6
		ld	hl,merge_pairs
pb4:		ld	a,(hl)
		cp	0xFF
		jp	z,pb6
		ld	d,a			; убираемый
		inc	hl
		ld	e,(hl)			; замена
		inc	hl
		push	hl
		ld	hl,used
		ld	a,d
		call	add_hl_a
		ld	a,(hl)
		or	a
		jp	z,pb5
		push	hl
		ld	hl,used
		ld	a,e
		call	add_hl_a
		ld	a,(hl)
		pop	hl
		or	a
		jp	z,pb5
		ld	(hl),0			; used[d] := 0, repl[d] := e
		ld	hl,repl
		ld	a,d
		call	add_hl_a
		ld	(hl),e
		pop	hl
		jp	pb3
pb5:		pop	hl
		jp	pb4
pb6:		ld	c,0			; индексы видимым цветам по порядку; палитра парами
		ld	b,1
pb7:		ld	hl,used
		ld	a,b
		call	add_hl_a
		ld	a,(hl)
		or	a
		jp	z,pb8
		ld	a,(spr_E)		; цвет врагов — индекс 4, остальные — по порядку мимо 4
		cp	b
		ld	a,4
		jp	z,pb7b
		ld	a,c
		cp	4
		jp	nz,pb7a
		inc	c
pb7a:		ld	a,c
		inc	c
pb7b:		push	bc
		ld	c,a
		ld	hl,cmap
		ld	a,b
		call	add_hl_a
		ld	(hl),c
		ld	hl,msx2vec
		ld	a,b
		call	add_hl_a
		ld	e,(hl)
		ld	hl,pal
		ld	a,c
		add	a,a
		call	add_hl_a
		ld	(hl),e
		inc	hl
		ld	(hl),e
		pop	bc
pb8:		inc	b
		ld	a,b
		cp	16
		jp	nz,pb7
		ld	b,1			; слитые: cmap[c] := cmap[конец цепочки repl]
pb9:		ld	d,b
pb10:		ld	hl,repl
		ld	a,d
		call	add_hl_a
		ld	a,(hl)
		cp	d
		jp	z,pb11
		ld	d,a
		jp	pb10
pb11:		ld	hl,cmap
		ld	a,d
		call	add_hl_a
		ld	e,(hl)
		ld	hl,cmap
		ld	a,b
		call	add_hl_a
		ld	(hl),e
		inc	b
		ld	a,b
		cp	16
		jp	nz,pb9
		ld	a,(cmap+1)		; прозрачный 0 — цвет фона (R7 = 1)
		ld	(cmap+0),a
		ret

; spr_ecolor: A = цвет врагов комнаты — первый видимый спрайт VSAT с цветом 15, 12 или 14 (иначе 15)
spr_ecolor:
		ld	hl,VSAT
		ld	b,SPR_MAX
sec1:		ld	a,(hl)
		cp	0xD0
		jp	z,sec9
		inc	hl
		inc	hl
		inc	hl
		ld	a,(hl)
		and	0x0F
		inc	hl
		cp	15
		ret	z
		cp	12
		ret	z
		cp	14
		ret	z
		dec	b
		jp	nz,sec1
sec9:		ld	a,15
		ret

used_count:	ld	hl,used
		ld	b,16
		xor	a
uc1:		add	a,(hl)
		inc	hl
		dec	b
		jp	nz,uc1
		ret

; cell_colors: A = тайл -> D = цвет точек, E = цвет фона (MSX, 0 -> 1)
cell_colors:
		rrca
		rrca
		rrca
		and	0x1F
		ld	hl,coltab
		call	add_hl_a
		ld	a,(hl)
		ld	e,a
		rrca
		rrca
		rrca
		rrca
		and	0x0F
		jp	nz,cc1
		inc	a
cc1:		ld	d,a
		ld	a,e
		and	0x0F
		jp	nz,cc2
		inc	a
cc2:		ld	e,a
		ret

; --- render_all: вся таблица имён в плоскости ---------------------------------------------------------
		IFDEF	VIEWER
render_all:
		xor	a
		ld	(rr_r),a
		ld	hl,NT
		ld	(rr_nt),hl
ra_row:		xor	a
		ld	(rr_c),a
ra_cell:	ld	hl,(rr_nt)
		ld	a,(hl)
		inc	hl
		ld	(rr_nt),hl
		ld	(rr_t),a
		call	draw_cell
		ld	a,(rr_c)
		inc	a
		ld	(rr_c),a
		cp	32
		jp	nz,ra_cell
		ld	a,(rr_r)
		inc	a
		ld	(rr_r),a
		cp	24
		jp	nz,ra_row
		ret
		ENDIF

		IFDEF	VIEWER
; --- draw_cell: тайл rr_t в клетку (rr_r, rr_c) ---------------------------------------------------------
draw_cell:
		ld	a,(rr_t)
		call	cell_colors
		ld	hl,cmap			; D, E -> индексы Вектора
		ld	a,d
		call	add_hl_a
		ld	d,(hl)
		ld	hl,cmap
		ld	a,e
		call	add_hl_a
		ld	e,(hl)
		ld	hl,rr_m			; маски: точки/фон для плоскостей 8000 (бит 2), A000 (1), C000 (0)
		ld	b,4
ra_m:		ld	a,d
		and	b
		call	msk
		ld	(hl),a
		inc	hl
		ld	a,e
		and	b
		call	msk
		ld	(hl),a
		inc	hl
		ld	a,b
		rrca
		ld	b,a
		cp	0x80
		jp	nz,ra_m
		ld	a,(rr_t)		; шаблон: банк (tile_hi << 8) + 8 * тайл
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
		ld	a,8
		ld	(rr_y),a
ra_y:		ld	a,(de)
		inc	de
		ld	(rr_p),a
		cpl
		ld	(rr_np),a
		ld	a,(rr_m+1)		; 8000
		call	ra_byte
		ld	(hl),a
		ld	a,h
		add	a,0x20
		ld	h,a
		ld	a,(rr_m+3)		; A000
		ld	b,a
		ld	a,(rr_m+2)
		ld	c,a
		ld	a,(rr_np)
		and	b
		ld	b,a
		ld	a,(rr_p)
		and	c
		or	b
		ld	(hl),a
		ld	a,h
		add	a,0x20
		ld	h,a
		ld	a,(rr_m+5)		; C000
		ld	b,a
		ld	a,(rr_m+4)
		ld	c,a
		ld	a,(rr_np)
		and	b
		ld	b,a
		ld	a,(rr_p)
		and	c
		or	b
		ld	(hl),a
		ld	a,h
		sub	0x40
		ld	h,a
		dec	l
		ld	a,(rr_y)
		dec	a
		ld	(rr_y),a
		jp	nz,ra_y
		ret

		ENDIF

; ra_byte: A = маска фона плоскости 8000, (rr_m+0) — маска точек -> A = байт
ra_byte:	ld	b,a
		ld	a,(rr_m+0)
		ld	c,a
		ld	a,(rr_np)
		and	b
		ld	b,a
		ld	a,(rr_p)
		and	c
		or	b
		ret

msk:		or	a
		ret	z
		ld	a,0xFF
		ret

; clear_screen: 8000-FFFF := 0
clear_screen:
		ld	hl,0x8000
		ld	bc,0x8000
		ld	e,0
		jp	memfill
