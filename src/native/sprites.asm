; Объекты игры 7300 в порядке 72E0: постоянные дескрипторы слоёв с сохранением фона
; в невидимой плоскости (ячейка SPR_SLOTS + 256 * номер). Кадр: spr_plan (какие перерисовать: изменённые,
; под изменёнными клетками, пересекающие их) -> spr_restore (фон назад, 0..) -> вывод клеток -> spr_draw
; (отмеченные, с последнего: меньший номер сверху). Неизменённые спрайты не трогаются — не мерцают. Спрайт — до 3 столбцов x 3 плоскости вертикальных полос по 16 строк. Маски столбцов
; (sm_or[3][16]) считаются один раз на спрайт; AND-плоскости берут инверсию на лету. Полосы — развёрнутые блоки,
; адреса входа (по числу строк) подставляются в команды CALL (самоизменяемый код). Спрайт с тем же (X, Y), что
; у нарисованного перед ним, фон не сохраняет (слои героя). Y = D0 — конец, цвет 0 — не виден, EC и Y > BF — нет.
SM_OFS		equ	0xD0			; маски столбцов в ячейке спрайта (фон — до 3 x 3 x 23 = CF)
T0_U		equ	3			; единиц (256 тактов) от прерывания до первой группы
MA_U		equ	3			; запас «до луча»
MB_U		equ	2			; запас «после луча»
DL_N		equ	11			; ожидание: витков на единицу
SV_MAX		equ	23			; строк в области фона (слои героя: 16 + сдвиг до 7)
SREC		equ	16			; запись: нарисован, Y X имя цвет, r0 r1 c0 c1 (клетки), L, столбец, строк,
						; пустые столбцы, метка (+13)

; spr_plan: новые атрибуты (spr_new) и метки перерисовки в spr_rec: спрайт отмечен, если атрибуты не те
; (или spr_force), если под нарисованным клетки ждут вывода (PND) и, до замыкания, если его прямоугольник
; пересекает прежний или новый прямоугольник отмеченного. A = число отмеченных.
; obj_ptr: A = место в порядке объектов -> DE = запись объекта игры (7300).
; HL и BC сохраняются. Копия таблицы атрибутов не нужна.
obj_ptr:	push	hl
		ld	l,a
		ld	h,0x72
		ld	a,l
		add	a,0xE0
		ld	l,a
		ld	a,(hl)
		add	a,a
		add	a,a
		ld	e,a
		ld	d,0x73
		pop	hl
		ret

spr_plan:	ld	a,(nmi_pend)
		or	a
		ld	a,3
		jp	z,spl_limit
		ld	a,2
spl_limit:	ld	(spl_dx+1),a
		ld	(spl_dy+1),a
		ld	hl,0x0101
		ld	(cover_moves),hl
		ld	(cover_moves+2),hl
		ld	(cover_moves+4),hl
		xor	a
		ld	(obj_end),a
		ld	hl,spr_rec+1		; DE -> атрибуты, L = 16 * k + 1
		ld	b,SPR_MAX
spl0:		ld	a,SPR_MAX
		sub	b
		call	obj_ptr
		ld	a,(obj_end)
		or	a
		jp	nz,spl_end
		ld	a,(de)
		cp	0xD0
		jp	nz,spl_c
		ld	a,1
		ld	(obj_end),a
spl_end:	ld	de,spl_z
spl_c:		ld	a,(de)
		cp	(hl)
		jp	z,spl_band_y
		xor	a
		ld	(band_valid),a
spl_band_y:	ld	a,(spr_force)
		or	a
		jp	nz,spl_ch
		ld	a,SPR_MAX
		sub	b
		cp	2
		jp	c,spl_compare
		cp	5
		jp	nc,spl_compare
		push	hl
		push	de
		inc	l
		inc	de
		ld	a,(de)
		sub	(hl)
		jp	nc,spl_dx
		cpl
		inc	a
spl_dx:		cp	3
		jp	nc,spl_distance
		ld	c,a
		dec	l
		dec	de
		ld	a,(de)
		sub	(hl)
		jp	nc,spl_dy
		cpl
		inc	a
spl_dy:		cp	3
		jp	nc,spl_distance
		or	c
		ld	c,a
		scf
spl_distance:	pop	de
		pop	hl
		jp	nc,spl_compare
		push	de
		inc	de
		inc	de
		inc	de
		ld	a,(de)
		and	0x8F
		pop	de
		jp	z,spl_compare
		jp	m,spl_compare
		ld	a,c
		or	a
		jp	nz,spl_hold
		push	de
		inc	de
		inc	de
		ld	a,(de)
		pop	de
		push	hl
		inc	l
		inc	l
		cp	(hl)
		pop	hl
		jp	z,spl_hold
		ld	a,SPR_MAX
		sub	b
		sub	2
		push	hl
		ld	hl,enemy_turn
		cp	(hl)
		pop	hl
		jp	z,spl_compare
spl_hold:
		ld	a,l
		and	0xF0
		or	13
		ld	l,a
		ld	(hl),0
		jp	spl_n
spl_compare:
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
spl_ch:		ld	a,l
		and	0xF0
		or	15
		ld	l,a
		ld	(hl),1			; дескриптор меняется только вместе с объектом
		ld	a,l			; изменился: метка 1
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
		call	rolling_pose
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
		push	hl
		ld	a,l
		sub	5
		ld	l,a
		ld	a,(hl)			; рамка показанной позиции, включая промежуточную позу
		pop	hl
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
spl_n:		push	hl
		ld	a,l
		and	0x70
		ld	l,a
		ld	a,(hl)
		ld	c,a
		ld	a,l
		or	0x80
		ld	l,a
		ld	a,(hl)
		cp	c
		jp	z,spl_band_v
		xor	a
		ld	(band_valid),a
spl_band_v:	pop	hl
		inc	de			; следующий: DE += 4, L = 16 * (k + 1) + 1
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
spl_z:		db	0xD0,0,0,0
spl_done:
; Очередь клеток уже накопила покрывающие её объекты; не сканировать их прямоугольники заново.
		ld	a,(sprite_dirty)
		rrca
		ld	c,a
		ld	b,SPR_MAX
		ld	hl,spr_rec+13
spd0:		ld	a,c
		rrca
		ld	c,a
		jp	nc,spd_next
		ld	(hl),1
spd_next:	ld	a,l
		add	a,16
		ld	l,a
		dec	b
		jp	nz,spd0
		xor	a
		ld	(sprite_dirty),a
; замыкание: неотмеченный нарисованный, чья рамка (ubr) пересекает рамку отмеченного
spx0:		ld	a,(band_candidate)
		or	a
		jp	z,spx_normal
		ld	a,(band_valid)
		or	a
		call	z,band_build
		call	band_check
		ld	a,(band_ok)
		or	a
		jp	nz,band_marked
spx_normal:	call	spn_cnt			; никто не отмечен — нечего замыкать
		ret	z
		cp	1
		jp	nz,spx_general
		call	single_clear
		ret	c
spx_general:	call	ub_build
spx0a:		ld	de,ml			; ml := отмеченные (номера)
		ld	hl,spr_rec+13
		ld	b,0
sm0:		ld	a,(hl)
		or	a
		jp	z,sm1
		ld	a,b
		ld	(de),a
		inc	e
sm1:		ld	a,l
		add	a,16
		ld	l,a
		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,sm0
		ld	a,e
		sub	ml&0xFF
		ld	(ml_n),a
		xor	a
		ld	(spx_ch),a
		ld	hl,spr_rec
