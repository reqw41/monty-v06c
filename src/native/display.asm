; Прямой вывод карты и объектов на экран Вектора.
; video_dirty: комната, её цвета, кадры огня/лент; PND/dlist: изменённые клетки.
; spr_rec/spr_new и таблицы полос — постоянные дескрипторы слоёв объектов.

; disp_prep: всё, кроме короткой части: клетки (кроме тех, что под перерисовываемыми спрайтами), план
; спрайтов; crit_pend := 1, если после прерывания нужна короткая часть (crit)
disp_prep:
		ld	a,(video_enabled)
		or	a
		ret	z
		xor	a
		ld	(drew_any),a
		ld	a,(video_dirty)
		and	DIRTY_ROOM			; новая комната: дождаться конца рисования (2 кадра без очистки)
		jp	z,dp1
		ld	hl,nt_age
		ld	a,(hl)
		inc	(hl)
		cp	2
		ret	c
		call	room_redraw
dp1:		ld	a,(lv_dirty)		; в клетки ставились живые тайлы — список живых клеток заново
		or	a
		jp	z,dp1a
		xor	a
		ld	(lv_dirty),a
		call	live_build
dp1a:		xor	a
		ld	(fire_ran),a
		ld	hl,enemy_turn
		inc	(hl)
		ld	a,(hl)
		cp	3
		jp	c,dp_phase
		ld	(hl),0
dp_phase:	ld	a,1			; до dp3 (кадры огня и лент) у живых клеток меняются только точки
		ld	(dc_pt),a
		ld	a,(video_dirty)
		and	DIRTY_COLOR
		jp	nz,dp_color_first
		ld	a,(video_dirty)
		and	DIRTY_BELT
		jp	z,dp_fire_new
		ld	a,(belt_frame)
		ld	hl,belt_shown
		cp	(hl)
		jp	nz,dp2
dp_fire_new:	ld	a,(video_dirty)
		and	DIRTY_FIRE			; фаза анимации
		jp	z,dp2
		ld	a,(video_dirty)
		and	0xFF-DIRTY_FIRE
		ld	(video_dirty),a
		ld	a,(fire_frame)
		ld	hl,fire_shown
		cp	(hl)
		jp	z,dp2
		ld	(fire_next),a
		call	fire_changes		; tile_changed: тайлы, у которых меняется исходная полоса
		ld	a,(fire_next)
		ld	(fire_shown),a
		ld	a,(fl_ph)		; их живые клетки — к перерисовке, но не все: каждая FIRE_K-я по очереди
		inc	a			; (огонь мигает вразнобой; дешевле в FIRE_K раз). FIRE_K и число кадров
		cp	FIRE_K			; огня (4) — взаимно простые: каждая клетка проходит все кадры
		jp	c,dpf1
		xor	a
dpf1:		ld	(fl_ph),a
		ld	(fl_c),a
		ld	a,1
		ld	(fire_ran),a
		ld	(fl_skm),a
		ld	a,tile_changed/256
		call	force_live_t
		xor	a
		ld	(fl_skm),a
		ld	hl,anim_set		; tile_changed := 0
bdz:		ld	a,(hl)
		cp	0xFF
		jp	z,dp2
		push	hl
		ld	l,a
		ld	h,tile_changed/256
		ld	(hl),0
		pop	hl
		inc	hl
		jp	bdz
dp_color_first:	xor	a
		ld	(dc_pt),a
		ld	a,(video_dirty)
		and	0xFF-DIRTY_COLOR
		ld	(video_dirty),a
		call	room_color_changes
		ld	a,1
		ld	(dc_pt),a
		jp	dp2
dp2:		ld	a,(fire_ran)
		or	a
		jp	nz,dp3
		ld	a,(video_dirty)
		and	DIRTY_BELT
		jp	z,dp3
		ld	a,(video_dirty)
		and	0xFF-DIRTY_BELT
		ld	(video_dirty),a
		ld	a,(belt_frame)
		ld	hl,belt_shown
		cp	(hl)
		jp	z,dp3
		ld	(hl),a
		ld	a,1
		ld	(tile_changed+0xE0),a
		ld	(tile_changed+0xE8),a
		ld	a,tile_changed/256
		call	force_live_t
		xor	a
		ld	(tile_changed+0xE0),a
		ld	(tile_changed+0xE8),a
dp3:		xor	a
		ld	(dc_pt),a
		ld	a,(fire_ran)
		or	a
		jp	nz,dp4
		ld	a,(video_dirty)
		and	DIRTY_COLOR
		jp	z,dp4
		ld	a,(video_dirty)
		and	0xFF-DIRTY_COLOR
		ld	(video_dirty),a
		call	room_color_changes
