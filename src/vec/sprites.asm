; Программные спрайты 16x16 по таблице атрибутов VSAT (TMS9918: Y, X, имя, цвет | EC) с сохранением фона.
; Кадр: spr_restore (фон назад, в порядке, обратном рисованию) -> вывод клеток -> spr_draw (с последнего:
; меньший номер сверху). Спрайт — до 3 столбцов x 3 плоскости вертикальных полос по 16 строк. Маски столбцов
; (sm_or[3][16]) считаются один раз на спрайт; AND-плоскости берут инверсию на лету. Полосы — развёрнутые блоки,
; адреса входа (по числу строк) подставляются в команды CALL (самоизменяемый код). Спрайт с тем же (X, Y), что
; у нарисованного перед ним, фон не сохраняет (слои героя). Y = D0 — конец, цвет 0 — не виден, EC и Y > BF — нет.
SPR_MAX		equ	6
SREC		equ	8			; запись: L верхней строки, столбец, строк, сохранён, пустые столбцы (биты 0-2)

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

; --- развёрнутые полосы: HL = экран (верхняя строка), DE = буфер или маска; вход — конец - строк * шаг ---
st_or:		REPT	16			; маска в выровненной странице
		ld	a,(de)
		or	(hl)
		ld	(hl),a
		inc	e
		dec	l
		ENDR
		ret
st_and:		REPT	16
		ld	a,(de)
		cpl
		and	(hl)
		ld	(hl),a
		inc	e
		dec	l
		ENDR
		ret

; set_entries: по st_rows — адреса входа в блоки в командах CALL (cs_or, cs_and)
set_entries:
		ld	a,(st_rows)
		ld	b,a
		add	a,a
		add	a,a			; 4 * строк
		ld	c,a
		ld	a,c
		add	a,b
		ld	c,a			; 5 * строк
		ld	hl,st_or+16*5
		call	sub_hl_c
		ld	(cs_or+1),hl
		ld	a,c
		add	a,b
		ld	c,a			; 6 * строк
		ld	hl,st_and+16*6
		call	sub_hl_c
		ld	(cs_and+1),hl
		ret
sub_hl_c:	ld	a,l
		sub	c
		ld	l,a
		ld	a,h
		sbc	a,0
		ld	h,a
		ret

; cols_build: по sv_col и sv_zc — активные столбцы (cl_n; cl_h[j] — столбец экрана, cl_m[j] — смещение маски 16*j)
cols_build:
		ld	hl,cl_h
		ld	de,cl_m
		ld	b,0			; j
		ld	c,0			; число
cb_1:		ld	a,(sv_col)
		add	a,b
		cp	32
		jp	nc,cb_2
		push	af
		ld	a,(sv_zc)		; бит j -> CY
		push	bc
		inc	b
cb_r:		dec	b
		jp	z,cb_t
		rrca
		jp	cb_r
cb_t:		pop	bc
		rrca
		jp	c,cb_e
		pop	af
		ld	(hl),a
		inc	hl
		ld	a,b
		add	a,a
		add	a,a
		add	a,a
		add	a,a
		ld	(de),a
		inc	de
		inc	c
		jp	cb_2
cb_e:		pop	af
cb_2:		inc	b
		ld	a,b
		cp	3
		jp	nz,cb_1
		ld	a,c
		ld	(cl_n),a
		ret

; --- spr_erase: клетки под прежними прямоугольниками спрайтов — к перерисовке (draw_rows сотрёт спрайты) ----
spr_erase:
		ld	a,(spr_n)
		or	a
		ret	z
		ld	c,a
