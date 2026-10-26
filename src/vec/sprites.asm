; Программные спрайты 16x16 по таблице атрибутов VSAT (TMS9918: Y, X, имя, цвет | EC) с сохранением фона
; в невидимой плоскости (ячейка SPR_SLOTS + 256 * номер). Кадр: spr_plan (какие перерисовать: изменённые,
; под изменёнными клетками, пересекающие их) -> spr_restore (фон назад, 0..) -> вывод клеток -> spr_draw
; (отмеченные, с последнего: меньший номер сверху). Неизменённые спрайты не трогаются — не мерцают. Спрайт — до 3 столбцов x 3 плоскости вертикальных полос по 16 строк. Маски столбцов
; (sm_or[3][16]) считаются один раз на спрайт; AND-плоскости берут инверсию на лету. Полосы — развёрнутые блоки,
; адреса входа (по числу строк) подставляются в команды CALL (самоизменяемый код). Спрайт с тем же (X, Y), что
; у нарисованного перед ним, фон не сохраняет (слои героя). Y = D0 — конец, цвет 0 — не виден, EC и Y > BF — нет.
SPR_MAX		equ	6
SM_OFS		equ	0xD0			; маски столбцов в ячейке спрайта (фон — до 3 x 3 x 23 = CF)
T0_U		equ	3			; единиц (256 тактов) от прерывания до первой группы
MA_U		equ	3			; запас «до луча»
MB_U		equ	2			; запас «после луча»
DL_N		equ	11			; ожидание: витков на единицу
SV_MAX		equ	23			; строк в области фона (слои героя: 16 + сдвиг до 7)
SREC		equ	16			; запись: нарисован, Y X имя цвет, r0 r1 c0 c1 (клетки), L, столбец, строк,
						; пустые столбцы, метка (+13)

; spr_plan: новые атрибуты (spr_new) и метки перерисовки в spr_rec: спрайт отмечен, если атрибуты не те
; (или spr_force), если под нарисованным изменились клетки (VNT != NTS) и, до замыкания, если его прямоугольник
; пересекает прежний или новый прямоугольник отмеченного. A = число отмеченных.
spr_plan:
		ld	hl,VSAT
		ld	de,spr_new
		ld	b,0			; номер
		ld	c,0			; встречен D0
spl0:		ld	a,c
		or	a
		jp	nz,spl_e
		ld	a,(hl)
		cp	0xD0
		jp	nz,spl1
		ld	c,1
spl_e:		xor	a			; после конца таблицы: невидим, атрибуты D0 0 0 0
		ld	(de),a
		inc	de
		ld	a,0xD0
		ld	(de),a
		inc	de
		xor	a
		ld	(de),a
		inc	de
		ld	(de),a
		inc	de
		ld	(de),a
		inc	de
		inc	de
		inc	de
		inc	de
		inc	de
		jp	spl4
spl1:		push	hl			; виден: Y + 1 < 192, цвет без EC и не 0
		ld	a,(hl)
		inc	a
		cp	192
		jp	nc,spl1n
		inc	hl
		inc	hl
		inc	hl
		ld	a,(hl)
		and	0x80
		jp	nz,spl1n
		ld	a,(hl)
		and	0x0F
		jp	z,spl1n
		ld	a,1
		jp	spl1v
spl1n:		xor	a
spl1v:		pop	hl
		ld	(de),a
		inc	de
		push	hl
		REPT	4
		ld	a,(hl)
		ld	(de),a
		inc	hl
		inc	de
		ENDR
		pop	hl
		push	hl			; прямоугольник клеток: строки y/8 .. (y+15)/8 (до 23), столбцы X/8 .. +1/+2
		ld	a,(hl)
		inc	a
		ld	h,a
		rrca
		rrca
		rrca
		and	0x1F
		ld	(de),a
		inc	de
		ld	a,h
		add	a,15
		rrca
		rrca
		rrca
		and	0x1F
		cp	24
		jp	c,spl2
		ld	a,23
spl2:		ld	(de),a
		inc	de
		pop	hl
		push	hl
		inc	hl
		ld	a,(hl)
		ld	h,a
		rrca
		rrca
		rrca
		and	0x1F
		ld	(de),a
		inc	de
		ld	l,a
		ld	a,h
		and	7
		ld	a,l
		jp	z,spl3
		inc	a
spl3:		inc	a
		cp	32
		jp	c,spl3a
		ld	a,31
spl3a:		ld	(de),a
		inc	de
		pop	hl
spl4:		ld	a,e			; DE — на +9: к следующей записи (+16)
		add	a,7
		ld	e,a
		ld	a,d
		adc	a,0
		ld	d,a
		inc	hl
		inc	hl
		inc	hl
		inc	hl
		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,spl0
; метки: атрибуты не те или spr_force
		ld	b,0
spm0:		ld	a,b
		call	new_ptr
		ex	de,hl
		ld	a,b
		call	rec_ptr
		push	hl
		inc	hl
		inc	de
		ld	a,(spr_force)
		ld	c,a
		REPT	4
		ld	a,(de)
		xor	(hl)
		or	c
		ld	c,a
		inc	hl
		inc	de
		ENDR
		pop	hl
		ld	de,13
		add	hl,de
		ld	a,c
		or	a
		jp	z,spm1
		ld	a,1
spm1:		ld	(hl),a
		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,spm0
		xor	a
		ld	(spr_force),a
; под нарисованным неотмеченным изменились клетки — отметить
		ld	b,0
spd0:		ld	a,b
		call	rec_ptr
		ld	a,(hl)			; нарисован?
		or	a
		jp	z,spd9
		push	hl
		ld	de,13
		add	hl,de
		ld	a,(hl)
		pop	hl
		or	a
		jp	nz,spd9
		push	hl
		inc	hl			; +5: r0 r1 c0 c1
		inc	hl
		inc	hl
		inc	hl
		inc	hl
		ld	a,(hl)
		ld	(se_r0),a
		inc	hl
		ld	a,(hl)
		ld	(se_r1),a
		inc	hl
		ld	a,(hl)
		ld	(se_y),a		; c0
		inc	hl
		ld	c,(hl)			; c1
		pop	hl