dp4:
		call	spr_plan		; какие спрайты перерисовать (A — сколько)
		ld	c,a
		ld	a,(dl_n)		; изменённые клетки есть?
		ld	b,a
		ld	a,(dl_ovf)
		or	b
		or	c
		ret	z
		ld	a,c
		or	a
		jp	z,draw_list		; спрайты не трогаем — только клетки
		call	spr_prep		; маски и места новых — заранее
		xor	a
		ld	(ex_any),a
		ld	a,(dl_n)
		ld	b,a
		ld	a,(dl_ovf)
		or	b
		jp	z,dp_no_cells
		call	ex_build		; клетки под прежними местами отмеченных — отложить
		xor	a
		ld	(ex_any),a
		ld	a,1
		ld	(dr_ex),a
		call	draw_list
		xor	a
		ld	(dr_ex),a
dp_no_cells:	call	crit_plan		; группы и порядок — тоже до ожидания
		ld	a,1			; короткая часть — сразу после прерывания кадра (crit)
		ld	(crit_pend),a
		ret

; ex_build: ex_r — прямоугольники (r0, r1, c0, c1) прежних мест нарисованных отмеченных спрайтов, ex_n штук
ex_build:
		ld	de,ex_r
		ld	b,0
		ld	c,0
eb0:		ld	a,b
		call	rec_ptr
		ld	a,(hl)
		or	a
		jp	z,eb9
		push	hl
		push	de
		ld	de,13
		add	hl,de
		ld	a,(hl)
		pop	de
		pop	hl
		or	a
		jp	z,eb9
		inc	hl
		inc	hl
		inc	hl
		inc	hl
		inc	hl
		REPT	4
		ld	a,(hl)
		ld	(de),a
		inc	hl
		inc	de
		ENDR
		inc	c
eb9:		inc	b
		ld	a,b
		cp	SPR_MAX
		jp	nz,eb0
		ld	a,c
		ld	(ex_n),a
		ld	hl,ex_r			; общая рамка: r0 мин., r1 макс., c0 мин., c1 макс.
		ld	de,0xFF00
		ld	bc,0xFF00
		ld	a,(ex_n)
		or	a
		jp	z,ebb9
ebb0:		push	af
		ld	a,(hl)
		cp	d
		jp	nc,ebb1
		ld	d,a
ebb1:		inc	hl
		ld	a,(hl)
		cp	e
		jp	c,ebb2
		ld	e,a
ebb2:		inc	hl
		ld	a,(hl)
		cp	b
		jp	nc,ebb3
		ld	b,a
ebb3:		inc	hl
		ld	a,(hl)
		cp	c
		jp	c,ebb4
		ld	c,a
ebb4:		inc	hl
		pop	af
		dec	a
		jp	nz,ebb0
ebb9:		ld	a,d
		ld	(ex_bb),a
		ld	a,e
		ld	(ex_bb+1),a
		ld	a,b
		ld	(ex_bb+2),a
		ld	a,c
		ld	(ex_bb+3),a
		ret

et_no:		or	a
		ret
; ex_test: строка rr_r, столбец C — в одном из ex_r? CY — да (HL, DE, B портятся)
ex_test:
		ld	a,(ex_n)
		or	a
		ret	z
		ld	b,a
		ld	a,(rr_r)		; вне общей рамки — сразу нет
		ld	hl,ex_bb
		cp	(hl)
		jp	c,et_no
		inc	hl
		ld	d,(hl)
		cp	d
		jp	z,et_r
		jp	nc,et_no
et_r:		inc	hl
		ld	a,c
		cp	(hl)
		jp	c,et_no
		inc	hl
		ld	d,(hl)
		cp	d
		jp	z,et_c
		jp	nc,et_no
et_c:
		ld	hl,ex_r
		ld	a,(rr_r)
		ld	d,a
et0:		ld	a,d			; r0 <= r <= r1, c0 <= c <= c1
		cp	(hl)
		jp	c,et8
		inc	hl
		ld	a,(hl)
		cp	d
		jp	c,et7
		inc	hl
		ld	a,c
		cp	(hl)
		jp	c,et6
		inc	hl
		ld	a,(hl)
		cp	c
		jp	c,et5
		scf
		ret
et8:		inc	hl
et7:		inc	hl
et6:		inc	hl
et5:		inc	hl
		dec	b
		jp	nz,et0
		or	a
		ret

