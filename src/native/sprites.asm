; Объекты игры 7300 в порядке 72E0: постоянные дескрипторы слоёв с сохранением фона
; в невидимой плоскости (ячейка SPR_SLOTS + 256 * номер). Кадр: spr_plan (какие перерисовать: изменённые,
; под изменёнными клетками, пересекающие их) -> spr_restore (фон назад, 0..) -> вывод клеток -> spr_draw
; (отмеченные, с последнего: меньший номер сверху). Неизменённые спрайты не трогаются — не мерцают. Спрайт — до 3 столбцов x 3 плоскости вертикальных полос по 16 строк. Маски столбцов
; (sm_or[3][16]) считаются один раз на спрайт; AND-плоскости берут инверсию на лету. Полосы — развёрнутые блоки,
; адреса входа (по числу строк) подставляются в команды CALL (самоизменяемый код). Спрайт с тем же (X, Y), что
; у нарисованного перед ним, фон не сохраняет (слои героя). В прежнем поле Y=D0 — конец; NES_FULL скрывает свободные слоты цветом 0.
SM_OFS		equ	0xD0			; маски столбцов в ячейке спрайта (фон — до 3 x 3 x 23 = CF)
T0_U		equ	3			; единиц (256 тактов) от прерывания до первой группы
MA_U		equ	3			; запас «до луча»
MB_U		equ	2			; запас «после луча»
DL_N		equ	11			; ожидание: витков на единицу
SV_MAX		equ	16			; строк в области фона: только враги (16 строк спрайта; по всем комнатам st_rows ≤ 14). Джо — свой путь (joe_restore_sp)
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

spr_plan:
 xor a
 ld (jn_hold),a
 IFNDEF NES_FULL
 ld a,(nmi_pend)
 or a
 ld a,3
 jp z,spl_limit
 dec a
spl_limit:
 ld (spl_dx+1),a
 ld (spl_dy+1),a
 ENDIF
		ld	hl,0x0101
		ld	(cover_moves),hl
		ld	(cover_moves+2),hl
		ld	(cover_moves+4),hl
		xor	a
 IFNDEF NES_FULL
		ld	(obj_end),a
 ENDIF
 call joe_attrs
		ld	hl,spr_rec+33		; DE -> атрибуты, L = 16 * k + 1
		ld	b,SPR_MAX-2
spl0:		ld	a,SPR_MAX
		sub	b
		call	obj_ptr
 IFNDEF NES_FULL
		ld	a,(obj_end)
		or	a
		jp	nz,spl_end
		ld	a,(de)
		cp	0xD0
		jp	nz,spl_c
		ld	a,1
 IFNDEF NES_FULL
		ld	(obj_end),a
 ENDIF
spl_end:	ld	de,spl_z
 ENDIF
spl_c:
 IFDEF NES_FULL
spl_band_y:
 ld a,(spr_force)
 or a
 jp nz,spl_ch
 push hl
 ld a,SPR_MAX
 sub b
 call pace_age
 pop hl
 cp PACE_ENEMY_PERIOD
 jp c,spl_unchanged
 ELSE
spl_band_y:	ld	a,(spr_force)
		or	a
		jp	nz,spl_ch
		ld	a,SPR_MAX
		sub	b
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
 ENDIF
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
spl_unchanged:
		ld	a,l			; без изменений: метка 0
		and	0xF0
		or	13
		ld	l,a
		ld	(hl),0
		jp	spl_n
spl_cp:		pop	de
spl_ch:
 push hl
 call band_invalidate_y
 pop hl
		ld	a,l
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
 ld a,SPR_MAX
 sub b
 cp 2
 jp c,spl_n
		call	rolling_pose
		ld	a,(de)			; виден: Y + 1 < 192, цвет без EC и не 0
		inc	a
		cp SCREEN_HEIGHT
		jp nc,spl_inv
 IFDEF NES_FULL
 cp HUD_ROWS*8-15
 jp c,spl_inv
 ENDIF
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
 IFDEF NES_FULL
 cp HUD_ROWS
 jp nc,spl_full_top
 ld a,HUD_ROWS