spd1:		ld	a,(se_r0)		; строка: L = (r & 7) * 32 + c, H = база + r / 8
		push	hl
		ld	d,a
		rrca
		rrca
		rrca
		and	0x1F
		ld	e,a			; r / 8
		ld	a,d
		rrca
		rrca
		rrca
		and	0xE0
		ld	d,a			; (r & 7) * 32
		ld	a,(se_y)
spd2:		push	af
		add	a,d
		ld	l,a
		ld	a,e
		add	a,VNT/256
		ld	h,a
		ld	a,e
		add	a,NTS/256
		push	bc
		ld	b,a
		ld	a,(hl)
		ld	h,b
		pop	bc
		cp	(hl)
		jp	nz,spd_m
		pop	af
		inc	a
		cp	c
		jp	z,spd2
		jp	c,spd2
		pop	hl
		ld	a,(se_r0)
		inc	a
		ld	(se_r0),a
		ld	d,a
		ld	a,(se_r1)
		cp	d
		jp	nc,spd1
		jp	spd9
spd_m:		pop	af
		pop	hl
		ld	de,13
		add	hl,de
		ld	(hl),1
spd9:		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,spd0
; замыкание: неотмеченный нарисованный, пересекающий прямоугольник отмеченного (прежний или новый)
spx0:		xor	a
		ld	(spx_ch),a
		ld	b,0
spx1:		ld	a,b
		call	rec_ptr
		ld	a,(hl)
		or	a
		jp	z,spx8
		push	hl
		ld	de,13
		add	hl,de
		ld	a,(hl)
		pop	hl
		or	a
		jp	nz,spx8
		ld	de,5
		add	hl,de
		ld	(spx_a),hl		; прямоугольник k
		ld	c,0			; j
spx2:		ld	a,c
		call	rec_ptr
		push	hl
		ld	de,13
		add	hl,de
		ld	a,(hl)
		pop	hl
		or	a
		jp	z,spx7
		ld	a,(hl)			; прежний (если был нарисован)
		or	a
		jp	z,spx3
		ld	de,5
		add	hl,de
		ex	de,hl
		ld	hl,(spx_a)
		call	isect
		jp	c,spx_m
spx3:		ld	a,c
		call	new_ptr
		ld	a,(hl)			; новый (если виден)
		or	a
		jp	z,spx7
		ld	de,5
		add	hl,de
		ex	de,hl
		ld	hl,(spx_a)
		call	isect
		jp	c,spx_m
spx7:		inc	c
		ld	a,c
		cp	SPR_MAX
		jp	nz,spx2
		jp	spx8
spx_m:		ld	hl,(spx_a)		; отметить k (+13 = +5 + 8)
		ld	de,8
		add	hl,de
		ld	(hl),1
		ld	a,1
		ld	(spx_ch),a
spx8:		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,spx1
		ld	a,(spx_ch)
		or	a
		jp	nz,spx0
		ld	b,0			; A = число отмеченных
		ld	c,0
spn0:		ld	a,b
		call	rec_ptr
		ld	de,13
		add	hl,de
		ld	a,(hl)
		add	a,c
		ld	c,a
		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,spn0
		ld	a,c
		or	a
		ret

; isect: HL, DE -> прямоугольники (r0, r1, c0, c1); CY — пересекаются (HL, DE, BC сохраняются)
isect:		push	bc
		push	hl
		push	de
		inc	de
		ld	a,(de)			; B.r1 < A.r0 — нет
		cp	(hl)
		jp	c,isn
		inc	hl
		dec	de
		ld	a,(de)			; A.r1 < B.r0 — нет
		ld	b,a
		ld	a,(hl)
		cp	b
		jp	c,isn
		inc	hl
		inc	de
		inc	de
		inc	de
		ld	a,(de)			; B.c1 < A.c0 — нет
		cp	(hl)
		jp	c,isn
		inc	hl
		dec	de
		ld	a,(de)			; A.c1 < B.c0 — нет
		ld	b,a
		ld	a,(hl)
		cp	b
		jp	c,isn
		pop	de
		pop	hl
		pop	bc
		scf
		ret
isn:		pop	de
		pop	hl
		pop	bc
		or	a
		ret

; rec_ptr / new_ptr: A = номер -> HL = запись (16 байт)
rec_ptr:	add	a,a			; spr_rec — с начала страницы, spr_new — с её середины (+80h)
		add	a,a
		add	a,a
		add	a,a
		ld	l,a
		ld	h,spr_rec/256
		ret
new_ptr:	add	a,a
		add	a,a
		add	a,a
		add	a,a
		or	0x80
		ld	l,a
		ld	h,spr_rec/256
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

st_sv:		REPT	SV_MAX			; фон в ячейку
		ld	a,(hl)
		ld	(de),a
		inc	e
		dec	l
		ENDR
		ret
st_rs:		REPT	SV_MAX			; фон из ячейки
		ld	a,(de)
		ld	(hl),a
		inc	e
		dec	l
		ENDR
		ret

; set_entries: по st_rows — адреса входа в блоки в командах CALL (cs_or, cs_and, cs_sv, cs_rs)
set_entries:
		ld	a,(st_rows)
		ld	b,a
		add	a,a
		add	a,a			; 4 * строк
		ld	c,a
		ld	hl,st_sv+SV_MAX*4
		call	sub_hl_c
		ld	(cs_sv+1),hl
		ld	hl,st_rs+SV_MAX*4
		call	sub_hl_c
		ld	(cs_rs+1),hl
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