spx1:		ld	a,(hl)			; нарисован и не отмечен
		or	a
		jp	z,spx8
		ld	a,l
		or	13
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
		ld	a,(ml_n)
		ld	b,a
		ld	hl,ml
spx2:		ld	a,(hl)			; рамка отмеченного j пересекает?
		push	hl
		call	ub_hit
		pop	hl
		jp	c,spx_m
		inc	l
		dec	b
		jp	nz,spx2
		ld	hl,(spx_a)
		jp	spx8
spx_m:		ld	hl,(spx_a)
		ld	(hl),1
		ld	a,1
		ld	(spx_ch),a
		ld	a,l
		rrca
		rrca
		rrca
		rrca
		and	7
		push	hl
		call	ub_one
		pop	hl
spx8:		ld	a,l
		and	0xF0
		add	a,16
		ld	l,a
		cp	16*SPR_MAX
		jp	nz,spx1
		ld	a,(spx_ch)		; отмечались — ещё круг
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
		call	cover_clear
		ld	(hl),0			; больше не нарисован
		inc	de
		ld	a,(de)			; фон сохранял он сам?
		or	a
		ret	z
		ld	(rs_mode),a		; 2 — одной плоскостью: фон только плоскости 8000
		cp	2
		jp	z,enemy_restore
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
		ld	a,(spr_rec+15)
		ld	hl,spr_rec+16+15
		or	(hl)
		ld	(hl),a
		ld	(spr_rec+15),a
		ld	(joe_changed),a
		ld	a,(ml_n)
		ld	b,a
		ld	hl,ml
pp0:		push	bc
		push	hl
		ld	b,(hl)
		ld	a,b
		ld	(sp_k),a
		call	rec_ptr
		ld	de,13
		add	hl,de
		ld	a,(hl)
		or	a
		jp	z,pp9
		ld	a,l
		add	a,2
		ld	l,a
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
		ld	a,b
		call	new_ptr
		inc	hl
		push	bc
		ld	a,b
		cp	2
		jp	c,pp_hero
		call	enemy_prepare
		jp	pp_ready
pp_hero:	call	spr_one
pp_ready:	pop	bc
pp9:		pop	hl
		pop	bc
		inc	l
		dec	b
		jp	nz,pp0
		ld	a,(spr_rec+15)
		ld	hl,spr_rec+16+15
		or	(hl)
		ret	z
; области фона: своя (new +9..+12); слой k над k+1 в той же точке (оба готовы) — k без фона (+15 = 1),
; у k+1 — объединение: верх = max L, низ = min (L - строк + 1), пустые столбцы — общие
		ld	b,0
pm0:		ld	a,b			; только отмеченные (неотмеченные не рисуются; слой — только с отмеченным:
		call	rec_ptr			; они пересекаются — замыкание отметило оба)
		ld	a,l
		add	a,13
		ld	l,a
		ld	a,(hl)
		or	a
		jp	z,pm0n
		inc	l
		inc	l
		ld	a,(hl)
		or	a
		jp	z,pm0n
		ld	a,b
		call	new_ptr
		push	hl
		inc	hl			; +4: цвет
		inc	hl
		inc	hl
		inc	hl
		ld	a,(hl)
		and	0x0F
		ld	c,a
		ld	a,c			; все, кроме Джо (цвета 6, 11), — враги: одной плоскостью (8000) цветом
		cp	6			; палитры 4 (цвет врагов комнаты), фон — только этой плоскости
		ld	c,2
		jp	z,pm0h
		cp	11
		jp	nz,pm0a
pm0h:		ld	c,0			; Джо — тремя плоскостями (бит 2 его индекса — 0: под ним 8000 гасится, враг
						; и белые тайлы не красят его в 5, 7 — цвет врагов)
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
pm0n:		inc	b
		ld	a,b
		cp	2
		jp	nz,pm0
		ld	a,(spr_rec+15)
		ld	hl,spr_rec+16+15
		or	(hl)
		jp	z,spr_ready
		ld	b,0			; Джо — один объект с двумя слоями, общая область фона
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
pm8:		jp	spr_ready

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
		ld	(sp_cr),a
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
		call	ps_find			; враг с готовыми сдвигами — маска не нужна
		call	nz,spr_masks
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
		inc	l
		inc	e
		REPT	8			; атрибуты и прямоугольник (одна страница)
		ld	a,(de)
		ld	(hl),a
		inc	l
		inc	e
		ENDR
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
		call	cover_set
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
		cp	2
		jp	z,enemy_native_put
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
		ld	a,(joe_fast)
		or	a
		jp	nz,joe_blit
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
		ld	a,(joe_fast)
		or	a
		ret	nz
		ld	a,(sp_k)		; маски: готовые сдвиги (ps_hi[k] != 0) или ячейка спрайта
		add	a,ps_hi&0xFF
		ld	l,a
		ld	h,ps_hi/256
		ld	a,(hl)
		or	a
		jp	z,spp0
		ld	(sp_mskp),a
		ld	a,l
		sub	ps_hi-ps_lo
		ld	l,a
		ld	a,(hl)
		jp	spp2
spp0:		ld	a,(sp_mpage)
		ld	(sp_mskp),a
		ld	a,SM_OFS
spp2:		ld	(so_mofs+1),a
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
		ld	c,2			; плоскости: враг (sp_sp = 2) — 8000 (OR); Джо — три (8000 под ним гасится)
		ld	a,(sp_sp)
		cp	c
		jp	z,spp1
		ld	c,0
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
so_mofs:	add	a,SM_OFS		; маска: ячейка + D0 + 16 * столбец (или готовый сдвиг: блок + R * столбец)
		ld	e,a
		ld	a,(sp_mskp)
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
		call	rec_ptr
		ld	a,l
		add	a,13
		ld	l,a
		ld	a,(hl)			; не отмечен — рисоваться не будет
		or	a
		jp	z,sy9
		inc	l
		inc	l
		ld	a,(hl)
		or	a
		jp	z,sy9
		ld	(hl),0
		ld	a,l
		add	a,0x7F
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
		ld	a,(sy_k)		; шаг столбцов масок: 16 или строк готового сдвига
		add	a,ps_hi&0xFF
		ld	e,a
		ld	d,ps_hi/256
		ld	a,(de)
		or	a
		ld	a,16
		jp	z,sy4
		ld	a,e
		add	a,ps_r-ps_hi
		ld	e,a
		ld	a,(de)
sy4:		ld	(cb_st),a
		push	hl
		ld	a,l
		add	a,4
		ld	e,a
		ld	d,h			; маски — с +4
		inc	l
		call	cb_to
		ld	a,16
		ld	(cb_st),a
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
		cp	2
		jp	nz,sy0
		jp	joe_prepare
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
; cb_to: C = столбец, B = пустые (биты 0..2), HL — куда столбцы экрана, DE — куда смещения масок (cb_st * j):
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
		ld	a,(cb_st)
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
		ld	a,(cb_st)
		add	a,a
		ld	(de),a
		inc	e
		ret
		ALIGN	4
cb_m:		ds	3
		ASSERT	cb_m/256 == (cb_m+2)/256

