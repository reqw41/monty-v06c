; Программные спрайты 16x16 по таблице атрибутов VSAT (TMS9918: Y, X, имя, цвет | EC) с сохранением фона
; в невидимой плоскости (ячейка SPR_SLOTS + 256 * номер). Кадр: spr_plan (какие перерисовать: изменённые,
; под изменёнными клетками, пересекающие их) -> spr_restore (фон назад, 0..) -> вывод клеток -> spr_draw
; (отмеченные, с последнего: меньший номер сверху). Неизменённые спрайты не трогаются — не мерцают. Спрайт — до 3 столбцов x 3 плоскости вертикальных полос по 16 строк. Маски столбцов
; (sm_or[3][16]) считаются один раз на спрайт; AND-плоскости берут инверсию на лету. Полосы — развёрнутые блоки,
; адреса входа (по числу строк) подставляются в команды CALL (самоизменяемый код). Спрайт с тем же (X, Y), что
; у нарисованного перед ним, фон не сохраняет (слои героя). Y = D0 — конец, цвет 0 — не виден, EC и Y > BF — нет.
		IFNDEF	NATIVE
SPR_MAX		equ	6
		ENDIF
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
spr_plan:					; один проход: атрибуты VSAT против нарисованных (запись +1..+4); изменённым
		ld	de,VSAT			; (или при spr_force) — метка, новые атрибуты, видимость, место
		ld	hl,spr_rec+1		; DE -> атрибуты, L = 16 * k + 1
		ld	b,SPR_MAX
spl0:		ld	a,(de)
		cp	0xD0
		jp	nz,spl_c
		ld	de,spl_z		; конец таблицы: дальше невидимы, атрибуты D0 0 0 0
spl_c:		ld	a,(spr_force)
		or	a
		jp	nz,spl_ch
		push	de
		REPT	3
		ld	a,(de)
		cp	(hl)
		jp	nz,spl_cp
		inc	de
		inc	l
		ENDR
		ld	a,(de)
		cp	(hl)
		jp	nz,spl_cp
		pop	de
		ld	a,l			; без изменений: метка 0
		and	0xF0
		or	13
		ld	l,a
		ld	(hl),0
		jp	spl_n
spl_cp:		pop	de
spl_ch:		ld	a,l			; изменился: метка 1
		and	0xF0
		or	13
		ld	l,a
		ld	(hl),1
		and	0xF0			; новые атрибуты -> spr_new +1..+4
		or	0x81
		ld	l,a
		push	de
		REPT	4
		ld	a,(de)
		ld	(hl),a
		inc	de
		inc	l
		ENDR
		pop	de
		ld	a,(de)			; виден: Y + 1 < 192, цвет без EC и не 0
		inc	a
		cp	192
		jp	nc,spl_inv
		ld	c,a			; C = Y + 1
		inc	de
		inc	de
		inc	de
		ld	a,(de)
		dec	de
		dec	de
		and	0x8F
		jp	m,spl_iv1
		jp	z,spl_iv1
		ld	a,c			; +5..+8: строки y/8 .. (y+15)/8 (до 23), столбцы X/8 .. +1/+2 (до 31)
		rrca
		rrca
		rrca
		and	0x1F
		ld	(hl),a
		inc	l
		ld	a,c
		add	a,15
		rrca
		rrca
		rrca
		and	0x1F
		cp	24
		jp	c,spl2
		ld	a,23
spl2:		ld	(hl),a
		inc	l
		ld	a,(de)
		dec	de
		ld	c,a
		push	bc
		rrca
		rrca
		rrca
		and	0x1F
		ld	(hl),a
		inc	l
		inc	a
		ld	b,a			; (B — счётчик, на время)
		ld	a,c
		and	7
		ld	a,b
		pop	bc
		push	bc
		jp	z,spl3
		inc	a
spl3:		cp	32
		jp	c,spl3a
		ld	a,31
spl3a:		ld	(hl),a
		pop	bc
		ld	a,l
		and	0xF0
		ld	l,a
		ld	(hl),1
		jp	spl_n