; --- spr_restore: фон под нарисованными отмеченными спрайтами — назад (в порядке, обратном рисованию: 0..) ----
; restore1: B = номер — если нарисован и отмечен: фон назад, «не нарисован» (BC сохраняется)
restore1:	ld	a,b
		call	rec_ptr
		ld	a,(hl)
		or	a
		ret	z
		ld	a,l
		add	a,13
		ld	e,a
		ld	d,h
		ld	a,(de)			; отмечен?
		or	a
		ret	z
		ld	(hl),0			; больше не нарисован
		inc	de
		ld	a,(de)			; фон сохранял он сам?
		or	a
		ret	z
		cp	2			; одной плоскостью — клетки под прежним местом заново
		jp	nz,rs_b
		ld	a,l
		add	a,5
		ld	l,a
		ld	a,1
		ld	(cr_force),a
		push	bc
		call	cells_rect
		pop	bc
		xor	a
		ld	(cr_force),a
		ret
rs_b:
		ld	a,l
		add	a,9
		ld	l,a
		ld	a,(hl)
		ld	(sv_lo),a
		push	bc
		ld	a,b			; rst[k]: столбцов, 3 столбца экрана, вход в st_rs
		ld	c,a
		add	a,a
		add	a,c
		add	a,a			; 6 * k
		ld	hl,rst
		call	add_hl_a
		ld	c,(hl)
		inc	hl
		ld	(rs_h),hl
		inc	hl
		inc	hl
		inc	hl
		ld	a,(hl)
		ld	(cs_rs+1),a
		inc	hl
		ld	a,(hl)
		ld	(cs_rs+2),a
		ld	a,b
		add	a,SPR_SLOTS/256
		ld	d,a
		ld	e,0
		ld	a,c
		ld	(rs_n),a
		ld	b,0x80
sr1:		ld	hl,(rs_h)
		ld	a,(rs_n)
		ld	c,a
sr2:		ld	a,(hl)
		inc	hl
		add	a,b
		push	hl
		ld	h,a
		ld	a,(sv_lo)
		ld	l,a
cs_rs:		call	st_rs
		pop	hl
		dec	c
		jp	nz,sr2
		ld	a,b
		add	a,0x20
		ld	b,a
		cp	0xE0
		jp	nz,sr1
		pop	bc
		ret

; --- spr_prep: для отмеченных видимых — обрезка, маски (в ячейку +C0), место; в spr_new: +9 L, +10 столбец,
; +11 строк, +12 пустые столбцы, +13 цвет (индекс), +14 рисовать. Всё долгое — до ожидания кадра.
spr_prep:
		ld	b,0
pp0:		ld	a,b
		ld	(sp_k),a
		call	rec_ptr
		ld	de,13
		add	hl,de
		ld	a,(hl)
		or	a
		jp	z,pp9
		ld	a,b
		call	new_ptr
		push	hl
		ld	de,14
		add	hl,de
		ld	(hl),0
		pop	hl
		ld	a,(hl)			; виден?
		or	a
		jp	z,pp9
		inc	hl
		push	bc
		call	spr_one
		pop	bc
pp9:		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,pp0
; области фона: своя (new +9..+12); слой k над k+1 в той же точке (оба готовы) — k без фона (+15 = 1),
; у k+1 — объединение: верх = max L, низ = min (L - строк + 1), пустые столбцы — общие
		ld	b,0
pm0:		ld	a,b
		call	new_ptr
		push	hl
		inc	hl			; +4: цвет
		inc	hl
		inc	hl
		inc	hl
		ld	a,(hl)
		and	0x0F
		ld	c,a
		ld	a,(spr_E)
		cp	c
		ld	c,0
		jp	nz,pm0a
		ld	c,2			; враг цвета палитры 4 — одной плоскостью (8000), без фона
pm0a:		ld	a,l
		add	a,11
		ld	l,a
		ld	(hl),c
		pop	hl
		ld	a,l
		add	a,9
		ld	l,a
		ex	de,hl
		ld	a,b
		add	a,a
		add	a,a
		ld	hl,svr
		call	add_hl_a
		REPT	4
		ld	a,(de)
		ld	(hl),a
		inc	de
		inc	hl
		ENDR
		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,pm0
		ld	b,0
pm1:		ld	a,b			; оба готовы и не одной плоскостью?
		call	new_ptr
		ld	a,l
		add	a,14
		ld	l,a
		ld	a,(hl)
		or	a
		jp	z,pm8
		inc	hl
		ld	a,(hl)
		or	a
		jp	nz,pm8
		ld	a,l
		add	a,15
		ld	l,a
		ld	a,(hl)
		or	a
		jp	z,pm8
		inc	hl
		ld	a,(hl)
		or	a
		jp	nz,pm8
		ld	a,b			; X тот же, |dY| <= 7?
		call	new_ptr
		inc	hl
		ld	d,h
		ld	a,l
		add	a,16
		ld	e,a
		inc	hl
		inc	de
		ld	a,(de)
		cp	(hl)
		jp	nz,pm8
		dec	hl
		dec	de
		ld	a,(de)
		sub	(hl)
		jp	nc,pm1a
		cpl
		inc	a
pm1a:		cp	8
		jp	nc,pm8
		ld	a,b			; k — слой
		call	new_ptr
		ld	a,l
		add	a,15
		ld	l,a
		ld	(hl),1
		ld	a,b			; svr[k+1] := объединение svr[k] и svr[k+1]
		add	a,a
		add	a,a
		ld	hl,svr
		call	add_hl_a
		ld	d,h
		ld	e,l			; DE = svr[k]
		ld	a,4
		call	add_hl_a		; HL = svr[k+1]
		ld	a,(de)			; низ k: L - строк + 1
		inc	de
		inc	de
		ld	c,a
		ld	a,(de)
		dec	de
		dec	de
		push	bc
		ld	b,a
		ld	a,c
		sub	b
		inc	a
		ld	(pm_bot),a
		inc	hl
		inc	hl
		ld	b,(hl)
		dec	hl
		dec	hl
		ld	a,(hl)
		sub	b
		inc	a			; низ k+1
		ld	b,a
		ld	a,(pm_bot)
		cp	b
		jp	c,pm2
		ld	a,b
pm2:		ld	(pm_bot),a		; общий низ
		ld	a,(de)
		cp	(hl)
		jp	c,pm3
		ld	(hl),a			; общий верх