; spr_masks: sm_or[j][line] — строка шаблона, сдвинутая на s = X & 7 (столбцы j = 0..2); sv_zc: бит j — пусто.
; r = циклический сдвиг вправо на s (вход в цепочку RRCA подставлен в CALL), m = FFh >> s:
; столбец 0 = rB & m, 1 = (rB & ~m) | (rC & m), 2 = rC & ~m; при s = 0 — без сдвига, столбец 2 пуст.
spr_masks:
		ld	a,(sp_k)		; та же маска, что в прошлый раз (шаблон, сдвиг, начало, строк) — не строить
		add	a,a
		add	a,a
		add	a,mk_key&0xFF		; (страница sprt)
		ld	l,a
		ld	h,mk_key/256
		ld	c,0			; C — отличий
		ld	a,(sp_name)
		call	mk_cmp
		ld	a,(sp_x)
		and	7
		call	mk_cmp
		ld	a,(sm_off)
		call	mk_cmp
		ld	a,(st_rows)
		call	mk_cmp
		ld	a,c
		or	a
		ret	z
		ld	a,(sp_name)
		call	sprite_source
		ld	a,(sm_off)
		call	add_hl_a
		ld	a,(st_rows)
		ld	(sp_line),a
		ld	a,(sp_k)		; маски — в ячейку спрайта (+D0)
		add	a,SPR_SLOTS/256
		ld	d,a
		ld	e,SM_OFS
		ld	a,(sp_x)
		and	7
		jp	z,smz			; s = 0
		call	rotate_select
		ld	b,a
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
		call	rotate_byte
		ld	c,a
smk_m0:		and	0
		ld	(de),a			; столбец 0 = r0 & m
		ld	a,e
		add	a,16
		ld	e,a
		ld	a,c
smk_n1:		and	0
		ld	(de),a			; столбец 1 (пока) = r0 & ~m
		ld	a,l
		add	a,16
		ld	l,a
		ld	a,(hl)
		call	rotate_byte
		ld	c,a
smk_m1:		and	0
		ex	de,hl
		or	(hl)
		ld	(hl),a			; столбец 1 |= r1 & m
		ex	de,hl
		ld	a,e
		add	a,16
		ld	e,a
		ld	a,c
smk_n2:		and	0
		ld	(de),a			; столбец 2 = r1 & ~m
		ld	a,e
		sub	31
		ld	e,a
		ld	a,l
		sub	15
		ld	l,a
		ld	a,(sp_line)
		dec	a
		ld	(sp_line),a
		jp	nz,smk1
		ret
; mk_cmp: A — с (HL): другое — (HL) := A, C += 1; HL += 1
mk_cmp:		cp	(hl)
		jp	z,mkc1
		ld	(hl),a
		inc	c
mkc1:		inc	l
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

; Начальное состояние масок слоёв Джо; таблицы поворота больше не нужны.

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
; cr_list: пары (действие, номер): 1 — фон назад, 2 — клетки, 3 — спрайт,
; 4 — независимый враг в прежней области, повторное использование фона; конец 0.
; Группа: фон всех назад (0..), клетки под прежними местами, спрайты (с последнего).
crit_plan:
		ld	a,(ml_n)
		cp	1
		jp	nz,crit_groups
		ld	a,(ml)
		ld	h,a
		ld	l,1
		ld	(cr_list),hl
		inc	l
		ld	(cr_list+2),hl
		inc	l
		ld	(cr_list+4),hl
		xor	a
		ld	(cr_list+6),a
		ret
crit_groups:
		ld	a,(band_candidate)
		or	a
		jp	z,crit_general
		ld	a,(band_ok)
		or	a
		jp	nz,band_emit
crit_general:	ld	hl,cr_list
		ld	(cr_ptr),hl
		ld	de,ml			; отмеченные -> ml (по возрастанию), grp[k] := k, неотмеченные — FF
		ld	b,0
cq0:		ld	a,b
		add	a,a
		add	a,a
		add	a,a
		add	a,a
		add	a,13
		ld	l,a
		ld	h,spr_rec/256
		ld	a,(hl)
		or	a
		ld	c,0xFF
		jp	z,cq1
		ld	c,b
		ld	a,b
		ld	(de),a
		inc	e
cq1:		ld	a,b
		add	a,grp&0xFF
		ld	l,a
		ld	h,grp/256
		ld	(hl),c
		ld	a,b			; mg[k] := 0 (не объединялся)
		add	a,mg&0xFF
		ld	l,a
		ld	h,mg/256
		ld	(hl),0
		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,cq0
		ld	a,e
		sub	ml&0xFF
		ld	(ml_n),a
		ld	hl,ml			; объединение: пары (i, j) из ml, рамки пересекаются — группа j -> группа i
cu1:		ld	a,(ml_n)
		ld	b,a
		ld	a,l
		sub	ml&0xFF
		inc	a
		cp	b
		jp	nc,gp0			; i — последний
		push	hl
		ld	a,(hl)
		ld	(cu_i),a
		call	ub_ld			; рамка i -> D, E, C, ub_c1
		pop	hl
		push	hl
cu2:		inc	l
		ld	a,l
		sub	ml&0xFF
		ld	b,a
		ld	a,(ml_n)
		cp	b
		jp	z,cu8
		push	hl
		ld	a,(hl)			; j
		ld	(cu_j),a
		call	grp_of
		ld	(cu_gj),a
		ld	a,(cu_i)
		call	grp_of
		ld	(cu_g),a
		ld	hl,cu_gj
		cp	(hl)
		jp	z,cu7			; уже вместе
		ld	a,(cu_j)
		call	ub_hit
		jp	nc,cu7
		ld	a,(cu_i)		; оба — в группе из нескольких
		add	a,mg&0xFF
		ld	l,a
		ld	h,mg/256
		ld	(hl),1
		ld	a,(cu_j)
		add	a,mg&0xFF
		ld	l,a
		ld	(hl),1
		ld	hl,ml			; все с grp = grp[j] -> grp[i]
		ld	a,(ml_n)
		ld	b,a
cu3:		ld	a,(hl)
		push	hl
		add	a,grp&0xFF
		ld	l,a
		ld	h,grp/256
		ld	a,(cu_gj)
		cp	(hl)
		jp	nz,cu4
		ld	a,(cu_g)
		ld	(hl),a
cu4:		pop	hl
		inc	l
		dec	b
		jp	nz,cu3
cu7:		pop	hl
		jp	cu2
cu8:		pop	hl
		inc	l
		jp	cu1
gp0:		call	sort_marked
gq9:		ld	hl,(cr_ptr)		; группы — по первому в порядке ml; DE -> список
		ex	de,hl
		ld	hl,ml
		ld	a,(ml_n)
		or	a
		jp	z,gp_x
		ld	b,a
gp1:		ld	a,(hl)			; k
		push	hl
		push	bc
		ld	c,a
		call	ub_r0			; места нет (рамка пуста) — и дальше нет
		cp	0xFF
		jp	z,gp_e
		ld	a,c
		add	a,grp&0xFF
		ld	l,a
		ld	h,grp/256
		ld	a,(hl)
		cp	SPR_MAX
		jp	nc,gp3			; группа уже выведена
		ld	b,a
		ld	a,c
		add	a,mg&0xFF
		ld	l,a
		ld	h,mg/256
		ld	a,(hl)
		or	a
		jp	nz,gp_m
		ld	a,c			; одиночный: фон, клетки (если нарисован), рисование
		add	a,grp&0xFF
		ld	l,a
		ld	h,grp/256
		ld	(hl),0xFE
		ld	a,c
		add	a,a
		add	a,a
		add	a,a
		add	a,a
		ld	l,a
		ld	h,spr_rec/256
		ld	a,(hl)
		or	a
		jp	z,gp2
		ld	a,1
		ld	(de),a
		inc	de
		ld	a,c
		ld	(de),a
		inc	de
		ld	a,2
		ld	(de),a
		inc	de
		ld	a,c
		ld	(de),a
		inc	de