spl_iv1:	dec	de
spl_inv:	ld	a,l
		and	0xF0
		ld	l,a
		ld	(hl),0
spl_n:		inc	de			; следующий: DE += 4, L = 16 * (k + 1) + 1
		inc	de
		inc	de
		inc	de
		ld	a,l
		and	0x70
		add	a,0x11
		ld	l,a
		dec	b
		jp	nz,spl0
		xor	a
		ld	(spr_force),a
		jp	spl_done
spl_z:		REPT	SPR_MAX
		db	0xD0,0,0,0
		ENDR
spl_done:
; под нарисованным неотмеченным изменились клетки — отметить (только если клетки вообще менялись)
		ld	a,(dl_n)
		ld	b,a
		ld	a,(dl_ovf)
		or	b
		jp	z,spx0
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
; замыкание: неотмеченный нарисованный, чья рамка (ubr) пересекает рамку отмеченного
spx0:		call	spn_cnt			; никто не отмечен — нечего замыкать
		ret	z
		call	ub_build
spx0a:		xor	a
		ld	(spx_ch),a
		ld	b,0
spx1:		ld	a,b
		call	rec_ptr
		ld	a,(hl)
		or	a
		jp	z,spx8
		ld	a,l
		add	a,13
		ld	l,a
		ld	a,(hl)
		or	a
		jp	nz,spx8
		ld	(spx_a),hl		; метка k
		ld	a,l			; прежнее место k (+5..+8) -> D, E, C, ub_c1
		sub	8
		ld	l,a
		ld	d,(hl)
		inc	l
		ld	e,(hl)
		inc	l
		ld	c,(hl)
		inc	l
		ld	a,(hl)
		ld	(ub_c1),a
		push	bc
		ld	b,0			; j
spx2:		ld	a,b			; отмечен? (+13)
		add	a,a
		add	a,a
		add	a,a
		add	a,a
		add	a,13
		ld	l,a
		ld	h,spr_rec/256
		ld	a,(hl)
		or	a
		jp	z,spx7
		ld	a,b
		call	ub_hit
		jp	c,spx_m
spx7:		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,spx2
		pop	bc
		jp	spx8
spx_m:		pop	bc
		ld	hl,(spx_a)
		ld	(hl),1
		ld	a,1
		ld	(spx_ch),a
		ld	a,b
		call	ub_one
spx8:		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,spx1
		ld	a,(spx_ch)
		or	a
		jp	nz,spx0a
		jp	spn_cnt
spn_cnt:	ld	hl,spr_rec+13		; A = число отмеченных
		ld	de,16
		ld	b,SPR_MAX
		xor	a
spn0:		add	a,(hl)
		add	hl,de
		dec	b
		jp	nz,spn0
		or	a
		ret

; ub_build: рамки отмеченных (ub_one)
ub_build:	ld	b,0
ubb0:		ld	a,b
		add	a,a
		add	a,a
		add	a,a
		add	a,a
		add	a,13
		ld	l,a
		ld	h,spr_rec/256
		ld	a,(hl)
		or	a
		ld	a,b
		call	nz,ub_one
		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,ubb0
		ret
; ub_one: A = номер -> ubr[k] = рамка (r0, r1, c0, c1) прежнего места (если нарисован) и нового (если виден);
; ни того ни другого — пусто (FF, 0, FF, 0). B сохраняется
ub_one:		ld	c,a
		add	a,a
		add	a,a
		add	a,ubr&0xFF		; (страница sprt)
		ld	e,a
		ld	d,ubr/256
		ld	a,c
		add	a,a
		add	a,a
		add	a,a
		add	a,a
		ld	l,a
		ld	h,spr_rec/256
		ld	a,(hl)			; нарисован — прежнее место
		or	a
		jp	z,uo_e
		ld	a,l
		or	5
		ld	l,a
		REPT	4
		ld	a,(hl)
		ld	(de),a
		inc	l
		inc	e
		ENDR
		dec	e
		dec	e
		dec	e
		dec	e
		ld	a,l			; запись в spr_new (+80h)
		and	0xF0
		or	0x80
		ld	l,a
		ld	a,(hl)
		or	a
		ret	z
		ld	a,l			; объединение с новым местом
		or	5
		ld	l,a
		ld	a,(de)			; r0 = min
		cp	(hl)
		jp	c,um1
		ld	a,(hl)
		ld	(de),a