pm3:		ld	a,(pm_bot)
		ld	b,a
		ld	a,(hl)
		sub	b
		inc	a
		inc	hl
		inc	hl
		ld	(hl),a			; строк
		inc	hl
		inc	de
		inc	de
		inc	de
		ld	a,(de)
		and	(hl)
		ld	(hl),a			; пустые столбцы — общие
		pop	bc
pm8:		inc	b
		ld	a,b
		cp	SPR_MAX-1
		jp	nz,pm1
		jp	spr_ready

; spr_one: HL -> атрибуты спрайта sp_k (spr_new + 1): обрезка, маски, место -> spr_new +9..+14
spr_one:
		ld	a,(hl)			; верхняя строка = Y + 1
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
		and	0x0F
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
		ld	a,(sp_k)
		call	new_ptr
		ld	de,9
		add	hl,de
		ld	a,(sv_lo)
		ld	(hl),a
		inc	hl
		ld	a,(sv_col)
		ld	(hl),a
		inc	hl
		ld	a,(st_rows)
		ld	(hl),a
		inc	hl
		ld	a,(sv_zc)
		ld	(hl),a
		inc	hl
		ld	a,(sp_ci)
		ld	(hl),a
		inc	hl
		ld	(hl),1
		ret

; --- spr_draw: отмеченные, с последнего (меньший номер сверху): запись := новые атрибуты; подготовленные —
; фон в ячейку и спрайт в экран (spr_put)
; draw1: B = номер — если отмечен: запись := новые атрибуты, подготовленный — в экран (BC сохраняется)
draw1:		push	bc
		ld	a,b
		ld	(sp_k),a
		call	new_ptr
		ex	de,hl			; DE = новая запись
		ld	a,b
		call	rec_ptr
		push	hl
		ld	bc,13
		add	hl,bc
		ld	a,(hl)
		ld	(hl),0			; метка снята
		pop	hl
		or	a
		jp	z,sd8
		ld	(hl),0			; не нарисован
		inc	hl
		inc	de
		ld	b,8			; атрибуты и прямоугольник
sd3:		ld	a,(de)
		ld	(hl),a
		inc	hl
		inc	de
		dec	b
		jp	nz,sd3
		ex	de,hl			; HL = новая +9
		ld	a,l
		add	a,5
		ld	l,a
		ld	a,(hl)			; подготовлен?
		or	a
		call	nz,spr_put
sd8:		pop	bc
		ret

; spr_put: спрайт sp_k по заготовкам (spr_ready). Не слой (new +15 = 0): фон области svr[k] — в ячейку,
; запись := нарисован с фоном, rst[k] — для восстановления; слой (+15 = 1) — только рисование поверх.
spr_put:
		ld	a,(sp_k)
		ld	b,a
		add	a,SPR_SLOTS/256
		ld	(sp_mpage),a
		ld	a,b
		call	new_ptr
		ld	a,l
		add	a,15
		ld	l,a
		ld	c,(hl)			; слой?
		ld	a,b
		call	rec_ptr
		ld	(hl),1			; нарисован
		ld	a,l
		add	a,14
		ld	l,a
		ld	a,c
		ld	(sp_sp),a
		or	a
		jp	z,pu_n
		cp	1
		ld	a,0			; +14: 0 — слой (без фона), 2 — одной плоскостью
		jp	z,pu_l
		ld	a,2
pu_l:		ld	(hl),a
		jp	spr_paint
pu_n:		ld	(hl),1			; +14: 1 — с фоном
		ld	a,l			; запись +9..+12 := svr[k]
		sub	5
		ld	l,a
		push	hl
		ld	a,b
		add	a,a
		add	a,a
		ld	hl,svr
		call	add_hl_a
		ex	de,hl
		pop	hl
		ld	a,(de)
		ld	(pu_lo),a
		REPT	4
		ld	a,(de)
		ld	(hl),a
		inc	de
		inc	hl
		ENDR
		ld	a,b			; pps[k] -> rst[k] (6 байт), вход в st_sv
		ld	c,a
		add	a,a
		add	a,c
		add	a,a
		ld	c,a
		ld	hl,pps
		call	add_hl_a
		push	hl
		ld	a,c
		ld	hl,rst
		call	add_hl_a
		pop	de
		push	de
		REPT	6
		ld	a,(de)
		ld	(hl),a
		inc	de
		inc	hl
		ENDR
		ld	a,b			; вход в st_sv — pps2[k]
		add	a,a
		ld	hl,pps2
		call	add_hl_a
		ld	a,(hl)
		ld	(cs_sv+1),a
		inc	hl
		ld	a,(hl)
		ld	(cs_sv+2),a
		pop	hl
		ld	a,(hl)			; столбцов
		or	a
		jp	z,spr_paint
		ld	(rs_n),a
		inc	hl
		ld	(rs_h),hl
		ld	a,(sp_mpage)
		ld	d,a
		ld	e,0
		ld	b,0x80
pu1:		ld	hl,(rs_h)
		ld	a,(rs_n)
		ld	c,a
pu2:		ld	a,(hl)
		inc	hl
		add	a,b
		push	hl
		ld	h,a
		ld	a,(pu_lo)
		ld	l,a
cs_sv:		call	st_sv
		pop	hl
		dec	c
		jp	nz,pu2
		ld	a,b
		add	a,0x20
		ld	b,a
		cp	0xE0
		jp	nz,pu1
