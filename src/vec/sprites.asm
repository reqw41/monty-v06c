; Программные спрайты 16x16 по таблице атрибутов VSAT (TMS9918: Y, X, имя, цвет | EC) с сохранением фона
; в невидимой плоскости (ячейка SPR_SLOTS + 256 * номер). Кадр: spr_plan (какие перерисовать: изменённые,
; под изменёнными клетками, пересекающие их) -> spr_restore (фон назад, 0..) -> вывод клеток -> spr_draw
; (отмеченные, с последнего: меньший номер сверху). Неизменённые спрайты не трогаются — не мерцают. Спрайт — до 3 столбцов x 3 плоскости вертикальных полос по 16 строк. Маски столбцов
; (sm_or[3][16]) считаются один раз на спрайт; AND-плоскости берут инверсию на лету. Полосы — развёрнутые блоки,
; адреса входа (по числу строк) подставляются в команды CALL (самоизменяемый код). Спрайт с тем же (X, Y), что
; у нарисованного перед ним, фон не сохраняет (слои героя). Y = D0 — конец, цвет 0 — не виден, EC и Y > BF — нет.
SPR_MAX		equ	6
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
rec_ptr:	ld	hl,spr_rec
rp1:		add	a,a
		add	a,a
		add	a,a
		add	a,a
		jp	add_hl_a
new_ptr:	ld	hl,spr_new
		jp	rp1

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

st_sv:		REPT	16			; фон в ячейку
		ld	a,(hl)
		ld	(de),a
		inc	e
		dec	l
		ENDR
		ret
st_rs:		REPT	16			; фон из ячейки
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
		ld	hl,st_sv+16*4
		call	sub_hl_c
		ld	(cs_sv+1),hl
		ld	hl,st_rs+16*4
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
spr_restore:
		ld	b,0
sr0:		ld	a,b
		call	rec_ptr
		ld	a,(hl)
		or	a
		jp	z,sr9
		push	hl
		ld	de,13
		add	hl,de
		ld	a,(hl)
		pop	hl
		or	a
		jp	z,sr9
		ld	(hl),0			; больше не нарисован
		ld	de,9
		add	hl,de
		ld	a,(hl)
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
		push	bc
		call	cols_build
		call	set_entries
		pop	bc
		ld	a,b
		add	a,SPR_SLOTS/256
		ld	d,a
		ld	e,0
		push	bc
		ld	b,0x80
sr1:		ld	hl,cl_h
		ld	a,(cl_n)
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
sr9:		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,sr0
		ret

; --- spr_draw: отмеченные спрайты, с последнего (меньший номер сверху): запись := новые атрибуты, рисование ----
spr_draw:
		ld	b,SPR_MAX
sd2:		dec	b
		push	bc
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
		ld	a,(de)			; виден?
		ld	(sp_vis),a
		inc	de
		ld	b,8			; атрибуты и прямоугольник
sd3:		ld	a,(de)
		ld	(hl),a
		inc	hl
		inc	de
		dec	b
		jp	nz,sd3
		ld	a,(sp_vis)
		or	a
		jp	z,sd8
		ld	a,(sp_k)
		call	rec_ptr
		inc	hl
		call	spr_one
sd8:		pop	bc
		ld	a,b
		or	a
		jp	nz,sd2
		ret

; spr_one: HL -> атрибуты спрайта sp_k; фон под ним — в ячейку SPR_SLOTS + 256 * sp_k
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
		call	set_entries
		call	cols_build
		ld	a,(cl_n)
		or	a
		ret	z
		ld	a,(sp_k)		; запись: нарисован, место для восстановления
		call	rec_ptr
		ld	(hl),1
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
		ld	a,(sp_k)
		add	a,SPR_SLOTS/256
		ld	h,a
		ld	l,0
		ld	(sv_ptr),hl
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
		push	de
		ld	h,a
		ld	a,(sv_lo)
		ld	l,a
		push	hl			; экран: верх полосы
		ld	hl,(sv_ptr)
		ex	de,hl			; DE = ячейка фона
		pop	hl			; HL = экран
		push	hl
cs_sv:		call	st_sv
		ex	de,hl
		ld	(sv_ptr),hl
		pop	hl
		pop	de
		ld	a,(de)
		inc	de
		push	de
		add	a,sm_or&0xFF
		ld	e,a
		ld	d,sm_or/256
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