um1:		inc	l
		inc	e
		ld	a,(de)			; r1 = max
		cp	(hl)
		jp	nc,um2
		ld	a,(hl)
		ld	(de),a
um2:		inc	l
		inc	e
		ld	a,(de)			; c0 = min
		cp	(hl)
		jp	c,um3
		ld	a,(hl)
		ld	(de),a
um3:		inc	l
		inc	e
		ld	a,(de)			; c1 = max
		cp	(hl)
		ret	nc
		ld	a,(hl)
		ld	(de),a
		ret
uo_e:		ld	a,l			; не нарисован: новое место (если виден), иначе пусто
		or	0x80
		ld	l,a
		ld	a,(hl)
		or	a
		jp	z,uo_z
		ld	a,l
		or	5
		ld	l,a
		REPT	4
		ld	a,(hl)
		ld	(de),a
		inc	l
		inc	e
		ENDR
		ret
uo_z:		ld	a,0xFF
		ld	(de),a
		inc	e
		xor	a
		ld	(de),a
		inc	e
		dec	a
		ld	(de),a
		inc	e
		xor	a
		ld	(de),a
		ret
; ub_ld: A = номер -> рамка в D (r0), E (r1), C (c0), ub_c1 (c1)
ub_ld:		add	a,a
		add	a,a
		add	a,ubr&0xFF
		ld	l,a
		ld	h,ubr/256
		ld	d,(hl)
		inc	l
		ld	e,(hl)
		inc	l
		ld	c,(hl)
		inc	l
		ld	a,(hl)
		ld	(ub_c1),a
		ret
; ub_hit: A = номер; CY — его рамка пересекает рамку из ub_ld (BC, DE сохраняются)
ub_hit:		add	a,a
		add	a,a
		add	a,ubr&0xFF
		ld	l,a
		ld	h,ubr/256
		ld	a,e			; r0j <= r1
		cp	(hl)
		jp	c,uh_n
		inc	l
		ld	a,(hl)			; r1j >= r0
		cp	d
		jp	c,uh_n
		inc	l
		ld	a,(ub_c1)		; c0j <= c1
		cp	(hl)
		jp	c,uh_n
		inc	l
		ld	a,(hl)			; c1j >= c0
		cp	c
		ccf
		ret
uh_n:		or	a
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

; se_init: se_tab[строк 0..SV_MAX] — адреса входа (cs_sv, cs_rs, cs_or, cs_and)
se_init:	ld	de,se_tab
		xor	a
sei1:		ld	(st_rows),a
		push	de
		call	set_entries_slow
		pop	de
		ld	hl,cs_sv+1
		call	sei_w
		ld	hl,cs_rs+1
		call	sei_w
		ld	hl,cs_or+1
		call	sei_w
		ld	hl,cs_and+1
		call	sei_w
		ld	a,(st_rows)
		inc	a
		cp	SV_MAX+1
		jp	nz,sei1
		ret
sei_w:		ld	a,(hl)
		ld	(de),a
		inc	hl
		inc	de
		ld	a,(hl)
		ld	(de),a
		inc	de
		ret
set_entries_slow:
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
		ld	(rs_mode),a		; 2 — одной плоскостью: фон только плоскости 8000
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
		add	a,rst&0xFF		; (страница sprt)
		ld	l,a
		ld	h,rst/256
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
		ld	a,(rs_mode)		; 3 — двумя плоскостями: с A000
		cp	3
		jp	nz,sr1
		ld	b,0xA0
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
		ld	a,(rs_mode)
		cp	2
		jp	z,sr_x
		ld	a,b
		add	a,0x20
		ld	b,a
		cp	0xE0
		jp	nz,sr1