spl_full_top:
 ENDIF
		ld (hl),a
		inc l
		ld a,c
		add a,15
		rrca
		rrca
		rrca
		and	0x1F
		cp	SCREEN_ROWS
		jp	c,spl2
		ld	a,SCREEN_ROWS-1
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
		call joe_plan
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
; Slot 1 is logical metadata only; pending background bits cannot resurrect it.
 ld a,(spr_rec+29)
 ld hl,spr_rec+13
 or (hl)
 ld (hl),a
 xor a
 ld (spr_rec+29),a
 ld (spr_rec+31),a
 ld (spr_new+16),a
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
st_or equ st_rs
st_and equ st_rs
st_sv equ st_rs
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
 ld a,b
 or a
 jp z,joe_restore
 jp enemy_restore

; --- spr_prep: для отмеченных видимых — обрезка, маски (в ячейку +C0), место; в spr_new: +9 L, +10 столбец,
; +11 строк, +12 пустые столбцы, +13 цвет (индекс), +14 рисовать. Всё долгое — до ожидания кадра.
spr_prep:
 ld a,(ml_n)
 ld b,a
 ld hl,ml
pp0:
 push bc
 push hl
 ld b,(hl)
 ld a,b
 ld (sp_k),a
 call rec_ptr
 ld de,13
 add hl,de
 ld a,(hl)
 or a
 jp z,pp9
 inc l
 inc l
 ld a,(hl)
 or a
 jp z,pp9
 ld (hl),0
 ld a,b
 call new_ptr
 push hl
 ld de,14
 add hl,de
 ld (hl),0
 pop hl
 ld a,(hl)
 or a
 jp z,pp9
 ld a,b
 or a
 jp z,pp_hero
 inc hl
 call enemy_prepare
 jp pp9
pp_hero:
 call joe_prepare
pp9:
 pop hl
 pop bc
 inc l
 dec b
 jp nz,pp0
 ret

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
		ld	a,SCREEN_HEIGHT
		sub	b
		cp	16
		jp	c,so0
		ld	a,16
so0:		ld	(st_rows),a
		ld	a,(sp_y)
		ld	b,a
		IFDEF NES_FULL
		ld a,SCREEN_TOP-FIELD_YSHIFT
		ELSE
		ld	a,SCREEN_TOP
		ENDIF
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
sd8:		ld a,(sp_k)
 or a
 call z,joe_copy_second
		pop	bc
		ret

; spr_put: спрайт sp_k по заготовкам (spr_ready). Не слой (new +15 = 0): фон области svr[k] — в ячейку,
; запись := нарисован с фоном, rst[k] — для восстановления; слой (+15 = 1) — только рисование поверх.
spr_put:
 ld a,(sp_k)
 ld b,a
 add a,SPR_SLOTS/256
 ld (sp_mpage),a
 ld a,b
 call rec_ptr
 ld (hl),1
 call cover_set
 ld a,l
 add a,14
 ld l,a
 ld (hl),2
 ld a,b
 or a
 jp nz,enemy_native_put
 ld (hl),1
 jp joe_put

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
 IFDEF NES_ENEMY_SEEDS
 call nes_seed_masks
 ret z
 ENDIF
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
smk1:
 IFDEF NES_FULL
 ld a,(sp_line)
 ld b,a
 ENDIF
smk_row:	ld	a,(hl)
 IFDEF NES_FULL
smk_rotate0:
 jp smk_rotate0_end
 REPT 7
 rrca
 ENDR
smk_rotate0_end:
 ELSE
		call	rotate_byte
 ENDIF
		ld	c,a
smk_m0:		and	0
		ld	(de),a			; столбец 0 = r0 & m
		ld	a,e
		add	a,16
		ld	e,a
		ld	a,c
smk_n1:		and	0
		ld	(de),a			; столбец 1 (пока) = r0 & ~m
		ld a,l
		add a,16
		ld l,a
		ld	a,(hl)
 IFDEF NES_FULL
smk_rotate1:
 jp smk_rotate1_end
 REPT 7
 rrca
 ENDR
smk_rotate1_end:
 ELSE
		call	rotate_byte
 ENDIF
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
		ld a,l
		sub 15
		ld l,a
 IFDEF NES_FULL
 dec b
 jp nz,smk_row
 ELSE
		ld	a,(sp_line)
		dec	a
		ld	(sp_line),a
		jp	nz,smk1
 ENDIF
		ret
; mk_cmp: A — с (HL): другое — (HL) := A, C += 1; HL += 1
mk_cmp:		cp	(hl)
		jp	z,mkc1
		ld	(hl),a
		inc	c
mkc1:		inc	l
		ret
smz:
 IFDEF NES_FULL
 ld a,(sp_line)
 ld b,a
 ENDIF