se0:		dec	c
		push	bc
		ld	a,c
		call	rec_ptr
		ld	a,(hl)			; L верхней строки -> строка экрана y = DF - L
		ld	b,a
		ld	a,0xDF
		sub	b
		ld	(se_y),a
		inc	hl
		ld	a,(hl)
		ld	(sv_col),a
		inc	hl
		ld	a,(hl)			; строк
		ld	b,a
		ld	a,(se_y)
		add	a,b
		dec	a			; нижняя строка
		rrca
		rrca
		rrca
		and	0x1F
		ld	(se_r1),a
		ld	a,(se_y)
		rrca
		rrca
		rrca
		and	0x1F
		ld	(se_r0),a
		inc	hl
		inc	hl
		ld	a,(hl)			; пустые столбцы
		ld	(sv_zc),a
		call	cols_build
se1:		ld	a,(se_r0)		; строка клеток
		cp	24
		jp	nc,se3
		ld	hl,cl_h
		ld	a,(cl_n)
		or	a
		jp	z,se3
		ld	b,a
se2:		ld	a,(se_r0)		; HL' = VNT + 32 * строка + столбец
		push	hl
		ld	l,a
		ld	h,0
		add	hl,hl
		add	hl,hl
		add	hl,hl
		add	hl,hl
		add	hl,hl
		ex	(sp),hl
		ld	a,(hl)
		inc	hl
		ex	(sp),hl
		call	add_hl_a
		ld	de,VNT
		add	hl,de
		call	ft_mark1
		pop	hl
		dec	b
		jp	nz,se2
se3:		ld	a,(se_r0)
		ld	b,a
		ld	a,(se_r1)
		cp	b
		jp	z,se4
		jp	c,se4
		ld	a,b
		inc	a
		ld	(se_r0),a
		jp	se1
se4:		pop	bc
		ld	a,c
		or	a
		jp	nz,se0
		xor	a
		ld	(spr_n),a
		ret

; rec_ptr: A = номер -> HL = spr_rec + 8 * A
rec_ptr:	add	a,a
		add	a,a
		add	a,a
		ld	hl,spr_rec
		jp	add_hl_a

; --- spr_draw: все видимые спрайты из VSAT, с последнего ------------------------------------------------
spr_draw:
		ld	hl,VSAT
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
		ld	a,0xFF
		ld	(sp_px),a
		ld	(sp_py),a
		ld	a,b
		or	a
		ret	z
sd2:		dec	b
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
		ld	a,(hl)			; верхняя строка = Y + 1
		inc	a
		cp	192
		ret	nc
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
		and	0x80
		ret	nz
		ld	a,(hl)
		and	0x0F
		ret	z
		ld	hl,cmap
		call	add_hl_a
		ld	a,(hl)
		ld	(sp_ci),a
		ld	a,(sp_y)		; строк: min(16, 192 - Y)
		ld	b,a
		ld	a,192
		sub	b
		cp	16
		jp	c,so0
		ld	a,16
so0:		ld	(st_rows),a
		ld	a,(sp_y)
		ld	b,a
		ld	a,0xDF
		sub	b
		ld	(sv_lo),a
		ld	a,(sp_x)
		rrca
		rrca
		rrca
		and	0x1F
		ld	(sv_col),a
		call	trim_sprite		; Z — пусто
		ret	z
		call	spr_masks
		call	set_entries
		call	cols_build
		ld	a,(spr_n)		; запись
		ld	(sp_k),a
		call	rec_ptr
		ld	a,(sv_lo)
		ld	(hl),a
		inc	hl
		ld	a,(sv_col)
		ld	(hl),a
		inc	hl
		ld	a,(st_rows)
		ld	(hl),a
		inc	hl
		ld	b,1			; сохранять фон, если позиция не та же, что у предыдущего нарисованного
		ld	a,(sp_x)
		ld	c,a
		ld	a,(sp_px)
		cp	c
		jp	nz,so1
		ld	a,(sp_y)
		ld	c,a
		ld	a,(sp_py)
		cp	c
		jp	nz,so1
		ld	b,0
so1:		ld	(hl),b
		inc	hl
		ld	a,(sv_zc)
		ld	(hl),a
		ld	a,(sp_x)
		ld	(sp_px),a
		ld	a,(sp_y)
		ld	(sp_py),a
		ld	hl,spr_n
		inc	(hl)