; spr_paint: по ppd[sp_k] (столбцы, маски, входы) и sv_lo/sp_ci из spr_new — спрайт в экран
spr_paint:
		ld	a,(sp_k)
		call	new_ptr
		ld	a,l
		add	a,9
		ld	l,a
		ld	a,(hl)
		ld	(sv_lo),a
		ld	a,l
		add	a,4
		ld	l,a
		ld	a,(hl)			; цвет: бит 2 индекса -> бит 7 (плоскости 80, A0, C0)
		rlca
		rlca
		rlca
		rlca
		rlca
		ld	(sp_cbits),a
		ld	a,(sp_k)		; ppd[k]: столбцов, cl_h[3], cl_m[3], вход OR, вход AND (11 байт)
		ld	b,a
		add	a,a
		add	a,a
		add	a,a
		add	a,b
		add	a,b
		add	a,b			; 11 * k
		ld	hl,ppd
		call	add_hl_a
		ld	a,(hl)
		or	a
		ret	z
		ld	(cl_n),a
		inc	hl
		ld	(pp_h),hl
		ld	a,l
		add	a,3
		ld	l,a
		ld	a,h
		adc	a,0
		ld	h,a
		ld	(pp_m),hl
		inc	hl
		inc	hl
		inc	hl
		ld	a,(hl)
		ld	(cs_or+1),a
		inc	hl
		ld	a,(hl)
		ld	(cs_or+2),a
		inc	hl
		ld	a,(hl)
		ld	(cs_and+1),a
		inc	hl
		ld	a,(hl)
		ld	(cs_and+2),a
		ld	b,0x80
so3:		ld	a,(sp_sp)		; одной плоскостью: только 8000, OR
		cp	2
		ld	a,0xFF
		jp	z,so3k
		ld	a,(sp_cbits)
		rlca
		ld	(sp_cbits),a
		sbc	a,a			; FF — OR, 00 — AND
so3k:		ld	(st_kind),a
		ld	hl,(pp_m)
		ex	de,hl
		ld	hl,(pp_h)
		ld	a,(cl_n)
		ld	c,a
so4:		ld	a,(hl)
		inc	hl
		add	a,b
		push	hl
		push	bc
		ld	h,a
		ld	a,(sv_lo)
		ld	l,a
		ld	a,(de)
		inc	de
		push	de
		add	a,SM_OFS		; маска: ячейка + D0 + 16 * столбец
		ld	e,a
		ld	a,(sp_mpage)
		ld	d,a
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
		ld	a,(sp_sp)
		cp	2
		ret	z
		ld	a,b
		add	a,0x20
		ld	b,a
		cp	0xE0
		jp	nz,so3
		ret

; spr_ready: для подготовленных (new +14) — заготовки: pps[k] (область фона svr[k]: столбцов, 3 столбца,
; вход st_rs), pps2[k] (вход st_sv), ppd[k] (рисование: столбцов, cl_h, cl_m, входы st_or, st_and)
spr_ready:
		ld	b,0
sy0:		ld	a,b
		call	new_ptr
		ld	a,l
		add	a,14
		ld	l,a
		ld	a,(hl)
		or	a
		jp	z,sy9
		push	bc
		ld	a,b			; область фона
		add	a,a
		add	a,a
		ld	hl,svr
		call	add_hl_a
		call	sy_load
		call	set_entries
		call	cols_build
		pop	bc
		push	bc
		ld	a,b
		ld	c,a
		add	a,a
		add	a,c
		add	a,a
		ld	hl,pps
		call	add_hl_a
		ld	a,(cl_n)
		ld	(hl),a
		inc	hl
		ld	de,cl_h
		REPT	3
		ld	a,(de)
		ld	(hl),a
		inc	de
		inc	hl
		ENDR
		ld	a,(cs_rs+1)
		ld	(hl),a
		inc	hl
		ld	a,(cs_rs+2)
		ld	(hl),a
		pop	bc
		push	bc
		ld	a,b
		add	a,a
		ld	hl,pps2
		call	add_hl_a
		ld	a,(cs_sv+1)
		ld	(hl),a
		inc	hl
		ld	a,(cs_sv+2)
		ld	(hl),a
		pop	bc
		push	bc
		ld	a,b			; рисование: свои параметры (new +9..+12)
		call	new_ptr
		ld	a,l
		add	a,9
		ld	l,a
		call	sy_load
		call	set_entries
		call	cols_build
		pop	bc
		push	bc
		ld	a,b
		add	a,a
		add	a,a
		add	a,a
		add	a,b
		add	a,b
		add	a,b
		ld	hl,ppd
		call	add_hl_a
		ld	a,(cl_n)
		ld	(hl),a
		inc	hl
		ld	de,cl_h
		REPT	6			; cl_h[3], cl_m[3] (подряд)
		ld	a,(de)
		ld	(hl),a
		inc	de
		inc	hl
		ENDR
		ld	a,(cs_or+1)
		ld	(hl),a
		inc	hl
		ld	a,(cs_or+2)
		ld	(hl),a
		inc	hl
		ld	a,(cs_and+1)
		ld	(hl),a
		inc	hl
		ld	a,(cs_and+2)
		ld	(hl),a
		pop	bc
sy9:		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,sy0
		ret
; sy_load: HL -> L, столбец, строк, пустые столбцы -> sv_lo, sv_col, st_rows, sv_zc
sy_load:	ld	a,(hl)
		ld	(sv_lo),a
		inc	hl
		ld	a,(hl)
		ld	(sv_col),a
		inc	hl
		ld	a,(hl)
		ld	(st_rows),a
		inc	hl
		ld	a,(hl)
		ld	(sv_zc),a
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
		ld	a,(sp_k)		; маски — в ячейку спрайта (+C0)
		add	a,SPR_SLOTS/256
		ld	d,a
		ld	e,SM_OFS
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

; --- crit_plan: до ожидания кадра — группы пересекающихся отмеченных спрайтов сверху вниз -> список действий
; cr_list: пары (действие, номер): 1 — фон назад, 2 — клетки под прежним местом, 3 — спрайт; конец 0.
; Группа: фон всех назад (0..), клетки под прежними местами, спрайты (с последнего).
crit_plan:
		ld	hl,cr_list
		ld	(cr_ptr),hl
		ld	b,0			; grp[k] := k для отмеченных, иначе FF
cg0:		ld	a,b
		call	rec_ptr
		ld	de,13
		add	hl,de
		ld	a,(hl)
		or	a
		ld	a,0xFF
		jp	z,cgx1
		ld	a,b