smz1:		ld	a,(hl)
		ld	(de),a
		ld a,l
		add a,16
		ld l,a
		ld	a,e
		add	a,16
		ld	e,a
		ld	a,(hl)
		ld	(de),a
		ld a,l
		sub 15
		ld l,a
		ld	a,e
		sub	15
		ld	e,a
 IFDEF NES_FULL
 dec b
 jp nz,smz1
 ELSE
		ld	a,(sp_line)
		dec	a
		ld	(sp_line),a
		jp	nz,smz1
 ENDIF
		ret

; Начальное состояние масок слоёв Джо; таблицы поворота больше не нужны.

; trim_sprite: по spr_trim[имя] — sm_off (первая строка), sv_lo, st_rows (строк — с учётом нижнего края),
; sv_zc (столбец 0 пуст — левая половина пуста; 2 — правая пуста или X кратен 8). Z — спрайт пуст.
trim_sprite:
		ld	a,(sp_name)		; имя кратно 4 -> запись по 4 байта: имя
 IFDEF NES_FULL
 cp 128                    ; upper records were empty: native Joe bypasses this table
 jp c,ts_trim_lookup
 xor a                     ; Z = empty, including every discarded high record
 ret
ts_trim_lookup:
		ld	l,a
		ld	h,spr_trim/256     ; page-aligned table: no 16-bit base addition
 ASSERT (spr_trim&255) == 0
 ELSE
		ld	l,a
		ld	h,0
		ld	de,spr_trim
		add	hl,de
 ENDIF
		ld	a,(hl)			; первая
		cp	0xFF
		ret	z
 IFDEF NES_FULL
 ld b,a
 ld a,(sp_y)
 ld c,a
 ld a,HUD_ROWS*8
 sub c
 jp c,ts_full_ready
 cp b
 jp c,ts_full_ready
 ld b,a
ts_full_ready:
 ld a,b
 ENDIF
		ld (sm_off),a
		ld b,a
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
ck_count:
 IFDEF NES_FULL
 call pace_charge
 ELSE
 ld a,b
 or a
 ld a,1
 jp nz,ck_units
 ld a,4
 ENDIF
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
 IFDEF NES_FULL
ck_limit:
 cp PACE_BUDGET
 ELSE
		cp	4
 ENDIF
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
cr0:
 IFDEF NES_FULL
 ld a,(cr_c0)
 ld c,a
 ld a,(cr_r)
 call nf_row_addr
 ld a,h
 add a,(PND-VNT)/256
 ld h,a
 ELSE
		ld	a,(cr_r)		; HL = PND + 32 r + c0
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
 ENDIF
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
ps_names:
 IFDEF NES_FULL
 ; The NES start and most rooms use the two spider poses. Cache them before
 ; the eight rolling-skull poses when the full room pack reduces free RAM.
 ; Only these four poses obtain masks with this room/art budget. The other
 ; rolling-skull poses retain their original source and the uncached path.
 db 0x2C,0x30,0x0C,0x14,0xFF
 ELSE
 db 0x0C,0x10,0x14,0x18,0x1C,0x20,0x24,0x28,0x2C,0x30,0x68,0x78,0xFF
 ENDIF
 IFDEF NES_FULL
PS_N equ 4
 ELSE
PS_N equ 12
 ENDIF
 IFDEF NES_ENEMY_SEEDS
PS_SHIFTS equ 4
PS_SEED_POSES equ 4
 ELSE
PS_SHIFTS equ 8
 ENDIF