; room_redraw: таблица анимации, палитра, всё к перерисовке
room_redraw:
		call	band_room_init
		ld	a,(belt_frame)
		ld	(belt_shown),a
		ld	a,1
		ld	(spr_force),a
		ld	hl,tile_changed
		ld	bc,256
		ld	e,0
		call	memfill_f
		ld	a,(fire_frame)			; кадр анимации
		ld	(fire_shown),a
		call	pal_build
		call	pal_fill
		call	group_modes_build
		call	tiles_reset
		ld	a,3
		ld	(pal_load),a
		call	draw_all		; комната — целиком, прямо (спрайты — стёрты: их не восстанавливать)
		ld	a,(video_dirty)
		and	0xFF-DIRTY_ROOM-DIRTY_COLOR
		ld	(video_dirty),a
		call	live_build
		xor	a
		ld	(lv_dirty),a
		jp	room_color_snapshot

; Живые клетки (анимированные тайлы anim_set и лента/цепь E0-EF) — по корзинам тайлов: lv_idx[тайл] = корзина
; (0..32) или FF; корзина b — элементы с lv_beg[b] по lv_beg[b + 1] - 1: адрес клетки в VNT — младший байт
; в live_list, старший — в live_hi (до LIVE_N клеток; в комнатах — до 189).
LIVE_N		equ	250
FIRE_K		equ	3			; огонь: при смене кадра — каждая FIRE_K-я клетка (по очереди)
live_hi		equ	0xF100			; (бывшие флаги анимации тайлов — не читались)
LV_N		equ	33
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

; live_build: корзины живых клеток комнаты (два прохода по VNT: подсчёт, раскладка)
live_build:
		ld	hl,lv_pos		; счётчики := 0
		ld	b,LV_N
		xor	a
lbz:		ld	(hl),a
		inc	hl
		dec	b
		jp	nz,lbz
		ld	hl,VNT
		ld	d,lv_idx/256
lb1:		ld	e,(hl)
		ld	a,(de)
		cp	0xFF
		jp	z,lb2
		push	hl
		ld	hl,lv_pos
		call	add_hl_a
		inc	(hl)
		pop	hl
lb2:		inc	hl
		ld	a,h
		cp	(VNT+768)/256
		jp	nz,lb1
		ld	hl,lv_pos		; начала: lv_beg[b] = сумма (не больше LIVE_N), lv_pos := lv_beg
		ld	de,lv_beg
		ld	b,LV_N
		ld	c,0
lb3:		ld	a,c
		ld	(de),a
		ld	a,(hl)
		ld	(hl),c
		add	a,c
		cp	LIVE_N
		jp	c,lb4
		ld	a,LIVE_N
lb4:		ld	c,a
		inc	hl
		inc	de
		dec	b
		jp	nz,lb3
		ld	a,c
		ld	(de),a			; lv_beg[LV_N] — всего
		ld	hl,VNT			; раскладка
lb5:		ld	e,(hl)
		ld	d,lv_idx/256
		ld	a,(de)
		cp	0xFF
		jp	z,lb7
		push	hl
		ld	e,a
		ld	hl,lv_beg+1		; конец корзины
		call	add_hl_a
		ld	c,(hl)
		ld	a,e
		ld	hl,lv_pos
		call	add_hl_a
		ld	a,(hl)
		cp	c
		jp	nc,lb6			; корзина полна (предел LIVE_N)
		inc	(hl)
		ld	e,a			; адрес клетки: младший — live_list, старший — live_hi
		ld	d,live_list/256
		pop	hl
		push	hl
		ld	a,l
		ld	(de),a
		ld	d,live_hi/256
		ld	a,h
		ld	(de),a
		push	bc
		ld	a,l
		and	0xE0
		rrca
		rrca
		ld	b,a
		ld	a,h
		rrca
		rrca
		and	0xC0
		or	b
		cpl
		add	a,0xE0
		ld	d,live_scr_lo/256
		ld	(de),a
		pop	bc
lb6:		pop	hl
lb7:		inc	hl
		ld	a,h
		cp	(VNT+768)/256
		jp	nz,lb5
		ld	hl,lv_beg		; непустые корзины -> lv_pos (номера), lv_nn — сколько
		ld	de,lv_pos
		ld	bc,0
lbn:		ld	a,(hl)
		inc	hl
		cp	(hl)
		jp	z,lbn1
		ld	a,b
		ld	(de),a
		inc	de
		inc	c
lbn1:		inc	b
		ld	a,b
		cp	LV_N
		jp	nz,lbn
		ld	a,c
		ld	(lv_nn),a
		ret

force_live_t:
		ld	(fl_pg),a
		ld	a,(lv_nn)
		or	a
		ret	z
		ld	b,a
		ld	hl,lv_pos