so2:		ld	a,(cl_n)
		or	a
		ret	z
		ld	a,(sp_ci)		; цвет: бит 2 индекса -> бит 7 (плоскости 80, A0, C0)
		rlca
		rlca
		rlca
		rlca
		rlca
		ld	(sp_cbits),a
		ld	b,0x80
so3:		ld	a,(sp_cbits)
		rlca
		ld	(sp_cbits),a
		sbc	a,a			; FF — OR, 00 — AND
		ld	(st_kind),a
		ld	hl,cl_h
		ld	de,cl_m
		ld	a,(cl_n)
		ld	c,a
so4:		ld	a,(hl)
		inc	hl
		add	a,b
		push	hl
		push	bc
		ld	h,a
		ld	a,(de)
		inc	de
		push	de
		add	a,sm_or&0xFF
		ld	e,a
		ld	d,sm_or/256
		ld	a,(sv_lo)
		ld	l,a
		ld	a,(st_kind)
		or	a
		jp	z,cs_and
cs_or:		call	st_or
		jp	so6
cs_and:		call	st_and
so6:		pop	de
		pop	bc
		pop	hl
		dec	c
		jp	nz,so4
		ld	a,b
		add	a,0x20
		ld	b,a
		cp	0xE0
		jp	nz,so3
		ret

; spr_masks: sm_or[j][line] — строка шаблона, сдвинутая на s = X & 7 (столбцы j = 0..2); sv_zc: бит j — пусто.
; r = циклический сдвиг вправо на s (вход в цепочку RRCA подставлен в CALL), m = FFh >> s:
; столбец 0 = rB & m, 1 = (rB & ~m) | (rC & m), 2 = rC & ~m; при s = 0 — без сдвига, столбец 2 пуст.
spr_masks:
		ld	hl,(sp_name)		; шаблон: VSPR + 8 * имя
		ld	h,0
		add	hl,hl
		add	hl,hl
		add	hl,hl
		ld	de,VSPR
		add	hl,de
		ld	a,(sm_off)
		call	add_hl_a
		ld	a,(st_rows)
		ld	(sp_line),a
		ld	de,sm_or
		ld	a,(sp_x)
		and	7
		jp	z,smz			; s = 0
		ld	b,a			; вход: rot_end - s
		ld	a,rot_end&0xFF
		sub	b
		ld	(smc1+1),a
		ld	(smc2+1),a
		ld	a,rot_end/256
		sbc	a,0
		ld	(smc1+2),a
		ld	(smc2+2),a
		ld	a,0xFF			; m
smm:		or	a
		rra
		dec	b
		jp	nz,smm
		ld	(smk_m0+1),a
		ld	(smk_m1+1),a
		cpl
		ld	(smk_n1+1),a
		ld	(smk_n2+1),a
smk1:		ld	a,(hl)
smc1:		call	rot_end
		ld	c,a			; C = rB
		ld	a,l
		add	a,16
		ld	l,a
		ld	a,(hl)
smc2:		call	rot_end
		ld	b,a			; B = rC
		ld	a,l
		sub	15
		ld	l,a
		ld	a,c
smk_m0:		and	0
		ld	(de),a			; столбец 0
		ld	a,e
		add	a,16
		ld	e,a
		ld	a,c
smk_n1:		and	0
		ld	c,a
		ld	a,b
smk_m1:		and	0
		or	c
		ld	(de),a			; столбец 1
		ld	a,e
		add	a,16
		ld	e,a
		ld	a,b
smk_n2:		and	0
		ld	(de),a			; столбец 2
		ld	a,e
		sub	31
		ld	e,a
		ld	a,(sp_line)
		dec	a
		ld	(sp_line),a
		jp	nz,smk1
		ret