sr_x:		pop	bc
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
		ld	c,2			; враг цвета палитры 4 — одной плоскостью (8000), без фона
		jp	z,pm0a
		ld	a,l			; индекс без бита 2 (герой: 1, 2) — двумя плоскостями A000, C000
		add	a,9
		ld	l,a
		ld	a,(hl)
		and	4
		ld	c,3
		jp	z,pm0a
		ld	c,0
pm0a:		pop	hl
		push	hl
		ld	a,l
		add	a,15
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
		add	a,svr&0xFF		; (страница sprt)
		ld	l,a
		ld	h,svr/256
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
		ld	a,(hl)			; плоскости k: 0 (три) или 3 (две); у k+1 — те же или три
		ld	c,a
		cp	2
		jp	z,pm8
		ld	a,l
		add	a,15
		ld	l,a
		ld	a,(hl)
		or	a
		jp	z,pm8
		inc	hl
		ld	a,(hl)
		cp	c
		jp	z,pm1b
		or	a
		jp	nz,pm8
pm1b:
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
		add	a,svr&0xFF		; (страница sprt)
		ld	l,a
		ld	h,svr/256
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
		cp	1
		jp	nz,pu_n
		ld	(hl),0			; +14: 0 — слой (без фона)
		jp	spr_paint
pu_n:		or	a			; +14: 1 — с фоном, 2 — одной плоскостью (фон плоскости 8000)
		jp	nz,pu_s
		inc	a
pu_s:		ld	(hl),a
		ld	a,l			; запись +9..+12 := svr[k]
		sub	5
		ld	l,a
		push	hl
		ld	a,b
		add	a,a
		add	a,a
		add	a,svr&0xFF		; (страница sprt)
		ld	l,a
		ld	h,svr/256
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
		add	a,pps&0xFF		; (страница sprt)
		ld	l,a
		ld	h,pps/256
		push	hl
		ld	a,c
		add	a,rst&0xFF		; (страница sprt)
		ld	l,a
		ld	h,rst/256
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
		add	a,pps2&0xFF		; (страница sprt)
		ld	l,a
		ld	h,pps2/256
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
		ld	a,(sp_sp)		; двумя плоскостями — с A000
		cp	3
		jp	nz,pu1
		ld	b,0xA0
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
		ld	a,(sp_sp)		; одной плоскостью — только 8000
		cp	2
		jp	z,pu3
		ld	a,b
		add	a,0x20
		ld	b,a
		cp	0xE0
		jp	nz,pu1
pu3:
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
		ld	a,(hl)			; плоскости по индексу: 4 — 8000 (OR), без бита 2 — A000, C000, иначе три
		ld	c,2
		cp	4
		jp	z,spp1
		ld	c,0
		and	4
		jp	nz,spp1
		ld	c,3
spp1:		ld	a,c
		ld	(sp_pm),a
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
		add	a,ppd&0xFF		; (страница sprt)
		ld	l,a
		ld	h,ppd/256
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
		ld	a,(sp_pm)		; двумя плоскостями: с A000 (бит плоскости 8000 пропустить)
		cp	3
		jp	nz,so3
		ld	b,0xA0
		ld	a,(sp_cbits)
		rlca
		ld	(sp_cbits),a
so3:		ld	a,(sp_pm)		; одной плоскостью: только 8000, OR
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
		ld	a,(sp_pm)
		cp	2
		ret	z
		ld	a,b
		add	a,0x20
		ld	b,a
		cp	0xE0
		jp	nz,so3
		ret