flt1:		ld	c,(hl)			; корзина (из непустых)
		push	hl
		push	bc
		ld	b,0
		ld	hl,lv_tile
		add	hl,bc
		ld	e,(hl)			; флаг тайла корзины
		ld	a,(fl_pg)
		ld	d,a
		ld	a,(de)
		or	a
		jp	z,flt3
		ld	(fl_color_pm+1),a
		ld	a,e
		ld	(rr_t),a
		ld	c,LV_N
		add	hl,bc			; lv_beg[b]: с, по
		ld	c,(hl)
		inc	hl
		ld	a,(hl)
		sub	c
		jp	z,flt3
		ld	(fl_n),a
		push	bc			; C — позиция
		call	tile_ready
		ld	(tile_src),hl
		ld	a,(rr_t)
		rrca
		rrca
		rrca
		and	31
		ld	hl,group_modes
		call	add_hl_a
		ld	c,(hl)
		ld	a,0x15
		ld	b,a
		ld	a,(dc_pt)
		or	a
		jp	z,fl_color_pm
		ld	a,c
		rrca
		xor	c
		and	b
flt4:		rlca
		rlca
		rlca
		jp	fl_pm_ready
fl_color_pm:	ld	a,0xA8
fl_pm_ready:	ld	(fl_pm),a
		call	fl_select
		pop	bc
		or	a
		jp	z,flt3
		ld	a,c
		ld	hl,fl_n
		add	a,(hl)
		ld	(fl_end),a
		ld	a,1
		ld	(fl_stride+1),a
		ld	a,(fl_skm)
		or	a
		jp	z,fl_begin
		ld	a,(rr_t)
		cp	0x38
		jp	z,fl_fire_setup
		cp	0xD0
		jp	c,fl_begin
fl_fire_setup:	ld	a,(fl_c)
		ld	b,a
		xor	a
		sub	b
		jp	nc,fl_first
		add	a,FIRE_K
fl_first:	add	a,c
		ld	c,a
		ld	a,(fl_n)
		add	a,b
fl_mod:		cp	FIRE_K
		jp	c,fl_mod_done
		sub	FIRE_K
		jp	fl_mod
fl_mod_done:	ld	(fl_c),a
		ld	a,FIRE_K
		ld	(fl_stride+1),a
		ld	a,(fl_end)
		cp	c
		jp	c,flt3
		jp	z,flt3
fl_begin:
flt2:		ld	l,c
		ld	h,live_list/256
		ld	e,(hl)
		ld	h,live_hi/256
		ld	d,(hl)
flt6:		ld	a,(de)			; в карте уже другой тайл (взят предмет и т. п.) — не наша клетка: её
		ld	hl,rr_t			; изменение и так в очереди
		cp	(hl)
		jp	nz,flt5
		ld	a,d			; PND: бит 0 — ждёт вывода, бит 1 — под спрайтом
		add	a,(PND-VNT)/256
		ld	h,a
		ld	l,e
		ld	a,(hl)
		or	a
		jp	z,flt9
fl_cover:	and	0x7E
		jp	nz,flt_q
		ld	a,(hl)
		and	1
		jp	z,flt9
		ld	a,(dc_pt)		; ждёт полного вывода: только точки — не здесь (она в списке)
		or	a
		jp	nz,flt5
		ld	(hl),0			; выведена
flt9:		ld	l,c
		ld	h,live_scr_lo/256
		ld	b,(hl)
		ld	a,e
		and	31
fl_hbase:	add	a,0x80
		ld	h,a
		ld	l,b
		ex	de,hl
		ld	hl,(tile_src)
		ex	de,hl
fl_write:	jp	fl_slow
fl_slow:	ld	a,(fl_pm)
		ld	b,a
flp0:		ld	a,b			; плоскость: бит 7 маски
		add	a,a
		ld	b,a
		jp	nc,flp2
		REPT	8
		ld	a,(de)
		ld	(hl),a
		inc	de
		dec	l
		ENDR
		ld	a,l
		add	a,8
		ld	l,a
flp1:		ld	a,b			; (пропуск бита между плоскостями)
		add	a,a
		ld	b,a
		jp	z,flp3
		ld	a,h
		add	a,0x20
		ld	h,a
		jp	flp0
flp2:		REPT	8
		inc	de
		ENDR
		jp	flp1
flp3:		jp	flt5
flt_q:		ld	a,(hl)
fl_qcover:	and	0x7E
		call	cover_dirty
		ld	a,(hl)			; под спрайтом — к выводу (PND), в список (после его стирания)
		rrca
		jp	c,flt5			; уже ждёт вывода — в списке есть
		inc	(hl)
		ld	a,(dl_n)
		cp	DL_MAX
		jp	nc,flt_o
		inc	a
		ld	(dl_n),a
		dec	a
		add	a,a
		ld	l,a
		ld	h,dlist/256
		ld	(hl),e
		inc	l
		ld	(hl),d
flt5:		ld	a,c
fl_stride:	add	a,1
		ld	c,a
		ld	hl,fl_end
		cp	(hl)
		jp	c,flt2