; ps_find: для спрайта sp_k — враг (цвет не 6, 11) с готовыми сдвигами: ps_lo/hi/r[k] := блок, R; Z.
; Иначе ps_hi[k] := 0, NZ
ps_find:	ld	a,(sp_k)
		add	a,ps_hi&0xFF
		ld	l,a
		ld	h,ps_hi/256
		ld	(hl),0
 IFDEF NES_ENEMY_SEEDS
 ld a,(sp_x)
 and 1
 jp nz,psf_n
 ENDIF
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
		ld b,(hl)			; B = R
 IFDEF NES_FULL
 ld a,(st_rows)
 cp b
 jp nz,psf_n
 ENDIF
		ld	a,c			; ps_tab + 2 * (PS_SHIFTS * name + shift index)
		add	a,a
		add	a,a
 IFNDEF NES_ENEMY_SEEDS
		add	a,a
 ENDIF
		ld	l,a
		ld	a,(sp_x)
		and	7
 IFDEF NES_ENEMY_SEEDS
 rrca
 ENDIF
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
 ld de,joe_attr_source
 ld hl,0xF500
 ld bc,joe_attr_end-joe_attr_source
 call copy_de_hl
 IFDEF STRICT
 ld de,joe_latch_source
 ld hl,0xF600
 ld bc,joe_latch_end-joe_latch_source
 call copy_de_hl

 ENDIF

 IFNDEF NES_STABLE_COLORS
 ld de,joe_source0
 ld hl,joe_runtime0
 ld bc,joe_end0-joe_source0
 call copy_de_hl
 ld de,joe_source1
 ld hl,0xFC30
 ld bc,joe_end1-joe_source1
 call copy_de_hl
 ld de,joe_source2
 ld hl,joe_runtime2
 ld bc,joe_end2-joe_source2
 call copy_de_hl
 ELSE
 ; Install the bonus-only palette code in the unused sprite-record tail.
 ; Legacy high-RAM restore destinations hold permanent colour art.
 ld de,nt_bonus_palette_source
 ld hl,nt_bonus_palette
 ld bc,nt_bonus_palette_end-nt_bonus_palette
 call copy_de_hl
joe_load_done:
 ENDIF
 ret
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

mask_keys_init:
 ld hl,mk_key
 ld bc,4*SPR_MAX
 ld e,0xFF
 call memfill
 ld hl,jn_key
 ld bc,5
 jp memfill

; --- обрезка по шаблону: spr_trim[имя/4] = (первая строка, последняя, пустые половины: бит 0 — левая, 1 — правая);
; строка пуста, если пусты обе половины; всё пусто — первая = FF. Пересчёт — trim_build (при смене комнаты).
trim_build:
		ld	de,spr_trim
 IFDEF NES_FULL
SPR_TRIM_COUNT equ 32
 ELSE
SPR_TRIM_COUNT equ 64
 ENDIF
		ld	c,SPR_TRIM_COUNT
tb0:		ld	a,SPR_TRIM_COUNT
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
 ; Allocation cursors are temporary; the runtime live list later owns FF80.
 IFDEF STRICT
 ld de,ps_rg
 ld hl,0xFF80
 ld bc,ps_rg_end-ps_rg
 call copy_de_hl
 ENDIF
		ld	hl,ps_names
		ld	c,0
pbd0:
 IFDEF NES_ENEMY_SEEDS
 ld a,c
 cp PS_SEED_POSES
 ret z
 ENDIF
		ld	a,(hl)
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
 IFNDEF NES_ENEMY_SEEDS
		add	a,a
 ENDIF
		ld	b,a
		ld	a,(ps_s)
 IFDEF NES_ENEMY_SEEDS
 rrca
 ENDIF
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
 IFDEF NES_ENEMY_SEEDS
 inc a
 ENDIF
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
 IFDEF STRICT
ps_alloc:	ld	c,a
 ; First fit retains small tails for later, shorter source frames.
 ld hl,0xFF80
 ld (ps_rp),hl
 call ps_nrg
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
 push hl
 ld hl,(ps_rp)
 dec hl
 dec hl
 dec hl
 dec hl
 ld (hl),e
 inc hl
 ld (hl),d
 pop hl
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
 ELSE
ps_alloc: jp nes_ps_alloc
ps_nrg: ret
 ENDIF
		ENT
ps_boot_source_end:
		ASSERT ps_boot_source_end-ps_boot_source < 24*TILE_CAP
; свободные места (начало, конец): невидимая плоскость — бывший кэш тайлов, затем основная память
 IFDEF STRICT
ps_rg:		dw	PS_MORE, 0x7000, sprite_sources_end, 0x7B00, 0x7B80, VNT, 0xEB40, 0xEC00, 0xEF00, 0xF000, 0xF600+joe_latch_end-joe_latch_source, 0xF820, ps_heap, PS_TOP, ps_boot_source+125, ps_boot_source_end, sprt_end, 0x6800, 0x6660, 0x6680, JOE_PICTURE+12*joe_nes_rows, JOE_BACKGROUND, JOE_BACKGROUND+9*joe_nes_rows, 0xFB00, 0xFBD0, 0xFBD0, 0xFC30+joe_end1-joe_source1, 0xFCD0, joe_runtime2+joe_end2-joe_source2, 0xFDD0, 0xFE30, 0xFED0, 0, 0	; 0 — места нет
 ENDIF