smz:
smz1:		ld	a,(hl)
		ld	(de),a
		ld	a,l
		add	a,16
		ld	l,a
		ld	a,e
		add	a,16
		ld	e,a
		ld	a,(hl)
		ld	(de),a
		ld	a,l
		sub	15
		ld	l,a
		ld	a,e
		sub	15
		ld	e,a
		ld	a,(sp_line)
		dec	a
		ld	(sp_line),a
		jp	nz,smz1
		ret

; цепочка сдвига: вход rot_end - s выполняет s команд RRCA
rot_beg:	REPT	7
		rrca
		ENDR
rot_end:	ret

; --- обрезка по шаблону: spr_trim[имя/4] = (первая строка, последняя, пустые половины: бит 0 — левая, 1 — правая);
; строка пуста, если пусты обе половины; всё пусто — первая = FF. Пересчёт — trim_build (при смене комнаты).
trim_build:
		ld	hl,VSPR
		ld	de,spr_trim
		ld	c,64
tb0:		push	bc
		ld	b,0			; строка
		ld	c,0xFF			; первая
		xor	a
		ld	(tr_last),a
		ld	(tr_z0),a		; ИЛИ левых
		ld	(tr_z2),a		; ИЛИ правых
tb1:		ld	a,(hl)			; левая
		push	hl
		push	af
		ld	a,16
		call	add_hl_a
		ld	a,(hl)			; правая
		ld	h,a
		ld	a,(tr_z2)
		or	h
		ld	(tr_z2),a
		pop	af
		ld	l,a
		ld	a,(tr_z0)
		or	l
		ld	(tr_z0),a
		ld	a,l
		or	h
		pop	hl
		jp	z,tb2
		ld	a,b
		ld	(tr_last),a
		ld	a,c
		cp	0xFF
		jp	nz,tb2
		ld	c,b
tb2:		inc	hl
		inc	b
		ld	a,b
		cp	16
		jp	nz,tb1
		ld	a,c			; запись
		ld	(de),a
		inc	de
		ld	a,(tr_last)
		ld	(de),a
		inc	de
		ld	b,0
		ld	a,(tr_z0)
		or	a
		jp	nz,tb3
		inc	b
tb3:		ld	a,(tr_z2)
		or	a
		jp	nz,tb4
		inc	b
		inc	b
tb4:		ld	a,b
		ld	(de),a
		inc	de
		inc	de
		ld	a,16			; следующий шаблон: +32 (уже +16)
		call	add_hl_a
		pop	bc
		dec	c
		jp	nz,tb0
		ret

; trim_sprite: по spr_trim[имя] — sm_off (первая строка), sv_lo, st_rows (строк — с учётом нижнего края),
; sv_zc (столбец 0 пуст — левая половина пуста; 2 — правая пуста или X кратен 8). Z — спрайт пуст.
trim_sprite:
		ld	a,(sp_name)		; имя кратно 4 -> запись по 4 байта: имя
		ld	l,a
		ld	h,0
		ld	de,spr_trim
		add	hl,de
		ld	a,(hl)			; первая
		cp	0xFF
		ret	z
		ld	(sm_off),a
		ld	b,a
		inc	hl
		ld	a,(hl)			; последняя
		sub	b
		inc	a			; строк по шаблону
		ld	c,a
		ld	a,(st_rows)		; видимых строк от верха спрайта
		sub	b
		jp	c,ts_e
		jp	z,ts_e
		cp	c
		jp	c,ts1
		ld	a,c
ts1:		ld	(st_rows),a
		ld	a,(sv_lo)
		sub	b
		ld	(sv_lo),a
		inc	hl
		ld	a,(hl)			; пустые половины
		ld	b,0
		rrca
		jp	nc,ts2
		inc	b			; левая пуста — столбец 0 пуст
ts2:		rrca
		jp	c,ts3
		ld	a,(sp_x)
		and	7
		jp	nz,ts4
ts3:		ld	a,b			; правая пуста или X кратен 8 — столбец 2 пуст
		or	4
		ld	b,a
ts4:		ld	a,b
		ld	(sv_zc),a
		or	1			; NZ
		ret
ts_e:		xor	a
		ret