gp2:		ld	a,3
		ld	(de),a
		inc	de
		ld	a,c
		ld	(de),a
		inc	de
		jp	gp3
gp_m:		ld	c,b			; группа C из нескольких: по номерам
		ld	a,1			; фон назад (нарисованные), по возрастанию
		call	gp_emit
		ld	a,2			; клетки под прежними местами
		call	gp_emit
		ld	b,SPR_MAX		; спрайты, с последнего; группа выведена (FE)
		ld	hl,grp+SPR_MAX-1
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
gp3:		pop	bc
		pop	hl
		inc	l
		dec	b
		jp	nz,gp1
		jp	gp_x
gp_e:		pop	bc
		pop	hl
gp_x:		ex	de,hl
		ld	(cr_ptr),hl
		jp	cr_end
; ub_r0: A = номер -> A = верх рамки (HL портится)
ub_r0:		add	a,a
		add	a,a
		add	a,ubr&0xFF		; (страница sprt)
		ld	l,a
		ld	h,ubr/256
		ld	a,(hl)
		ret
; gp_emit: A = действие — (A, k) в список DE для нарисованных k группы C, по возрастанию номеров
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
crit:		xor	a
		ld	(cr_units),a
		ld	hl,(cr_read)
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
		jp	z,ck_repaint
		xor	a
		ld	(en_reuse),a
		call	draw1
		jp	ck_count
ck_repaint:	ld	a,1
		ld	(en_reuse),a
		ld	a,b
		add	a,cover_moves&255
		ld	l,a
		ld	h,cover_moves/256
		ld	(hl),0
		call	draw1
ck_count:	ld	a,b
		cp	2
		ld	a,1
		jp	nc,ck_units
		inc	a
ck_units:	ld	hl,cr_units
		add	a,(hl)
		ld	(hl),a
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
		ld	a,(cr_units)
		cp	4
		jp	c,ck0
		ld	a,(hl)
		cp	1
		jp	z,ck_defer
		cp	4
		jp	nz,ck0
ck_defer:	ld	(cr_read),hl
		ld	a,1
		ld	(crit_pend),a
		ret

; grp_of: A = номер -> A = grp[номер], HL -> grp[номер]
		ASSERT	grp/256 == (grp+SPR_MAX-1)/256
grp_of:		add	a,grp&0xFF		; grp — в пределах страницы
		ld	l,a
		ld	h,grp/256
		ld	a,(hl)
		ret

; cells_rect: HL -> (r0, r1, c0, c1): клетки, ждущие вывода (PND), — на экран
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
		inc	a
		ld	hl,cr_c0
		sub	(hl)
		ld	(cr_c1),a		; (здесь — число столбцов)
cr0:		ld	a,(cr_r)		; HL = PND + 32 r + c0
		rrca
		rrca
		rrca
		ld	l,a
		and	0x1F
		add	a,PND/256
		ld	h,a
		ld	a,l
		and	0xE0
		ld	l,a
		ld	a,(cr_c0)
		or	l
		ld	l,a
		ld	a,(cr_c1)
		ld	b,a
cr1:		ld	a,(hl)			; ждёт вывода
		and	1
		jp	z,cr2
		ld	a,(hl)
		and	0xFE
		ld	(hl),a
		push	hl
		push	bc
		ld	a,h			; тайл — из VNT (то же смещение)
		add	a,(VNT-PND)/256
		ld	d,a
		ld	e,l
		ld	a,(de)
		ld	(rr_t),a
		ld	a,(cr_r)
		ld	(rr_r),a
		ld	a,l
		and	31
		ld	(rr_c),a
		call	draw_cell
		pop	bc
		pop	hl
cr2:		inc	l
		dec	b
		jp	nz,cr1
		ld	a,(cr_r)
		inc	a
		ld	(cr_r),a
		ld	b,a
		ld	a,(cr_r1)
		cp	b
		jp	nc,cr0
		ret

; --- готовые сдвиги кадров врагов: при старте (ps_build) для кадров ps_names — все 8 сдвигов по столбцам
; (столбец j — R байт с первой непустой строки, R — строк по обрезке; блок 3R байт — в одной странице);
; ps_tab[8 * номер + s] — адрес блока, ps_rr[номер] — R; ps_idx[имя / 4] — номер (FF — нет)
ps_names:	db	0x0C,0x10,0x14,0x18,0x1C,0x20,0x24,0x28,0x2C,0x30,0x68,0x78,0xFF
PS_N		equ	12
; ps_find: для спрайта sp_k — враг (цвет не 6, 11) с готовыми сдвигами: ps_lo/hi/r[k] := блок, R; Z.
; Иначе ps_hi[k] := 0, NZ
ps_find:	ld	a,(sp_k)
		add	a,ps_hi&0xFF
		ld	l,a
		ld	h,ps_hi/256
		ld	(hl),0
		ld	a,(sp_cr)
		cp	6
		jp	z,psf_n
		cp	11
		jp	z,psf_n
		ld	a,(sp_name)
		rrca
		rrca
		and	0x3F
		ld	l,a
		ld	h,0
		ld	de,ps_idx
		add	hl,de
		ld	a,(hl)
		cp	0xFF
		jp	z,psf_n
		ld	c,a			; C = номер
		ld	hl,ps_rr
		call	add_hl_a
		ld	b,(hl)			; B = R
		ld	a,c			; ps_tab + 2 * (8 * номер + s)
		add	a,a
		add	a,a
		add	a,a
		ld	l,a
		ld	a,(sp_x)
		and	7
		add	a,l
		ld	l,a
		ld	h,0
		add	hl,hl
		ld	de,ps_tab
		add	hl,de
		ld	e,(hl)
		inc	hl
		ld	d,(hl)
		ld	a,d			; места не хватило — масками
		or	a
		jp	z,psf_n
		ld	a,(sp_k)
		add	a,ps_lo&0xFF
		ld	l,a
		ld	h,ps_lo/256
		ld	(hl),e
		ld	a,l
		add	a,ps_hi-ps_lo
		ld	l,a
		ld	(hl),d
		add	a,ps_r-ps_hi
		ld	l,a
		ld	(hl),b
		xor	a
		ret
psf_n:		or	1
		ret

; ps_build: блоки готовых сдвигов (после trim_build и mask_keys_init) — в свободные места ps_rg
; Одноразовый построитель исполняется из ещё пустого кэша тайлов E000.
; Его исходный код после копирования также доступен ps_alloc.
ps_boot_source:
		DISP	TILE_IMAGES
joe_load:
		ld	de,joe_source0
		ld	hl,0xFB30
		ld	bc,joe_end0-joe_source0
		call	copy_de_hl
		ld	de,joe_source1
		ld	hl,0xFC30
		ld	bc,joe_end1-joe_source1
		call	copy_de_hl
		ld	de,joe_source2
		ld	hl,0xFD30
		ld	bc,joe_end2-joe_source2
		call	copy_de_hl
		ld	de,joe_source3
		ld	hl,0xFE30
		ld	bc,joe_end3-joe_source3
		jp	copy_de_hl
game_init:	ld	hl,0x7000
		ld	de,ram0_pk
		call	unpack
		ld	hl,room_colors
		ld	de,col0
		ld	bc,32
		call	copy_de_hl
		ld	a,1
		ld	(video_enabled),a
		ret
unpack:		ld	a,(de)
		inc	de
		cp	0xFF
		ret	z
		cp	0x80
		jp	nc,upk_r
		inc	a
		ld	b,a