flt3:		pop	bc
		pop	hl
		inc	hl
		dec	b
		jp	nz,flt1
		ret
flt_o:		ld	a,1
		ld	(dl_ovf),a
		jp	flt5
; Частые наборы плоскостей: готовые входы без цикла и проверки маски на каждой клетке.
fl_select:	push	af
		ld	a,(fl_pm)
		and	0x80
		ld	a,6			; A000/C000 не затрагивают врагов, рисуемых только в 8000
		jp	z,fl_set_cover
		ld	a,0x7E
fl_set_cover:	ld	(fl_cover+1),a
		ld	(fl_qcover+1),a
		ld	a,0x80
		ld	(fl_hbase+1),a
		ld	a,(fl_pm)
		ld	hl,fl_fast3
		cp	0xA8
		jp	z,fl_sel_done
		ld	hl,fl_dual_same
		cp	0xA0
		jp	z,fl_sel_dual0
		cp	0x28
		jp	nz,fl_sel_slow
		ld	hl,(tile_src)
		ld	de,8
		add	hl,de
		ld	(tile_src),hl
		ld	a,0xA0
		ld	(fl_hbase+1),a
		ld	a,c
		rrca
		rrca
		xor	c
		and	3
		jp	fl_sel_dual
fl_sel_dual0:	ld	a,c
		rrca
		rrca
		xor	c
		and	12
fl_sel_dual:	ld	hl,fl_dual_same
		jp	z,fl_sel_done
		ld	hl,fl_dual_inv
		jp	fl_sel_done
fl_sel_slow:	ld	a,(fl_pm)
		cp	0x80
		jp	z,fl_sel_one
		ld	b,8
		ld	c,0xA0
		cp	0x20
		jp	z,fl_one_offset
		ld	b,16
		ld	c,0xC0
		cp	8
		jp	nz,fl_sel_generic
fl_one_offset:	ld	a,c
		ld	(fl_hbase+1),a
		ld	hl,(tile_src)
		ld	d,0
		ld	e,b
		add	hl,de
		ld	(tile_src),hl
fl_sel_one:	ld	hl,fl_fast1
		jp	fl_sel_done
fl_sel_generic:	ld	hl,fl_slow
fl_sel_done:	ld	(fl_write+1),hl
		pop	af
		ret

fl_fast1:
		REPT	8
		ld	a,(de)
		ld	(hl),a
		inc	de
		dec	l
		ENDR
		jp	flp3

fl_fast3:
		REPT	3
		REPT	8
		ld	a,(de)
		ld	(hl),a
		inc	de
		dec	l
		ENDR
		ld	a,l
		add	a,8
		ld	l,a
		ld	a,h
		add	a,0x20
		ld	h,a
		ENDR
		jp	flp3

; Две меняющиеся плоскости: одна исходная полоса, общий или обратный узор.
fl_dual_same:	push	bc
		ld	a,h
		add	a,0x20
		ld	b,a
		ld	c,l
		REPT	8
		ld	a,(de)
		ld	(hl),a
		ld	(bc),a
		inc	de
		dec	l
		dec	c
		ENDR
		pop	bc
		jp	flp3
fl_dual_inv:	push	bc
		ld	a,h
		add	a,0x20
		ld	b,a
		ld	c,l
		REPT	8
		ld	a,(de)
		ld	(hl),a
		cpl
		ld	(bc),a
		inc	de
		dec	l
		dec	c
		ENDR
		pop	bc
		jp	flp3

; Список изменённых тайлов на переход кадра построен генератором графики.
fire_changes:	ld	a,(fire_shown)
		add	a,a
		add	a,a
		ld	b,a
		ld	a,(fire_next)
		add	a,b
		add	a,a
		ld	hl,fire_transitions
		call	add_hl_a
		ld	e,(hl)
		inc	hl
		ld	d,(hl)
fd0:		ld	a,(de)
		cp	0xFF
		ret	z
		ld	l,a
		ld	h,tile_changed/256
		ld	(hl),1
		inc	de
		jp	fd0

; draw_all: все клетки на экран прямо по карте (графика — заново только при смене тайла подряд); спрайты —
; «не нарисованы» (экран под ними новый), очередь клеток и PND — пусто
draw_all:	ld	hl,spr_rec
dal0:		ld	(hl),0
		ld	a,l
		add	a,16
		ld	l,a
		cp	16*SPR_MAX
		jp	nz,dal0
		xor	a
		ld	(dl_n),a
		ld	(dl_ovf),a
		ld	(sprite_dirty),a
		ld	hl,PND
		ld	bc,768
		ld	e,0
		call	memfill_f
		ld	a,0xFF
		ld	(da_t),a
		ld	de,VNT			; DE — клетка карты, HL — экран (столбец 0, верх строки 0)
		ld	hl,0x80DF