cgx1:		ld	hl,grp
		ld	c,a
		ld	a,b
		call	add_hl_a
		ld	(hl),c
		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,cg0
cu0:		xor	a			; объединение пересекающихся (прежние и новые места)
		ld	(spx_ch),a
		ld	b,0
cu1:		ld	a,b
		call	grp_of
		cp	SPR_MAX
		jp	nc,cu8
		ld	c,b
cu2:		inc	c
		ld	a,c
		cp	SPR_MAX
		jp	nc,cu8
		call	grp_of
		cp	SPR_MAX
		jp	nc,cu2
		ld	d,a			; grp[j]
		ld	a,b
		call	grp_of
		cp	d
		jp	z,cu2
		call	overl			; B, C пересекаются?
		jp	nc,cu2
		ld	a,b			; все с grp = grp[j] -> grp[i]
		call	grp_of
		ld	e,a
		ld	hl,grp
		push	bc
		ld	b,SPR_MAX
cu3:		ld	a,(hl)
		cp	d
		jp	nz,cu4
		ld	(hl),e
cu4:		inc	hl
		dec	b
		jp	nz,cu3
		pop	bc
		ld	a,1
		ld	(spx_ch),a
		jp	cu2
cu8:		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,cu1
		ld	a,(spx_ch)
		or	a
		jp	nz,cu0
		call	grp_cost		; строки и длительность групп (единица — 256 тактов)
		ld	a,T0_U
		ld	(t_now),a
gp0:		ld	a,0xFF			; A: успевает до луча (t + d + запас <= s) — самая верхняя
		ld	(gp_y),a
		ld	(gp_g),a
		ld	b,0
gp1:		call	g_get			; H: s, L: e, D: d; Z — группы нет
		jp	z,gp3
		ld	a,(t_now)
		add	a,d
		jp	c,gp3
		add	a,MA_U
		jp	c,gp3
		cp	h
		jp	z,gp1a
		jp	nc,gp3
gp1a:		ld	a,h
		ld	hl,gp_y
		cp	(hl)
		jp	nc,gp3
		ld	(hl),a
		ld	a,b
		ld	(gp_g),a
gp3:		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,gp1
		ld	a,(gp_g)
		cp	0xFF
		jp	nz,gp_go
		ld	b,0			; B: луч уже прошёл (e + запас <= t) — первая такая
gp2:		call	g_get
		jp	z,gp2n
		ld	a,l
		add	a,MB_U
		ld	c,a
		ld	a,(t_now)
		cp	c
		jp	nc,gp2y
gp2n:		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,gp2
		ld	a,0xFF			; C: ждать, пока луч пройдёт группу с наименьшим e
		ld	(gp_y),a
		ld	b,0
gp5a:		call	g_get
		jp	z,gp5b
		ld	a,l
		ld	hl,gp_y
		cp	(hl)
		jp	nc,gp5b
		ld	(hl),a
		ld	a,b
		ld	(gp_g),a
gp5b:		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,gp5a
		ld	a,(gp_g)
		cp	0xFF
		jp	z,cr_end		; групп больше нет
		ld	a,(gp_y)		; ожидание (e + запас - t) единиц: действие 4
		add	a,MB_U
		ld	c,a
		ld	a,(t_now)
		ld	b,a
		ld	a,c
		sub	b
		jp	c,gp_go
		jp	z,gp_go
		ld	b,a
		ld	a,c
		ld	(t_now),a
		ld	a,4
		call	cr_add
		jp	gp_go
gp2y:		ld	a,b
		ld	(gp_g),a
gp_go:		ld	a,(gp_g)		; t += d группы
		ld	b,a
		call	g_get
		ld	a,(t_now)
		add	a,d
		jp	nc,gp_t
		ld	a,0xFF
gp_t:		ld	(t_now),a
		ld	hl,gact
		ld	a,(gp_g)
		call	add_hl_a
		ld	(hl),0
		ld	a,(gp_g)
		ld	d,a
		ld	b,0			; было нарисовано -> wd[k]; фон назад
gp4:		ld	a,b
		call	grp_of
		cp	d
		jp	nz,gp5
		ld	a,b
		call	rec_ptr
		ld	a,(hl)
		push	af
		ld	hl,wd
		ld	a,b
		call	add_hl_a
		pop	af
		ld	(hl),a
		ld	a,1
		call	cr_add
gp5:		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,gp4
		ld	b,0			; клетки под прежними местами
gp6:		ld	a,b
		call	grp_of
		cp	d
		jp	nz,gp7
		ld	hl,wd
		ld	a,b
		call	add_hl_a
		ld	a,(hl)
		or	a
		jp	z,gp7
		ld	a,2
		call	cr_add
gp7:		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,gp6
		ld	b,SPR_MAX		; спрайты, с последнего; группа обработана (FE)
gp8:		dec	b
		ld	a,b
		call	grp_of
		cp	d
		jp	nz,gp9
		ld	(hl),0xFE
		ld	a,3
		call	cr_add
gp9:		ld	a,b
		or	a
		jp	nz,gp8
		jp	gp0

; g_get: B = группа -> H = s, L = e, D = d; Z — группы нет (BC, E сохраняются)
g_get:		ld	hl,gact
		ld	a,b
		call	add_hl_a
		ld	a,(hl)
		or	a
		ret	z
		ld	a,SPR_MAX		; gact, gs, ge, gd — подряд по SPR_MAX
		call	add_hl_a
		ld	a,(hl)
		push	af
		ld	a,SPR_MAX
		call	add_hl_a
		ld	l,(hl)
		pop	af
		push	hl
		ld	h,a
		push	hl
		ld	hl,gd
		ld	a,b
		call	add_hl_a
		ld	d,(hl)
		pop	hl
		pop	af
		or	1			; NZ
		ret