upk_l:		ld	a,(de)
		ld	(hl),a
		inc	de
		inc	hl
		dec	b
		jp	nz,upk_l
		jp	unpack
upk_r:		and	0x7F
		add	a,2
		ld	b,a
		ld	a,(de)
		inc	de
upk_s:		ld	(hl),a
		inc	hl
		dec	b
		jp	nz,upk_s
		jp	unpack

ram0_pk:	INCBIN	"../../build/native/ram0.pk"

mask_keys_init:	ld	hl,mk_key
		ld	bc,4*SPR_MAX
		ld	e,0xFF
		jp	memfill

; --- обрезка по шаблону: spr_trim[имя/4] = (первая строка, последняя, пустые половины: бит 0 — левая, 1 — правая);
; строка пуста, если пусты обе половины; всё пусто — первая = FF. Пересчёт — trim_build (при смене комнаты).
trim_build:
		ld	de,spr_trim
		ld	c,64
tb0:		ld	a,64
		sub	c
		add	a,a
		add	a,a
		call	sprite_source
		push	bc
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
		pop	bc
		dec	c
		jp	nz,tb0
		ret

; lv_init: lv_idx и lv_tile (при загрузке)
lv_init:	xor	a
		ld	(lv_nn),a
		ld	hl,lv_idx
		ld	bc,256
		ld	e,0xFF
		call	memfill
		ld	de,anim_set
		ld	bc,lv_tile
		ld	h,lv_idx/256
		xor	a
lvi1:		push	af
		ld	a,(de)
		cp	0xFF
		jp	z,lvi2
		ld	l,a
		ld	(bc),a
		pop	af
		ld	(hl),a
		inc	a
		inc	de
		inc	bc
		jp	lvi1
lvi2:		pop	af
		ld	e,0xE0			; E0..EF — следующие корзины
lvi3:		ld	l,e
		ld	(hl),a
		push	af
		ld	a,e
		ld	(bc),a
		pop	af
		inc	bc
		inc	a
		inc	e
		jp	nz,lvi3
		ret

ps_build:	ld	hl,ps_idx
		ld	bc,64
		ld	e,0xFF
		call	memfill
		ld	hl,ps_rg
		ld	(ps_rp),hl
		call	ps_nrg
		ld	hl,ps_names
		ld	c,0
pbd0:		ld	a,(hl)
		cp	0xFF
		ret	z
		push	hl
		push	bc
		ld	(ps_nm),a
		rrca				; ps_idx[имя / 4] := номер
		rrca
		and	0x3F
		ld	hl,ps_idx
		call	add_hl_a
		ld	(hl),c
		ld	a,(ps_nm)		; обрезка: первая, последняя
		ld	l,a
		ld	h,0
		ld	de,spr_trim
		add	hl,de
		ld	a,(hl)
		ld	(ps_f),a
		inc	hl
		ld	b,(hl)
		sub	b
		cpl
		inc	a
		inc	a			; R = последняя - первая + 1
		ld	(ps_r0),a
		ld	a,c
		ld	hl,ps_rr
		call	add_hl_a
		ld	a,(ps_r0)
		ld	(hl),a
		xor	a
		ld	(ps_s),a
pbd1:		ld	a,(ps_s)		; m = FFh >> s
		call	rotate_select
		ld	b,a
		ld	a,0xFF
		inc	b
pbd6:		dec	b
		jp	z,pbd7
		or	a
		rra
		jp	pbd6
pbd7:		ld	(ps_m),a
		ld	a,(ps_r0)		; блок 3R
		ld	b,a
		add	a,a
		add	a,b
		call	ps_alloc		; HL — блок
		ld	(ps_dst),hl
		ld	a,h			; места нет — у этого кадра масок готовых нет (ps_tab — 0)
		or	l
		jp	z,pbd5
		pop	bc			; ps_tab[8 * номер + s] := HL
		push	bc
		ld	a,c
		add	a,a
		add	a,a
		add	a,a
		ld	b,a
		ld	a,(ps_s)
		add	a,b
		ld	l,a
		ld	h,0
		add	hl,hl
		ld	de,ps_tab
		add	hl,de
		ex	de,hl
		ld	hl,(ps_dst)
		ex	de,hl
		ld	(hl),e
		inc	hl
		ld	(hl),d
		ld	a,(ps_nm)
		call	sprite_source
		ld	a,(ps_f)
		call	add_hl_a
		ld	a,(ps_r0)
		ld	b,a			; B — строк
		push	hl
		ld	hl,(ps_dst)
		ex	de,hl
		pop	hl
pbd2:		push	bc
		ld	a,(hl)			; 24 бита: левая, правая, 0 — вправо на s
		ld	(ps_c0),a
		push	hl
		ld	a,16
		call	add_hl_a
		ld	a,(hl)
		ld	(ps_c1),a
		pop	hl
		xor	a
		ld	(ps_c2),a
		ld	a,(ps_s)		; s != 0: цепочка поворотов, m = FFh >> s: r0 & m, (r0 & ~m) | (r1 & m), r1 & ~m
		or	a
		jp	z,pbd4
		push	hl
		push	de
		ld	a,(ps_c0)
		call	rotate_byte
		ld	d,a
		ld	a,(ps_c1)
		call	rotate_byte
		ld	e,a
		ld	a,(ps_m)
		ld	c,a			; C = m
		and	d
		ld	(ps_c0),a
		ld	a,c
		cpl
		and	e
		ld	(ps_c2),a
		ld	a,c
		cpl
		and	d
		ld	b,a
		ld	a,c
		and	e
		or	b
		ld	(ps_c1),a
		pop	de
		pop	hl
pbd4:		ld	a,(ps_r0)		; столбцы: DE, DE + R, DE + 2R
		ld	c,a
		push	de
		ld	a,(ps_c0)
		ld	(de),a
		ld	a,e
		add	a,c
		ld	e,a
		ld	a,(ps_c1)
		ld	(de),a
		ld	a,e
		add	a,c
		ld	e,a
		ld	a,(ps_c2)
		ld	(de),a
		pop	de
		inc	e
		inc	hl
		pop	bc
		dec	b
		jp	nz,pbd2
pbd5:		ld	a,(ps_s)
		inc	a
		ld	(ps_s),a
		cp	8
		jp	nz,pbd1
		pop	bc
		pop	hl
		inc	hl
		inc	c
		jp	pbd0
; ps_alloc: A = байт -> HL = блок в одной странице (из ps_p; конец места — следующее место ps_rg); 0 — нет места
ps_alloc:	ld	c,a
psa0:		ld	hl,(ps_p)
		ld	a,h
		or	l
		ret	z
		ld	a,l
		add	a,c
		jp	nc,psa1
		jp	z,psa1			; ровно до конца страницы
		inc	h			; не помещается в страницу — со следующей
		ld	l,0
psa1:		push	hl			; конец места?
		ld	a,l
		add	a,c
		ld	e,a
		ld	a,h
		adc	a,0
		ld	d,a			; DE = HL + n
		ld	hl,(ps_end)
		ld	a,l
		sub	e
		ld	a,h
		sbc	a,d
		pop	hl
		jp	c,psa2			; не помещается
		ex	de,hl
		ld	(ps_p),hl
		ex	de,hl
		ret
psa2:		call	ps_nrg
		jp	psa0