dal2:		ld	a,(de)
		push	de
		push	hl
		ld	hl,da_t
		cp	(hl)
		jp	z,dal3
		ld	(hl),a			; другой тайл — образ заново
		ld	(rr_t),a
		call	tile_ready
		ld	(tile_src),hl
dal3:		pop	hl
		call	da_blit
		pop	de
		inc	de
		inc	h
		ld	a,h
		cp	0xA0
		jp	nz,dal2
		ld	h,0x80			; следующая строка
		ld	a,l
		sub	8
		ld	l,a
		ld	a,d
		cp	(VNT+768)/256
		jp	nz,dal2
		ld	hl,row_dirty
		ld	bc,24
		ld	e,0
		jp	memfill
; da_img: C = режимы, DE = графика -> (tile_dst): 3 плоскости по 8 байт (сверху вниз)
da_img:		ld	hl,(tile_dst)
		ld	a,c
		rrca
		rrca
		rrca
		rrca
		call	dai_p
		ld	a,c
		rrca
		rrca
		call	dai_p
		ld	a,c
dai_p:		and	3			; (циклы по 8 байт — развёрнуты)
		jp	z,dai0
		dec	a
		jp	z,daip
		dec	a
		jp	z,dain
		ld	a,0xFF
		jp	daif
dai0:		xor	a
daif:		REPT	8
		ld	(hl),a
		inc	hl
		ENDR
		ret
daip:		push	de
		REPT	8
		ld	a,(de)
		ld	(hl),a
		inc	hl
		inc	de
		ENDR
		pop	de
		ret
dain:		push	de
		REPT	8
		ld	a,(de)
		cpl
		ld	(hl),a
		inc	hl
		inc	de
		ENDR
		pop	de
		ret
; da_blit: готовые три плоскости -> HL, без запрета прерываний и смены SP.
da_blit:	push	hl
		ld	hl,(tile_src)
		ex	de,hl
		pop	hl
		REPT	3
		REPT	8
		ld	a,(de)
		ld	(hl),a
		inc	de
		dec	l
		ENDR
		ld	a,l
		add	a,8
		ld	l,a
		ld	a,h
		add	a,0x20
		ld	h,a
		ENDR
		ld	a,h
		sub	0x60
		ld	h,a
		ret

; force_tiles: A = старший байт таблицы флагов (256 байт по тайлам) — клетки с отмеченными тайлами к перерисовке
force_tiles:
		ld	d,a
		ld	hl,VNT
ftl:		ld	e,(hl)
		ld	a,(de)
		or	a
		jp	nz,ft_mark
ftn:		inc	l
		jp	nz,ftl
		inc	h
		ld	a,h
		cp	(VNT+768)/256
		jp	nz,ftl
		ret
ft_mark:	call	dl_add			; клетка — к выводу
		jp	ftn

; room_color_snapshot: shown_colors := room_colors
room_color_snapshot:
		ld	hl,shown_colors
		ld	de,room_colors
		ld	b,32
		jp	memcpyb

; room_color_changes: группы с новым цветом -> их клетки к перерисовке (палитра и режимы — при смене комнаты)
room_color_changes:
		xor	a
		ld	(other_colors),a
		ld	hl,room_colors
		ld	de,shown_colors
		ld	b,0
		ld	c,0			; изменённых групп
cg1:		ld	a,(de)
		cp	(hl)
		jp	z,cg2
		ld	a,(hl)
		ld	(de),a
		push	bc
		push	de
		push	hl
		call	group_mode_color
		ld	c,a
		ld	a,b
		ld	hl,group_modes
		call	add_hl_a
		ld	a,(hl)
		ld	(hl),c
		xor	c
		ld	c,a
		rrca
		or	c
		and	0x15
		rlca
		rlca
		rlca
		ld	(cg_mask+1),a
		pop	hl
		pop	de
		pop	bc
		ld	a,b			; группа не 1C, 1D — по карте
		and	0xFE
		cp	0x1C
		jp	z,cg1a
		ld	a,1
		ld	(other_colors),a
cg1a:		push	hl			; tile_changed[8b .. 8b+7] := 1
		ld	a,b
		add	a,a
		add	a,a
		add	a,a
		ld	l,a
		ld	h,tile_changed/256
cg_mask:	ld	a,0xA8
		REPT	8
		ld	(hl),a
		call	tile_recolor
		inc	l
		ENDR
		pop	hl
		inc	c