ps_rg_end:
 IFDEF STRICT
 ASSERT ps_rg_end-ps_rg <= 128
 ENDIF


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
cover_row:
 IFDEF NES_FULL
 push bc
 ld c,b
 ld a,d
 call nf_row_addr
 pop bc
 ld a,h
 add a,(PND-VNT)/256
 ld h,a
 ELSE
	ld	a,d
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
 ENDIF
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
 IFDEF NES_FULL
 sub 6
 cp 20
 ELSE
 cp 64
 ENDIF
 ld hl,shape_00
 ret nc
		ld	l,a
		ld	h,sprite_sources/256
		ld	a,(hl)
		inc	l
		ld	h,(hl)
		ld	l,a
		ret


; Нативный враг: дескриптор — L, столбец, строки, пустые столбцы; без PPS/PPD/RST.
enemy_native_put:
 IFDEF NES_FULL
 call enemy_ink_plane
 ld (en_paint_plane+1),a
 ENDIF
 ld a,l
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
		; entry = mix + step*(16-rows); keep unrolled bodies for speed
		ld	a,(en_reuse)
		or	a
		ld	hl,enemy_mix
		ld	de,8
		jp	z,en_mix_base
		ld	hl,enemy_repaint_mix
		ld	de,6
en_mix_base:	ld	a,(st_rows)
		ld	b,a
		ld	a,16
		sub	b
		jp	z,en_mix_set
en_mix_mul:	add	hl,de
		dec	a
		jp	nz,en_mix_mul
en_mix_set:	ld	(en_mix_call+1),hl
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
en_paint_plane:
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
 IFDEF NES_FULL
 call enemy_ink_plane
 ld (en_restore_plane+1),a
 ENDIF
		ld	a,l
		add	a,9
		ld	l,a
		call	en_load
		ld a,(st_rows)
 add a,a
 add a,a
 ld e,a
 ld hl,st_rs+4*SV_MAX
 ld a,l
 sub e
 ld l,a
 ld a,h
 sbc a,0
 ld h,a
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
en_restore_plane:
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

 IFDEF NES_FULL
NES_GREEN_SPIDERS equ 1
; HL points anywhere in an old/current record. Select its saved/rendered plane.
; Both spider poses stay one-plane sprites (8000); shared white skulls use C000.
enemy_ink_plane:
 push hl
 ld a,l
 and 0xF0
 or 3
 ld l,a
 ld a,(hl)
 sub 0x2C
 cp 8
 sbc a,a
 and 0x40
 xor 0xC0
 pop hl
 ret
 ENDIF

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
 IFDEF NES_FULL
 ; The startup builder keeps using rotate_byte. Runtime mask rows enter
 ; their own inline chains, avoiding CALL/RET for both halves of every row.
 push de
 ld de,smk_rotate0_end-rotate_0
 add hl,de
 ld (smk_rotate0+1),hl
 ld de,smk_rotate1_end-smk_rotate0_end
 add hl,de
 ld (smk_rotate1+1),hl
 pop de
 ENDIF
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
		cp	SCREEN_ROWS
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
sc_row:
 IFDEF NES_FULL
 push bc
 ld a,(sv_col)
 ld c,a
 ld a,d
 call nf_row_addr
 pop bc
 ld a,h
 add a,(PND-VNT)/256
 ld h,a
 ELSE
		ld	a,d
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
 ENDIF
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
 ld a,2
 ld (cu_i),a
bb_i:		ld	a,(cu_i)
		call	ub_ld
		ld	a,(cu_i)
		inc	a
		ld	(cu_j),a
bb_j:
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
band_check:
 call band_joe_check
 ld (band_ok),a
 or a
 ret z
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

band_marked:
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

band_emit:
 IFNDEF STRICT
 call nes_service
 ENDIF
 IFDEF NES_FULL
 ; Independent bands can be ordered by current age, without touching unions.
 call band_marked
 call sort_marked
 ld de,cr_list
 ld hl,ml
 ld a,(ml_n)
 ld b,a
 ELSE
		ld	de,cr_list
		ld	hl,band_order
		ld	b,SPR_MAX
 ENDIF
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
be_hero: ld b,0
 ld a,1
 call band_emit_one
 ld a,2
 call band_emit_one
 ld a,3
 call band_emit_one
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
		call	sort_r0
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
		call	sort_r0
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


sort_r0:
 IFDEF NES_FULL
 jp pace_priority
 ELSE
 cp 2
 jp nc,ub_r0
 xor a
 ret
 ENDIF

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