; grp_cost: для групп (grp[k] < SPR_MAX) — gact, gs (верхняя строка, единицы), ge (нижняя), gd (длительность):
; прежнее место (нарисован с фоном): строки, восстановление B/8 + 2; новое (подготовлен): строки области
; фона/своих, сохранение B/8 + B/64 (не слой), рисование B/8 + B/64 + 5; клетки откладывались — +3
grp_cost:
		ld	hl,gact
		ld	b,4*SPR_MAX
		xor	a
gc0:		ld	(hl),a
		inc	hl
		dec	b
		jp	nz,gc0
		ld	hl,gs
		ld	b,SPR_MAX
		ld	a,0xFF
gc1:		ld	(hl),a
		inc	hl
		dec	b
		jp	nz,gc1
		ld	b,0
gc2:		ld	a,b
		call	grp_of
		cp	SPR_MAX
		jp	nc,gc9
		ld	(gc_g),a
		ld	hl,gact
		call	add_hl_a
		ld	(hl),1
		ld	a,(ex_any)
		or	a
		ld	a,3
		call	nz,gc_add
		ld	a,b			; прежнее место
		call	rec_ptr
		ld	a,(hl)
		or	a
		jp	z,gc5
		ld	a,l
		add	a,14
		ld	e,a
		ld	d,h
		ld	a,(de)
		or	a
		jp	z,gc5
		cp	2
		jp	z,gc_sp
		ld	a,l
		add	a,9
		ld	l,a
		ld	c,(hl)			; L
		inc	hl
		inc	hl
		ld	a,(hl)			; строк
		push	af
		call	gc_ext			; C = L, A = строк
		pop	af
		ld	c,a
		push	bc
		ld	a,b			; столбцов: rst[k]
		ld	e,a
		add	a,a
		add	a,e
		add	a,a
		ld	hl,rst
		call	add_hl_a
		ld	a,(hl)
		pop	bc
		call	mul3			; A = 3 * A * C
		call	div8
		add	a,2
		call	gc_add
		jp	gc5
gc_sp:		ld	a,l			; одной плоскостью: стирание — клетки прямоугольника r0 r1 c0 c1
		add	a,5
		ld	l,a
		ld	a,(hl)			; r0 -> L = DF - 8 r0
		push	af
		add	a,a
		add	a,a
		add	a,a
		ld	c,a
		ld	a,0xDF
		sub	c
		ld	c,a
		inc	hl
		pop	af
		ld	d,a
		ld	a,(hl)			; r1 - r0 + 1 строк клеток
		sub	d
		inc	a
		ld	d,a
		inc	hl
		ld	e,(hl)
		inc	hl
		ld	a,(hl)			; c1 - c0 + 1 столбцов
		sub	e
		inc	a
		ld	e,a
		push	de
		ld	a,d			; строк точек = 8 * клеток
		add	a,a
		add	a,a
		add	a,a
		call	gc_ext
		pop	de
		xor	a			; клеток = D * E; 3 единицы на клетку + 2
ggs1:		add	a,e
		dec	d
		jp	nz,ggs1
		ld	c,a
		add	a,a
		add	a,c
		add	a,2
		call	gc_add
gc5:		ld	a,b			; новое место
		call	new_ptr
		ld	a,l
		add	a,14
		ld	l,a
		ld	a,(hl)
		or	a
		jp	z,gc9
		inc	hl
		ld	a,(hl)			; слой?
		or	a
		jp	nz,gc6
		ld	a,b			; область фона svr[k]
		add	a,a
		add	a,a
		ld	hl,svr
		call	add_hl_a
		ld	c,(hl)
		inc	hl
		inc	hl
		ld	a,(hl)
		push	af
		call	gc_ext
		pop	af
		ld	c,a
		push	bc
		ld	a,b			; столбцов: pps[k]
		ld	e,a
		add	a,a
		add	a,e
		add	a,a
		ld	hl,pps
		call	add_hl_a
		ld	a,(hl)
		pop	bc
		call	mul3
		call	div8b
		call	gc_add
gc6:		ld	a,b			; рисование: свои строки, ppd[k]
		call	new_ptr
		ld	a,l
		add	a,9
		ld	l,a
		ld	c,(hl)
		inc	hl
		inc	hl
		ld	a,(hl)
		push	af
		call	gc_ext
		pop	af
		ld	c,a
		push	bc
		ld	a,b
		ld	e,a
		add	a,a
		add	a,a
		add	a,a
		add	a,e
		add	a,e
		add	a,e
		ld	hl,ppd
		call	add_hl_a
		ld	a,(hl)
		pop	bc
		call	mul3
		call	div8b
		add	a,5
		call	gc_add
gc9:		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,gc2
		ld	hl,gd			; накладные расходы полос: d := d + d / 2 (по замерам)
		ld	b,SPR_MAX
gcs:		ld	a,(hl)
		or	a
		rra
		add	a,(hl)
		jp	nc,gcs1
		ld	a,0xFF
gcs1:		ld	(hl),a
		inc	hl
		dec	b
		jp	nz,gcs
		ret
; gc_add: gd[gc_g] += A (BC сохраняются)
gc_add:		push	hl
		ld	hl,gc_g
		ld	e,(hl)
		ld	hl,gd
		push	af
		ld	a,e
		call	add_hl_a
		pop	af
		add	a,(hl)
		jp	nc,gca1
		ld	a,0xFF
gca1:		ld	(hl),a
		pop	hl
		ret
; gc_ext: C = L верхней строки, A = строк -> gs[gc_g] := min(s), ge[gc_g] := max(e) (B сохраняется)
gc_ext:		push	bc
		ld	e,a
		ld	a,c
		sub	e
		inc	a			; L нижней
		push	af
		ld	a,c
		call	l2u
		ld	(gc_s),a		; s
		pop	af
		call	l2u
		inc	a
		ld	e,a			; e
		ld	a,(gc_s)
		ld	d,a
		ld	hl,gc_g
		ld	a,(hl)
		ld	hl,gs
		call	add_hl_a
		ld	a,d
		cp	(hl)
		jp	nc,gce1
		ld	(hl),a
gce1:		ld	a,SPR_MAX
		call	add_hl_a
		ld	a,e
		cp	(hl)
		jp	c,gce2
		ld	(hl),a