; ps_nrg: следующее место из ps_rg -> ps_p, ps_end
ps_nrg:		push	hl
		push	de
		ld	hl,(ps_rp)
		ld	e,(hl)
		inc	hl
		ld	d,(hl)
		inc	hl
		ex	de,hl
		ld	(ps_p),hl
		ex	de,hl
		ld	e,(hl)
		inc	hl
		ld	d,(hl)
		inc	hl
		ex	de,hl
		ld	(ps_end),hl
		ex	de,hl
		ld	(ps_rp),hl
		pop	de
		pop	hl
		ret
		ENT
ps_boot_source_end:
		ASSERT ps_boot_source_end-ps_boot_source < 24*TILE_CAP
; свободные места (начало, конец): невидимая плоскость — бывший кэш тайлов, затем основная память
ps_rg:		dw	PS_MORE, 0x7000, sprite_sources_end, VNT, TILE_IMAGES+24*TILE_CAP, 0xEC00, 0xEF00, 0xF000, 0xF600, 0xF820, ps_heap, PS_TOP, ps_boot_source+112, ps_boot_source_end, 0, 0	; 0 — места нет

; Покрытие клеток объектами постоянно хранится в PND, биты 1..6 по слоям.
; Меняется только при восстановлении/рисовании объекта; перекрытия сохраняют чужие биты.
cover_bits: db 2,4,8,16,32,64
cover_set:	push	af
		push	hl
		ld	a,b
		add	a,cover_moves&255
		ld	l,a
		ld	h,cover_moves/256
		ld	a,(hl)
		pop	hl
		or	a
		jp	z,cover_no_set
		ld	a,0xF6			; OR immediate
		jp	cover_start
cover_clear:	push	af
		ld	a,0xE6			; AND immediate
cover_start:	ld	(cover_op),a
		push	bc
		push	de
		push	hl
		ld	a,(cover_op)
		cp	0xE6
		jp	nz,cover_go
		ld	a,b
		call	new_ptr
		ld	a,(hl)
		or	a
		jp	z,cover_go
		ld	a,l
		or	5
		ld	e,a
		ld	d,h
		and	0x7F
		ld	l,a
		REPT	4
		ld	a,(de)
		cp	(hl)
		jp	nz,cover_go
		inc	l
		inc	e
		ENDR
		ld	a,b
		add	a,cover_moves&255
		ld	l,a
		ld	h,cover_moves/256
		ld	(hl),0
		jp	cover_end
cover_go:	ld	a,b
		ld	hl,cover_bits
		call	add_hl_a
		ld	a,(cover_op)
		cp	0xE6
		ld	a,(hl)
		jp	nz,cover_mask
		cpl
cover_mask:	ld	(cover_op+1),a
		ld	a,b
		call	rec_ptr
		ld	a,l
		add	a,5
		ld	l,a
		ld	d,(hl)
		inc	l
		ld	e,(hl)
		inc	l
		ld	b,(hl)
		inc	l
		ld	c,(hl)
cover_row:	ld	a,d
		rrca
		rrca
		rrca
		ld	l,a
		and	31
		add	a,PND/256
		ld	h,a
		ld	a,l
		and	0xE0
		or	b
		ld	l,a
		push	bc
		ld	a,c
		sub	b
		inc	a
		ld	b,a
cover_col:	ld	a,(hl)
cover_op:	or	0
		ld	(hl),a
		inc	l
		dec	b
		jp	nz,cover_col
		pop	bc
		ld	a,d
		inc	d
		cp	e
		jp	c,cover_row
cover_end:	pop	hl
		pop	de
		pop	bc
cover_no_set:	pop	af
		ret

; cover_dirty: A = байт PND; известны все объекты над изменившейся клеткой.
cover_dirty:	push	hl
		ld	hl,sprite_dirty
		or	(hl)
		ld	(hl),a
		pop	hl
		ret

; sprite_source: A = кадр объекта (шаг 4) -> HL = 32 байта двух исходных половин.
; Исходники разделяются между кадрами; DE/BC сохраняются.
sprite_source:	rrca
		and	0x7E
		ld	l,a
		ld	h,sprite_sources/256
		ld	a,(hl)
		inc	l
		ld	h,(hl)
		ld	l,a
		ret


; Нативный враг: дескриптор — L, столбец, строки, пустые столбцы; без PPS/PPD/RST.
enemy_native_put:	ld	a,l
		sub	5
		ld	l,a
		push	hl
		ld	a,(sp_k)
		call	new_ptr
		ld	a,l
		add	a,9
		ld	l,a
		ex	de,hl
		pop	hl
		REPT	4
		ld	a,(de)
		ld	(hl),a
		inc	l
		inc	e
		ENDR
		ld	a,(sp_k)
		add	a,ps_hi&255
		ld	l,a
		ld	h,ps_hi/256
		ld	a,(hl)
		or	a
		jp	z,en_slot_mask
		ld	(sp_mskp),a
		ld	a,l
		add	a,ps_r-ps_hi
		ld	l,a
		ld	a,(hl)
		ld	(en_stride),a
		ld	a,l
		sub	ps_r-ps_lo
		ld	l,a
		ld	a,(hl)
		jp	en_mask_ready
en_slot_mask:	ld	a,(sp_mpage)
		ld	(sp_mskp),a
		ld	a,16
		ld	(en_stride),a
		ld	a,SM_OFS
en_mask_ready:	ld	(en_mask),a
		ld	a,(sp_k)
		call	new_ptr
		ld	a,l
		add	a,9
		ld	l,a
		call	en_load
		ld	a,(st_rows)
		add	a,a
		ld	hl,enemy_entries
		ld	c,a
		ld	a,(en_reuse)
		or	a
		jp	z,en_table_ready
		ld	hl,enemy_repaint_entries
en_table_ready:	ld	a,c
		call	add_hl_a
		ld	e,(hl)
		inc	hl
		ld	d,(hl)
		ex	de,hl
		ld	(en_mix_call+1),hl
		jp	en_entry_ready
en_entry_ready:	ld	a,(sp_mpage)
		ld	b,a
		ld	c,0
		ld	a,3
		ld	(cl_n),a
en_paint_col:	ld	a,(en_zero)
		rrca
		ld	(en_zero),a
		jp	c,en_paint_next
		ld	a,(sv_col)
		cp	32
		ret	nc
		add	a,0x80
		ld	h,a
		ld	a,(sv_lo)
		ld	l,a
		ld	a,(en_mask)
		ld	e,a
		ld	a,(sp_mskp)
		ld	d,a
		ld	a,(en_reuse)
		or	a
		jp	z,en_mix_call
		push	hl
		ld	h,b
		ld	l,c
		pop	bc
en_mix_call:	call	enemy_mix
		ld	a,(en_reuse)
		or	a
		jp	z,en_paint_next
		ld	b,h
		ld	c,l
en_paint_next:	ld	hl,sv_col
		inc	(hl)
		ld	a,(en_stride)
		ld	hl,en_mask
		add	a,(hl)
		ld	(hl),a
		ld	hl,cl_n
		dec	(hl)
		jp	nz,en_paint_col
		ret

; HL -> L, столбец, строки, пустые столбцы.
en_load:	ld	a,(hl)
		ld	(sv_lo),a
		inc	l
		ld	a,(hl)
		ld	(sv_col),a
		inc	l
		ld	a,(hl)
		ld	(st_rows),a
		inc	l
		ld	a,(hl)
		ld	(en_zero),a
		ret

enemy_restore:	push	bc
		ld	a,l
		add	a,9
		ld	l,a
		call	en_load
		ld	a,(st_rows)
		add	a,a
		add	a,a
		add	a,a
		add	a,2
		ld	hl,se_tab
		jp	en_restore_lookup