cg2:		inc	hl
		inc	de
		inc	b
		ld	a,b
		cp	32
		jp	nz,cg1
		ld	a,c
		or	a
		ret	z
		ld	a,(belt_frame)
		ld	hl,belt_shown
		cp	(hl)
		jp	z,cg_phase_ready
		ld	(hl),a
		ld	a,0xE0
		call	color_belt_phase
		ld	a,0xE8
		call	color_belt_phase
cg_phase_ready:	ld	a,(video_dirty)
		and	0xFF-DIRTY_BELT
		ld	(video_dirty),a
		ld	a,(other_colors)		; тайлы групп с новым цветом — их клетки к перерисовке: только группы
		or	a			; ленты и цепи (1C, 1D: тайлы E0-EF — живые) — по списку живых клеток,
		ld	a,tile_changed/256		; иначе — по карте
		jp	nz,cgc1
		call	force_live_t
		jp	cgc2
cgc1:		call	force_tiles
cgc2:		ld	hl,tile_changed
		ld	bc,256
		ld	a,(other_colors)
		or	a
		jp	nz,cgc_clear
		ld	hl,tile_changed+0xE0
		ld	bc,16
cgc_clear:	ld	e,0
		jp	memfill_f

 ; При общей смене цвета/кадра нужны только плоскости нового узора и нового цвета.
color_belt_phase:	ld	l,a
		ld	h,tile_changed/256
		push	hl
		ld	b,(hl)
		rrca
		rrca
		rrca
		and	31
		ld	hl,group_modes
		call	add_hl_a
		ld	c,(hl)
		ld	a,c
		rrca
		xor	c
		and	0x15
		rlca
		rlca
		rlca
		or	b
		pop	hl
		ld	(hl),a
		ret

; draw_list: клетки из списка, ждущие вывода (PND), — на экран; при dr_ex клетки под прежними местами
; перерисовываемых спрайтов откладываются (остаются в списке). Список переполнен — по строкам (draw_rows)
draw_list:
		ld	a,(dl_ovf)
		or	a
		jp	nz,dl_full
		ld	a,(dl_n)
		or	a
		ret	z
		ld	(dl_cnt),a
		xor	a
		ld	(dl_k),a
		ld	hl,dlist
dl1:		ld	e,(hl)
		inc	l
		ld	d,(hl)
		inc	l
		push	hl
		ex	de,hl			; HL = VNT + клетка
		ld	a,h
		add	a,(PND-VNT)/256
		ld	d,a
		ld	e,l			; DE = PND + клетка
		ld	a,(de)
		and	1
		jp	z,dl8			; уже выведена
		ld	a,l			; строка и столбец
		and	31
		ld	(rr_c),a
		ld	c,a
		ld	a,l
		rlca
		rlca
		rlca
		and	7
		ld	b,a
		ld	a,h
		sub	VNT/256
		add	a,a
		add	a,a
		add	a,a
		or	b
		ld	(rr_r),a
		ld	a,(dr_ex)
		or	a
		jp	z,dl_go
		push	hl
		push	de
		call	ex_test
		pop	de
		pop	hl
		jp	nc,dl_go
		ld	a,1			; отложить: оставить в списке
		ld	(ex_any),a
		ld	a,(dl_k)
		add	a,a
		ld	c,a
		inc	a
		inc	a
		rra
		ld	(dl_k),a
		ld	b,dlist/256
		ld	a,l
		ld	(bc),a
		inc	c
		ld	a,h
		ld	(bc),a
		jp	dl8
dl_go:		ld	a,(de)
		and	0xFE
		ld	(de),a
		ld	a,(hl)
		ld	(rr_t),a
		ld	a,1
		ld	(drew_any),a
		call	draw_cell
dl8:		pop	hl
		ld	a,(dl_cnt)
		dec	a
		ld	(dl_cnt),a
		jp	nz,dl1
		ld	a,(dl_k)
		ld	(dl_n),a
		or	a
		ret	nz
		ld	hl,row_dirty		; список пуст — и строки
		ld	bc,24
		ld	e,0
		jp	memfill
dl_full:	ld	hl,row_dirty		; переполнение: все строки (вывод — где PND = 1)
		ld	bc,24
		ld	e,1
		call	memfill
		call	draw_rows
		xor	a
		ld	(dl_ovf),a
		ld	(dl_n),a
		ret

; draw_rows: в отмеченных строках перерисовать клетки, ждущие вывода (PND; выровнена так же, как VNT)
draw_rows:
		xor	a
		ld	(rr_r),a
		ld	hl,row_dirty
dr0:		ld	a,(hl)
		or	a
		jp	z,dr9
		ld	(hl),0
		xor	a
		ld	(dr_skip),a
		push	hl
		ld	a,(rr_r)		; HL = VNT + 32 * r, DE = PND + 32 * r
		ld	l,a
		ld	h,0
		add	hl,hl
		add	hl,hl
		add	hl,hl
		add	hl,hl
		add	hl,hl
		ld	a,h
		add	a,PND/256
		ld	d,a
		ld	e,l
		ld	a,h
		add	a,VNT/256
		ld	h,a
		ld	b,32