gce2:		pop	bc
		ret
; l2u: A = L строки экрана -> единицы от прерывания: ((295 - L) * 3) / 4 (строка луча = 40 + FF - L)
l2u:		ld	c,a
		ld	hl,0x127
		ld	a,l
		sub	c
		ld	l,a
		ld	a,h
		sbc	a,0
		ld	h,a
		ld	d,h
		ld	e,l
		add	hl,hl
		add	hl,de
		ld	a,l
		rrca
		rrca
		and	0x3F
		ld	l,a
		ld	a,h
		rrca
		rrca
		and	0xC0
		or	l
		ret
; mul3: A = 3 * A * C (A <= 3, C <= 23; результат < 256)
mul3:		ld	e,a
		xor	a
		inc	e
ml1:		dec	e
		jp	z,ml2
		add	a,c
		jp	ml1
ml2:		ld	e,a
		add	a,a
		add	a,e
		ret
; div8: A / 8; div8b: A / 8 + A / 64
div8:		rrca
		rrca
		rrca
		and	0x1F
		ret
div8b:		ld	e,a
		call	div8
		ld	d,a
		ld	a,e
		rlca
		rlca
		and	3
		add	a,d
		ret

cr_end:		xor	a			; конец списка
		ld	hl,(cr_ptr)
		ld	(hl),a
		ret
; cr_add: в список (A, B) (BC, DE сохраняются)
cr_add:		ld	hl,(cr_ptr)
		ld	(hl),a
		inc	hl
		ld	(hl),b
		inc	hl
		ld	(cr_ptr),hl
		ret

; crit: после прерывания кадра — список действий cr_list
crit:		ld	hl,cr_list
ck0:		ld	a,(hl)
		or	a
		ret	z
		inc	hl
		ld	b,(hl)
		inc	hl
		push	hl
		cp	2
		jp	c,ck1
		jp	z,ck2
		cp	4
		jp	z,ck4
		call	draw1
		jp	ck9
ck4:		ld	c,DL_N			; ~256 тактов
ck4a:		dec	c
		jp	nz,ck4a
		dec	b
		jp	nz,ck4
		jp	ck9
ck1:		call	restore1
		jp	ck9
ck2:		ld	a,(ex_any)		; клетки откладывались?
		or	a
		jp	z,ck9
		ld	a,b
		call	rec_ptr
		ld	a,l
		add	a,5
		ld	l,a
		call	cells_rect
ck9:		pop	hl
		jp	ck0

; grp_of: A = номер -> A = grp[номер], HL -> grp[номер]
grp_of:		add	a,grp&0xFF		; grp — в пределах страницы
		ld	l,a
		ld	h,grp/256
		ld	a,(hl)
		ret

; overl: B, C — номера; CY — какое-то из мест одного (прежнее, если нарисован; новое, если виден) пересекает
; какое-то из мест другого (BC, D сохраняются)
overl:		push	de
		ld	a,b
		call	place0
		ld	(ov_a),hl
		ld	a,b
		call	place1
		ld	(ov_a1),hl
		ld	a,c
		call	place0
		ld	(ov_b),hl
		ld	a,c
		call	place1
		ld	(ov_b1),hl
		ld	hl,(ov_b)
		ex	de,hl
		ld	hl,(ov_a)
		call	ovp
		jp	c,ov_y
		ld	hl,(ov_a1)
		call	ovp
		jp	c,ov_y
		ld	hl,(ov_b1)
		ex	de,hl
		ld	hl,(ov_a)
		call	ovp
		jp	c,ov_y
		ld	hl,(ov_a1)
		call	ovp
ov_y:		pop	de
		ret
; ovp: HL, DE — места или 0; CY — оба есть и пересекаются
ovp:		ld	a,h
		or	l
		ret	z
		ld	a,d
		or	e
		ret	z
		jp	isect

; place0 / place1: A = номер -> HL = прежнее место (rec+5, если нарисован) / новое (new+5, если виден), иначе 0
place0:		call	rec_ptr
		jp	pl1
place1:		call	new_ptr
pl1:		ld	a,(hl)
		or	a
		jp	z,plz
		ld	a,5
		jp	add_hl_a
plz:		ld	hl,0
		ret

; cells_rect: HL -> (r0, r1, c0, c1): клетки, где VNT != NTS, — на экран
cells_rect:
		ld	a,(hl)
		ld	(cr_r),a
		inc	hl
		ld	a,(hl)
		ld	(cr_r1),a
		inc	hl
		ld	a,(hl)
		ld	(cr_c0),a
		inc	hl
		ld	a,(hl)
		ld	(cr_c1),a
cr0:		ld	a,(cr_r)		; HL = VNT + 32 r + c0
		ld	(rr_r),a
		ld	l,a
		ld	h,0
		add	hl,hl
		add	hl,hl
		add	hl,hl
		add	hl,hl
		add	hl,hl
		ld	a,(cr_c0)
		call	add_hl_a
		ld	de,VNT
		add	hl,de
		ld	a,(cr_c0)
		ld	(rr_c),a
cr1:		ld	a,h			; DE = NTS + то же смещение
		sub	VNT/256
		add	a,NTS/256
		ld	d,a
		ld	e,l
		ld	a,(cr_force)		; все клетки (стирание врага одной плоскости)
		or	a
		jp	nz,cr1f
		ld	a,(de)
		cp	(hl)
		jp	z,cr2
cr1f:
		ld	a,(hl)
		ld	(de),a
		ld	(rr_t),a
		push	hl
		call	draw_cell
		pop	hl
cr2:		inc	hl
		ld	a,(rr_c)
		inc	a
		ld	(rr_c),a
		ld	b,a
		ld	a,(cr_c1)
		cp	b
		jp	nc,cr1
		ld	a,(cr_r)
		inc	a
		ld	(cr_r),a
		ld	b,a
		ld	a,(cr_r1)
		cp	b
		jp	nc,cr0
		ret