en_restore_lookup:	call	add_hl_a
		ld	e,(hl)
		inc	hl
		ld	d,(hl)
		ex	de,hl
		ld	(en_restore_call+1),hl
		ld	a,b
		add	a,SPR_SLOTS/256
		ld	d,a
		ld	e,0
		ld	a,(sv_col)
		ld	c,a
		ld	b,3
en_restore_col:	ld	a,(en_zero)
		rrca
		ld	(en_zero),a
		jp	c,en_restore_next
		ld	a,c
		cp	32
		jp	nc,en_restore_done
		add	a,0x80
		ld	h,a
		ld	a,(sv_lo)
		ld	l,a
		xor	a
en_restore_call:	call	st_rs
en_restore_next:	inc	c
		dec	b
		jp	nz,en_restore_col
en_restore_done:	pop	bc
		ret

enemy_entries:
		dw	enemy_mix+8*(16-0)
		dw	enemy_mix+8*(16-1)
		dw	enemy_mix+8*(16-2)
		dw	enemy_mix+8*(16-3)
		dw	enemy_mix+8*(16-4)
		dw	enemy_mix+8*(16-5)
		dw	enemy_mix+8*(16-6)
		dw	enemy_mix+8*(16-7)
		dw	enemy_mix+8*(16-8)
		dw	enemy_mix+8*(16-9)
		dw	enemy_mix+8*(16-10)
		dw	enemy_mix+8*(16-11)
		dw	enemy_mix+8*(16-12)
		dw	enemy_mix+8*(16-13)
		dw	enemy_mix+8*(16-14)
		dw	enemy_mix+8*(16-15)
		dw	enemy_mix+8*(16-16)
enemy_mix:
		REPT	16
		ld	a,(hl)
		ld	(bc),a
		ld	a,(de)
		or	(hl)
		ld	(hl),a
		inc	c
		inc	e
		dec	l
		ENDR
		ret

enemy_repaint_entries:
		DUP	17, n
		dw	enemy_repaint_mix+6*(16-n)
		EDUP
enemy_repaint_mix:
		REPT	16
		ld	a,(de)
		or	(hl)
		ld	(bc),a
		inc	l
		inc	e
		dec	c
		ENDR
		ret

; Выбор цепочки RRCA только при подготовке изменившегося кадра/сдвига.
rotate_select:	push	af
		push	hl
		ld	hl,rotate_7
		cpl
		add	a,8
		call	add_hl_a
		ld	(rotate_byte+1),hl
		pop	hl
		pop	af
		ret
rotate_byte:	jp	rotate_0
rotate_7:	rrca
		rrca
		rrca
		rrca
		rrca
		rrca
		rrca
rotate_0:	ret

; Дескриптор врага не содержит таблиц вызовов и списков столбцов.
enemy_prepare:	call	spr_one
		ld	c,2
		ld	a,(sp_k)
		call	new_ptr
		ld	a,l
		add	a,15
		ld	l,a
		ld	(hl),c
		ld	a,l
		and	0x7F
		ld	l,a
		ld	(hl),0
		ret

; Один изменённый объект: покрытие клеток доказывает отсутствие пересечений.
; CY — замыкание не нужно, ml содержит единственный объект.
single_clear:	ld	hl,spr_rec+13
		ld	b,0
sc_find:	ld	a,(hl)
		or	a
		jp	nz,sc_found
		ld	a,l
		add	a,16
		ld	l,a
		inc	b
		jp	sc_find
sc_found:	ld	a,b
		ld	(sp_k),a
		call	ub_one
		ld	a,(sp_k)
		call	ub_ld
		ld	a,d
		cp	24
		jp	nc,sc_no
		ld	a,c
		cp	32
		jp	nc,sc_no
		ld	(sv_col),a
		ld	a,(ub_c1)
		sub	c
		inc	a
		ld	(cl_n),a
		ld	c,0
sc_row:		ld	a,d
		rrca
		rrca
		rrca
		ld	l,a
		and	31
		add	a,PND/256
		ld	h,a
		ld	a,l
		and	0xE0
		ld	b,a
		ld	a,(sv_col)
		or	b
		ld	l,a
		ld	a,(cl_n)
		ld	b,a
sc_col:		ld	a,(hl)
		or	c
		ld	c,a
		inc	l
		dec	b
		jp	nz,sc_col
		ld	a,d
		inc	d
		cp	e
		jp	c,sc_row
		ld	a,(sp_k)
		ld	hl,cover_bits
		call	add_hl_a
		ld	a,(hl)
		cpl
		and	c
		and	0x7E
		jp	nz,sc_no
		ld	a,(sp_k)
		ld	(ml),a
		ld	a,1
		ld	(ml_n),a
		scf
		ret
sc_no:		or	a
		ret


; Катящиеся враги: кэш порядка по Y и пар с общими строками.
; Эти пары проверяются по X на каждом выводе; слои Джо остаются одной группой.
band_room_init:	xor	a
		ld	(band_valid),a
		ld	(band_ok),a
		ld	(band_candidate),a
		ld	(band_pair_n),a
		ld	a,(0x707A)
		or	a
		ret	z
		ld	hl,0x7086
br0:		ld	a,(hl)
		cp	255
		jp	z,br_yes
		and	0x48
		cp	8
		ret	nz
		inc	hl
		inc	hl
		jp	br0
br_yes:		ld	a,1
		ld	(band_candidate),a
		ret

band_build:	ld	a,1
		ld	(band_valid),a
		xor	a
		ld	(band_ok),a
		ld	(band_pair_n),a
		ld	b,0
bb_bounds:	ld	a,b
		call	ub_one
		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,bb_bounds
		xor	a
		ld	(cu_i),a
bb_i:		ld	a,(cu_i)
		add	a,a
		add	a,a
		add	a,ubr&255
		ld	l,a
		ld	h,ubr/256
		ld	a,(cu_i)
		call	ub_ld
		ld	a,(cu_i)
		inc	a
		ld	(cu_j),a
bb_j:		ld	a,(cu_i)
		or	a
		jp	nz,bb_pair
		ld	a,(cu_j)
		cp	1
		jp	z,bb_next
bb_pair:	ld	a,(cu_j)
		add	a,a
		add	a,a
		add	a,ubr&255
		ld	l,a
		ld	h,ubr/256
		ld	a,e
		cp	(hl)
		jp	c,bb_next
		inc	l
		ld	a,(hl)
		cp	d
		jp	c,bb_next
		ld	a,(band_pair_n)
		ld	hl,band_pairs
		call	add_hl_a
		ld	a,(cu_i)
		ld	(hl),a
		inc	hl
		ld	a,(cu_j)
		ld	(hl),a
		ld	hl,band_pair_n
		inc	(hl)
		inc	(hl)
bb_next:	ld	hl,cu_j
		inc	(hl)
		ld	a,(hl)
		cp	SPR_MAX
		jp	nz,bb_j
		ld	hl,cu_i
		inc	(hl)
		ld	a,(hl)
		cp	SPR_MAX-1
		jp	nz,bb_i
		ld	a,SPR_MAX
		ld	(ml_n),a
		ld	hl,ml
		ld	b,SPR_MAX
		xor	a
bb_sort_input:	ld	(hl),a
		inc	l
		inc	a
		dec	b
		jp	nz,bb_sort_input
		call	sort_marked
		ld	de,ml
		ld	hl,band_order
		ld	b,SPR_MAX
		call	memcpyb
		ld	a,1
		ld	(band_ok),a
		ret