dr1:		ld	a,(de)
		and	1
		jp	nz,dr_draw
dr2:		inc	l
		inc	e
		dec	b
		jp	nz,dr1
		pop	hl
		ld	a,(dr_skip)		; отложенные клетки — строка остаётся отмеченной
		or	a
		jp	z,dr9
		ld	(hl),1
dr9:		inc	hl
		ld	a,(rr_r)
		inc	a
		ld	(rr_r),a
		cp	24
		jp	nz,dr0
		ret
dr_draw:	ld	a,(dr_ex)
		or	a
		jp	z,dr_go
		push	hl
		push	de
		push	bc
		ld	a,l
		and	31
		ld	c,a
		call	ex_test
		pop	bc
		pop	de
		pop	hl
		jp	nc,dr_go
		ld	a,1
		ld	(dr_skip),a
		ld	(ex_any),a
		jp	dr2
dr_go:		ld	a,(de)
		and	0xFE
		ld	(de),a
		ld	a,(hl)
		ld	(rr_t),a
		ld	a,l
		and	31
		ld	(rr_c),a
		ld	a,1
		ld	(drew_any),a
		push	hl
		push	de
		push	bc
		call	draw_cell
		pop	bc
		pop	de
		pop	hl
		jp	dr2


; pal_fill: цвета MSX вне палитры -> индекс ближайшего из палитры (по merge_pairs)
pal_fill:
		ld	b,2
pf0:		ld	hl,used
		ld	a,b
		call	add_hl_a
		ld	a,(hl)
		or	a
		jp	nz,pf9
		ld	hl,merge_pairs		; первая пара (b, x) с used[x]
pf1:		ld	a,(hl)
		cp	0xFF
		jp	z,pf9
		inc	hl
		cp	b
		jp	nz,pf2
		ld	e,(hl)
		push	hl
		ld	hl,used
		ld	a,e
		call	add_hl_a
		ld	a,(hl)
		pop	hl
		or	a
		jp	z,pf2
		ld	hl,cmap
		ld	a,e
		call	add_hl_a
		ld	e,(hl)
		ld	hl,cmap
		ld	a,b
		call	add_hl_a
		ld	(hl),e
		jp	pf9
pf2:		inc	hl
		jp	pf1
pf9:		inc	b
		ld	a,b
		cp	16
		jp	nz,pf0
		ret

; group_modes_build: режимы 32 групп для построения образов (по 2 бита; 8000 — старшие:
; 0 — 00, 1 — шаблон, 2 — инверсия, 3 — FF) для индексов cmap[точки], cmap[фон] (0 -> 1)
group_modes_build:				; mb_d[i], mb_e[i] — вклад индекса cmap[i] (0 -> 1) как цвета точек и фона
		ld	b,0
mb0:		ld	a,b
		or	a
		jp	nz,mb1
		inc	a
mb1:		ld	hl,cmap
		call	add_hl_a
		ld	d,(hl)			; индекс
		ld	c,0			; точки: бит плоскости -> 1 в её паре (8000 — биты 5-4, A000 — 3-2, C000 — 1-0)
		ld	a,d
		and	4
		jp	z,mb2
		ld	c,0x10
mb2:		ld	a,d
		and	2
		jp	z,mb3
		ld	a,c
		or	0x04
		ld	c,a
mb3:		ld	a,d
		and	1
		jp	z,mb4
		inc	c
mb4:		ld	hl,mb_d
		ld	a,b
		call	add_hl_a
		ld	(hl),c
		ld	a,c			; фон — то же, сдвинутое на 1 (2 в паре)
		add	a,a
		ld	hl,mb_e
		push	af
		ld	a,b
		call	add_hl_a
		pop	af
		ld	(hl),a
		inc	b
		ld	a,b
		cp	16
		jp	nz,mb0
group_modes_refresh:	ld	de,room_colors
		ld	hl,group_modes
		ld	b,32
mb5:		ld	a,(de)
		call	group_mode_color
		ld	(hl),a
		inc	hl
		inc	de
		dec	b
		jp	nz,mb5
		ret

group_mode_color:	push	bc
		push	hl
		ld	b,a
		and	15
		ld	hl,mb_e
		call	add_hl_a
		ld	c,(hl)
		ld	a,b
		rrca
		rrca
		rrca
		rrca
		and	15
		ld	hl,mb_d
		call	add_hl_a
		ld	a,(hl)
		or	c
		pop	hl
		pop	bc
		ret