; spr_ready: для подготовленных (new +14) — заготовки: pps[k] (область фона svr[k]: столбцов, 3 столбца,
; вход st_rs), pps2[k] (вход st_sv), ppd[k] (рисование: столбцов, cl_h, cl_m, входы st_or, st_and);
; входы — прямо из se_tab
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
		ld	a,b
		ld	(sy_k),a
		add	a,a			; область фона svr[k]: L, столбец, строк, пустые
		add	a,a
		add	a,(svr&0xFF)+1		; (страница sprt)
		ld	l,a
		ld	h,svr/256
		ld	c,(hl)
		inc	l
		ld	a,(hl)
		inc	l
		ld	b,(hl)
		call	se_ptr
		ld	a,(sy_k)		; pps[k] (6 * k)
		ld	l,a
		add	a,a
		add	a,l
		add	a,a
		add	a,pps&0xFF
		ld	l,a
		ld	h,pps/256
		push	hl
		inc	l
		ld	de,cb_m
		call	cb_to
		pop	hl
		ld	a,e
		sub	cb_m&0xFF
		ld	(hl),a			; столбцов
		ld	a,l
		add	a,4
		ld	e,a
		ld	d,h
		ld	hl,(sy_se)		; se: sv, rs, or, and
		ld	c,(hl)
		inc	hl
		ld	b,(hl)
		inc	hl
		ld	a,(hl)
		ld	(de),a
		inc	e
		inc	hl
		ld	a,(hl)
		ld	(de),a
		ld	a,(sy_k)		; pps2[k] — вход st_sv
		add	a,a
		add	a,pps2&0xFF
		ld	l,a
		ld	h,pps2/256
		ld	(hl),c
		inc	l
		ld	(hl),b
		ld	a,(sy_k)		; рисование: свои параметры (new +10..+12)
		call	new_ptr
		ld	a,l
		add	a,10
		ld	l,a
		ld	c,(hl)
		inc	l
		ld	a,(hl)
		inc	l
		ld	b,(hl)
		call	se_ptr
		ld	a,(sy_k)		; ppd[k] (11 * k)
		ld	l,a
		add	a,a
		add	a,a
		add	a,l
		add	a,a
		add	a,l
		add	a,ppd&0xFF
		ld	l,a
		ld	h,ppd/256
		push	hl
		ld	a,l
		add	a,4
		ld	e,a
		ld	d,h			; маски — с +4
		inc	l
		call	cb_to
		pop	hl
		ld	a,e
		sub	l
		sub	4
		ld	(hl),a			; столбцов
		ld	a,l
		add	a,7
		ld	e,a
		ld	d,h
		ld	hl,(sy_se)
		inc	hl
		inc	hl
		inc	hl
		inc	hl
		REPT	4			; входы st_or, st_and
		ld	a,(hl)
		ld	(de),a
		inc	hl
		inc	e
		ENDR
		pop	bc
sy9:		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,sy0
		ret
; se_ptr: A = строк -> sy_se = se_tab + 8 * строк (BC сохраняется)
se_ptr:		add	a,a
		add	a,a
		add	a,a
		ld	hl,se_tab
		add	a,l
		ld	l,a
		ld	a,h
		adc	a,0
		ld	h,a
		ld	(sy_se),hl
		ret
; cb_to: C = столбец, B = пустые (биты 0..2), HL — куда столбцы экрана, DE — куда смещения масок (16 * j):
; столбцы C + j, кроме пустых и вне экрана; HL, DE — за последними записанными (внутри страниц)
cb_to:		ld	a,b
		rrca
		jp	c,cbt1
		ld	(hl),c
		inc	l
		xor	a
		ld	(de),a
		inc	e
cbt1:		ld	a,b
		and	2
		jp	nz,cbt2
		ld	a,c
		inc	a
		cp	32
		jp	nc,cbt2
		ld	(hl),a
		inc	l
		ld	a,16
		ld	(de),a
		inc	e
cbt2:		ld	a,b
		and	4
		ret	nz
		ld	a,c
		add	a,2
		cp	32
		ret	nc
		ld	(hl),a
		inc	l
		ld	a,32
		ld	(de),a
		inc	e
		ret
cb_m:		ds	3
		ASSERT	cb_m/256 == (cb_m+2)/256

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
		ld	de,grp
cg0:		ld	a,b
		add	a,a
		add	a,a
		add	a,a
		add	a,a
		add	a,13
		ld	l,a
		ld	h,spr_rec/256
		ld	a,(hl)
		or	a
		ld	a,0xFF
		jp	z,cgx1
		ld	a,b
cgx1:		ld	(de),a
		inc	e
		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,cg0