; Y/видимость кэшированы; только пары с общими строками проверяются по X.
; ub_one включает прежнее и новое место, в том числе промежуточную позу.
band_check:	ld	a,1
		ld	(band_ok),a
		ld	a,(band_pair_n)
		or	a
		ret	z
		ld	b,a
		ld	hl,band_pairs
bc_pair:	push	bc
		push	hl
		ld	a,(hl)
		call	band_xrange
		pop	hl
		push	hl
		push	de
		inc	hl
		ld	a,(hl)
		call	band_xrange
		pop	bc
		ld	a,c
		cp	d
		jp	c,bc_separate
		ld	a,e
		cp	b
		jp	nc,bc_overlap
bc_separate:	pop	hl
		pop	bc
		inc	hl
		inc	hl
		dec	b
		dec	b
		jp	nz,bc_pair
		ret
bc_overlap:	pop	hl
		pop	bc
		xor	a
		ld	(band_ok),a
		ret
; Cached pair members stay visible at fixed Y; union only their X cell intervals.
band_xrange:	call	rec_ptr
		ld	a,l
		or	7
		ld	l,a
		ld	d,(hl)
		inc	l
		ld	e,(hl)
		ld	a,l
		or	0x80
		ld	l,a
		ld	a,(hl)
		cp	e
		jp	c,bx_left
		ld	e,a
bx_left:	dec	l
		ld	a,(hl)
		cp	d
		ret	nc
		ld	d,a
		ret

band_marked:	ld	a,(spr_rec+13)
		ld	hl,spr_rec+16+13
		or	(hl)
		ld	(hl),a
		ld	(spr_rec+13),a
		ld	de,ml
		ld	hl,spr_rec+13
		ld	b,0
		ld	c,0
bm0:		ld	a,(hl)
		or	a
		jp	z,bm_next
		ld	a,b
		ld	(de),a
		inc	e
		inc	c
bm_next:	ld	a,l
		add	a,16
		ld	l,a
		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,bm0
		ld	a,c
		ld	(ml_n),a
		or	a
		ret

band_emit:	ld	de,cr_list
		ld	hl,band_order
		ld	b,SPR_MAX
be0:		ld	a,(hl)
		cp	1
		jp	z,be_next
		ld	c,a
		push	hl
		add	a,a
		add	a,a
		add	a,a
		add	a,a
		or	13
		ld	l,a
		ld	h,spr_rec/256
		ld	a,(hl)
		pop	hl
		or	a
		jp	z,be_next
		push	hl
		push	bc
		ld	b,c
		ld	a,b
		or	a
		jp	z,be_hero
		call	band_actor
		jp	be_pop
be_hero:	ld	b,0
		ld	a,1
		call	band_emit_one
		inc	b
		ld	a,1
		call	band_emit_one
		dec	b
		ld	a,2
		call	band_emit_one
		inc	b
		ld	a,2
		call	band_emit_one
		ld	a,3
		call	band_emit_one
		dec	b
		ld	a,3
		call	band_emit_one
be_pop:		pop	bc
		pop	hl
be_next:	inc	l
		dec	b
		jp	nz,be0
		xor	a
		ld	(de),a
		ret

band_actor:	ld	a,b
		call	rec_ptr
		ld	a,(hl)
		or	a
		jp	z,ba_draw
		push	hl
		ld	a,(ex_any)
		or	a
		jp	nz,ba_regular
		ld	a,l
		or	14
		ld	l,a
		ld	a,(hl)
		cp	2
		jp	nz,ba_regular
		ld	a,l
		or	0x80
		ld	l,a
		ld	a,(hl)
		or	a
		jp	z,ba_regular
		ld	a,l
		sub	5
		ld	l,a
		push	de
		ld	d,h
		ld	a,l
		and	0x7F
		ld	e,a
		ld	c,4
ba_compare:	ld	a,(de)
		cp	(hl)
		jp	nz,ba_changed
		inc	l
		inc	e
		dec	c
		jp	nz,ba_compare
		pop	de
		pop	hl
		ld	a,4
		ld	(de),a
		inc	de
		ld	a,b
		ld	(de),a
		inc	de
		ret
ba_changed:	pop	de
ba_regular:	pop	hl
		ld	a,1
		ld	(de),a
		inc	de
		ld	a,b
		ld	(de),a
		inc	de
		ld	a,2
		ld	(de),a
		inc	de
		ld	a,b
		ld	(de),a
		inc	de
ba_draw:	ld	a,3
		ld	(de),a
		inc	de
		ld	a,b
		ld	(de),a
		inc	de
		ret

band_emit_one:	ld	(gp_a),a
		ld	a,b
		call	rec_ptr
		push	hl
		ld	a,l
		or	13
		ld	l,a
		ld	a,(hl)
		pop	hl
		or	a
		ret	z
		ld	a,(gp_a)
		cp	3
		jp	z,be_write
		ld	a,(hl)
		or	a
		ret	z
be_write:	ld	a,(gp_a)
		ld	(de),a
		inc	de
		ld	a,b
		ld	(de),a
		inc	de
		ret

sort_marked:		ld	a,(ml_n)		; ml — по верхней строке рамки (вставками; равные — по номеру)
		cp	2
		ret	c
		ld	c,1			; p
gq1:		ld	a,c
		add	a,ml&0xFF
		ld	l,a
		ld	h,ml/256
		ld	b,(hl)			; B = ml[p]
		ld	a,b
		call	ub_r0
		ld	d,a			; D = её верх
		ld	e,c			; E = q
gq2:		ld	a,e
		or	a
		jp	z,gq3
		add	a,(ml&0xFF)-1
		ld	l,a
		ld	h,ml/256
		ld	a,(hl)			; ml[q - 1]
		push	af
		call	ub_r0
		cp	d
		jp	c,gq4			; меньше или равно — стоп
		jp	z,gq4
		ld	a,e			; (ub_r0 портит HL)
		add	a,ml&0xFF
		ld	l,a
		ld	h,ml/256
		pop	af
		ld	(hl),a			; ml[q] := ml[q - 1]
		dec	e
		jp	gq2
gq4:		pop	af
gq3:		ld	a,e
		add	a,ml&0xFF
		ld	l,a
		ld	h,ml/256
		ld	(hl),b
		inc	c
		ld	a,(ml_n)
		cp	c
		jp	nz,gq1
		ret


; Линейный катящийся враг: при задержке вывода выбрать промежуточную позу
; на его же траектории, не дальше трёх пикселей от нарисованной. ОЗУ игры не меняется.
rolling_pose:	ld	a,(band_candidate)
		or	a
		ret	z
		ld	a,l
		and	0x70
		cp	32
		ret	c
		push	hl
		push	bc
		ld	c,a
		ld	l,a
		ld	a,(hl)
		or	a
		jp	z,rp_done
		inc	l
		ld	a,(de)
		cp	(hl)
		jp	nz,rp_done
		inc	l
		ld	b,(hl)
		ld	a,c
		or	0x82
		ld	l,a
		ld	a,(hl)
		sub	b
		jp	c,rp_left
		cp	4
		jp	c,rp_done
		cp	9
		jp	nc,rp_done
		ld	a,b
		add	a,3
		jp	rp_set
rp_left:	cpl
		inc	a
		cp	4
		jp	c,rp_done
		cp	9
		jp	nc,rp_done
		ld	a,b
		sub	3
rp_set:		ld	(hl),a
rp_done:	pop	bc
		pop	hl
		ret