cu0:		xor	a			; объединение пересекающихся (рамки ubr — прежние и новые места)
		ld	(spx_ch),a
		ld	b,0
cu1:		ld	a,b
		call	grp_of
		cp	SPR_MAX
		jp	nc,cu8
		ld	(cu_g),a
		ld	a,b
		push	bc			; i (C — c0 рамки i)
		call	ub_ld
cu2:		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nc,cu7
		call	grp_of
		cp	SPR_MAX
		jp	nc,cu2
		ld	hl,cu_g
		cp	(hl)
		jp	z,cu2
		ld	(cu_gj),a
		ld	a,b
		call	ub_hit
		jp	nc,cu2
		push	bc			; все с grp = grp[j] -> grp[i]
		ld	a,(cu_gj)
		ld	c,a
		ld	hl,grp
		ld	b,SPR_MAX
cu3:		ld	a,(hl)
		cp	c
		jp	nz,cu4
		ld	a,(cu_g)
		ld	(hl),a
cu4:		inc	hl
		dec	b
		jp	nz,cu3
		pop	bc
		ld	a,1
		ld	(spx_ch),a
		jp	cu2
cu7:		pop	bc
cu8:		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,cu1
		ld	a,(spx_ch)
		or	a
		jp	nz,cu0
gp0:		ld	a,0xFF			; группа с наименьшей верхней строкой клеток (прежнее и новое место)
		ld	(gp_y),a
		ld	(gp_g),a
		ld	b,0
gp1:		ld	a,b
		add	a,grp&0xFF
		ld	l,a
		ld	h,grp/256
		ld	a,(hl)
		cp	SPR_MAX
		jp	nc,gp3
		ld	e,a
		ld	a,b			; верх: r0 рамки (прежнее и новое место)
		add	a,a
		add	a,a
		add	a,ubr&0xFF
		ld	l,a
		ld	h,ubr/256
		ld	c,(hl)
gp1b:		ld	a,(gp_y)
		cp	c
		jp	c,gp3
		jp	z,gp3
		ld	a,c
		ld	(gp_y),a
		ld	a,e
		ld	(gp_g),a
gp3:		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,gp1
		ld	a,(gp_g)
		cp	0xFF
		jp	z,cr_end
		ld	c,a			; C = группа, DE -> список
		ld	hl,(cr_ptr)
		ex	de,hl
		ld	a,1			; фон назад (нарисованные), по возрастанию
		call	gp_emit
		ld	a,2			; клетки под прежними местами
		call	gp_emit
		ld	hl,grp+SPR_MAX-1	; спрайты, с последнего; группа обработана (FE)
		ld	b,SPR_MAX
gp8:		dec	b
		ld	a,(hl)
		cp	c
		jp	nz,gp9
		ld	(hl),0xFE
		ld	a,3
		ld	(de),a
		inc	de
		ld	a,b
		ld	(de),a
		inc	de
gp9:		dec	l
		ld	a,b
		or	a
		jp	nz,gp8
		ex	de,hl
		ld	(cr_ptr),hl
		jp	gp0
; gp_emit: A = действие — (A, k) в список DE для нарисованных k группы C, по возрастанию
gp_emit:	ld	(gp_a),a
		ld	hl,grp
		ld	b,0
ge0:		ld	a,(hl)
		cp	c
		jp	nz,ge1
		push	hl
		ld	a,b
		add	a,a
		add	a,a
		add	a,a
		add	a,a
		ld	l,a
		ld	h,spr_rec/256
		ld	a,(hl)
		pop	hl
		or	a
		jp	z,ge1
		ld	a,(gp_a)
		ld	(de),a
		inc	de
		ld	a,b
		ld	(de),a
		inc	de
ge1:		inc	l
		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,ge0
		ret

cr_end:		xor	a			; конец списка
		ld	hl,(cr_ptr)
		ld	(hl),a
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
		call	draw1
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
		ASSERT	grp/256 == (grp+SPR_MAX-1)/256
grp_of:		add	a,grp&0xFF		; grp — в пределах страницы
		ld	l,a
		ld	h,grp/256
		ld	a,(hl)
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
