; Вывод виртуальной VRAM на экран Вектора раз в кадр (из прерывания).
; Отметки: row_dirty[24] (записи в таблицу имён), pat_flag[256] (тайлы с новыми шаблонами), vdirty (VD_*).
; Клетки к выводу: PND (1 — ждёт), список dlist; col_shown (цвета), tile_hi (кадр анимации 0-3); спрайты — spr_rec.
; Пока экран VDP выключен (R1 бит 6 = 0) — не рисуем; при включении — полная перерисовка с палитрой.

; display: подготовка и, если есть спрайты к перерисовке, — ожидание кадра и короткая часть (меню)
display:
		call	disp_prep
		ld	a,(crit_pend)
		or	a
		ret	z
		ld	hl,frames
		ld	a,(hl)
dp6:		cp	(hl)
		jp	z,dp6
		xor	a
		ld	(crit_pend),a
		jp	crit

; disp_prep: всё, кроме короткой части: клетки (кроме тех, что под перерисовываемыми спрайтами), план
; спрайтов; crit_pend := 1, если после прерывания нужна короткая часть (crit)
disp_prep:
		ld	a,(vregs+1)
		and	0x40
		ret	z
		ld	a,8			; атрибуты спрайтов 7300 -> VSAT (WR_SPR_NM_TBL обработчика кадра — здесь)
		call	sat_copy
		xor	a
		ld	(drew_any),a
		ld	a,(vdirty)
		and	VD_NT			; новая комната: дождаться конца рисования (2 кадра без очистки)
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
dp1a:		ld	a,(vdirty)
		and	VD_REG			; R4 — фаза анимации
		jp	z,dp2
		ld	a,(vdirty)
		and	0xFF-VD_REG
		ld	(vdirty),a
		call	bank_hi
		ld	hl,tile_hi
		cp	(hl)
		jp	z,dp2
		ld	(bk_new),a
		call	bank_diff		; col_flag: тайлы, чей шаблон в новом банке другой (огонь — через раз)
		ld	a,(bk_new)
		ld	(tile_hi),a
						; их живые клетки — к перерисовке
		ld	a,col_flag/256
		call	force_live_t
		ld	hl,anim_set		; col_flag := 0
bdz:		ld	a,(hl)
		cp	0xFF
		jp	z,dp2
		push	hl
		ld	l,a
		ld	h,col_flag/256
		ld	(hl),0
		pop	hl
		inc	hl
		jp	bdz
dp2:		ld	a,(vdirty)
		and	VD_PAT
		jp	z,dp3
		ld	a,(vdirty)
		and	0xFF-VD_PAT
		ld	(vdirty),a
		ld	a,pat_flag/256		; тайлы с новой графикой: живые клетки с ними (E0/E8 — лента и цепь) —
		call	force_live_t
		xor	a			; E0/E8 — сбросить; другие тайлы (pat_oth — отмечается при записи) — редкость:
		ld	(pat_flag+0xE0),a	; все их клетки (по карте)
		ld	(pat_flag+0xE8),a
		ld	a,(pat_oth)
		or	a
		jp	z,dp3
		xor	a
		ld	(pat_oth),a
		ld	a,pat_flag/256
		call	force_tiles
		ld	hl,pat_flag
		ld	bc,256
		ld	e,0
		call	memfill
dp3:		ld	a,(vdirty)
		and	VD_COL
		jp	z,dp4
		ld	a,(vdirty)
		and	0xFF-VD_COL
		ld	(vdirty),a
		call	col_changed
dp4:		call	spr_plan		; какие спрайты перерисовать (A — сколько)
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
		call	ex_build		; клетки под прежними местами отмеченных — отложить
		xor	a
		ld	(ex_any),a
		ld	a,1
		ld	(dr_ex),a
		call	draw_list
		xor	a
		ld	(dr_ex),a
		call	crit_plan		; группы и порядок — тоже до ожидания
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
		ld	a,1
		ld	(spr_force),a
		ld	hl,col_flag
		ld	bc,256
		ld	e,0
		call	memfill
		call	bank_hi			; кадр анимации
		ld	(tile_hi),a
		call	pal_build
		call	pal_fill
		call	modes_build
		ld	a,3
		ld	(pal_load),a
		call	force_all
		ld	a,(vdirty)
		and	0xFF-VD_NT-VD_COL
		ld	(vdirty),a
		call	live_build
		xor	a
		ld	(lv_dirty),a
		jp	col_snapshot

; Живые клетки (анимированные тайлы anim_set и лента/цепь E0-EF) — по корзинам тайлов: lv_idx[тайл] = корзина
; (0..32) или FF; корзина b — элементы с lv_beg[b] по lv_beg[b + 1] - 1: адрес клетки в VNT — младший байт
; в live_list, старший — в live_hi (до LIVE_N клеток; в комнатах — до 189).
LIVE_N		equ	250
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

; force_live_t: A = страница флагов по тайлам — живые клетки отмеченных тайлов к перерисовке (по корзинам)
force_live_t:
		ld	(fl_pg),a		; страница флагов
		ld	a,(lv_nn)
		or	a
		ret	z
		call	fl_bbox			; общая рамка нарисованных спрайтов
		ld	a,(lv_nn)
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
		ld	a,c
		ld	(fl_i),a
		call	dc_tile			; графика и режимы — одни на всю корзину (тайл один)
		ld	a,c
		ld	(fl_m),a
		ex	de,hl
		ld	(fl_g),hl
flt2:		ld	a,(fl_i)		; DE = клетка в VNT
		ld	l,a
		inc	a
		ld	(fl_i),a
		ld	h,live_list/256
		ld	e,(hl)
		ld	h,live_hi/256
		ld	d,(hl)
		ld	a,(de)			; в карте уже другой тайл (взят предмет и т. п.) — не наша клетка: её
		ld	hl,rr_t			; изменение и так в очереди
		cp	(hl)
		jp	nz,flt5
		ld	a,e			; строка, столбец
		and	31
		ld	(rr_c),a
		ld	a,e
		rlca
		rlca
		rlca
		and	7
		ld	b,a
		ld	a,d
		sub	VNT/256
		add	a,a
		add	a,a
		add	a,a
		or	b
		ld	(rr_r),a
		call	fl_under
		jp	c,flt_q
		push	de			; не под спрайтом — сразу на экран
		call	dc_scr
		ld	a,(fl_m)
		ld	c,a
		push	hl
		ld	hl,(fl_g)
		ex	de,hl
		pop	hl
		call	dc_draw
		pop	de
		ld	a,d			; выведена
		add	a,(PND-VNT)/256
		ld	h,a
		ld	l,e
		ld	(hl),0
		jp	flt5
flt_q:		ld	a,d			; под спрайтом — к выводу (PND), в список (после его стирания)
		add	a,(PND-VNT)/256
		ld	h,a
		ld	l,e
		ld	a,(hl)			; уже ждёт вывода — в списке есть
		or	a
		jp	nz,flt5
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
flt5:		ld	a,(fl_n)
		dec	a
		ld	(fl_n),a
		jp	nz,flt2
flt3:		pop	bc
		pop	hl
		inc	hl
		dec	b
		jp	nz,flt1
		ret
flt_o:		ld	a,1
		ld	(dl_ovf),a
		jp	flt5
; fl_bbox: fl_bb = общая рамка (r0, r1, c0, c1) мест нарисованных спрайтов (нет — пусто: FF, 0, FF, 0)
fl_bbox:	ld	de,0xFF00		; D — r0, E — r1, B — c0, C — c1
		ld	bc,0xFF00
		ld	hl,spr_rec
fx0:		ld	a,(hl)
		or	a
		jp	z,fx5
		push	hl
		ld	a,l
		add	a,5
		ld	l,a
		ld	a,(hl)
		cp	d
		jp	nc,fx1
		ld	d,a
fx1:		inc	l
		ld	a,(hl)
		cp	e
		jp	c,fx2
		ld	e,a
fx2:		inc	l
		ld	a,(hl)
		cp	b
		jp	nc,fx3
		ld	b,a
fx3:		inc	l
		ld	a,(hl)
		cp	c
		jp	c,fx4
		ld	c,a
fx4:		pop	hl
fx5:		ld	a,l
		add	a,16
		ld	l,a
		cp	16*SPR_MAX
		jp	nz,fx0
		ld	hl,fl_bb
		ld	(hl),d
		inc	hl
		ld	(hl),e
		inc	hl
		ld	(hl),b
		inc	hl
		ld	(hl),c
		ret
; fl_under: клетка (rr_r, rr_c) — под местом нарисованного спрайта? CY — да (DE сохраняется)
fl_under:	ld	a,(rr_r)
		ld	hl,fl_bb
		cp	(hl)
		jp	c,fu_n
		inc	hl
		ld	b,(hl)
		cp	b
		jp	z,fu1
		jp	nc,fu_n
fu1:		ld	a,(rr_c)
		inc	hl
		cp	(hl)
		jp	c,fu_n
		inc	hl
		ld	b,(hl)
		cp	b
		jp	z,fu2
		jp	nc,fu_n
fu2:		ld	hl,spr_rec		; по спрайтам
fu3:		ld	a,(hl)
		or	a
		jp	z,fu4
		push	hl
		ld	a,l
		add	a,5
		ld	l,a
		ld	a,(rr_r)		; r0 <= r <= r1, c0 <= c <= c1
		cp	(hl)
		jp	c,fu5
		inc	l
		ld	b,(hl)
		cp	b
		jp	z,fu6
		jp	nc,fu5
fu6:		ld	a,(rr_c)
		inc	l
		cp	(hl)
		jp	c,fu5
		inc	l
		ld	b,(hl)
		cp	b
		jp	z,fu7
		jp	nc,fu5
fu7:		pop	hl
		scf
		ret
fu5:		pop	hl
fu4:		ld	a,l
		add	a,16
		ld	l,a
		cp	16*SPR_MAX
		jp	nz,fu3
fu_n:		or	a
		ret

; bank_diff: col_flag[t] := 1 для тайлов anim_set, у которых шаблон в банке bk_new не тот, что в tile_hi
bank_diff:					; по таблице переходов банков (bd_init): col_flag анимированных тайлов
		ld	a,(tile_hi)
		add	a,a
		add	a,a
		ld	b,a
		ld	a,(bk_new)
		add	a,b
		ld	b,a
		add	a,a
		add	a,b			; 3 * (4 * старый + новый)
		ld	hl,bd_tab
		call	add_hl_a
		ld	de,anim_set
		ld	c,3
bdt0:		ld	a,(hl)
		ld	b,8
bdt1:		rrca
		push	af
		jp	nc,bdt2
		ld	a,(de)
		cp	0xFF
		jp	z,bdt3
		push	hl
		ld	l,a
		ld	h,col_flag/256
		ld	(hl),1
		pop	hl
bdt2:		inc	de
		pop	af
		dec	b
		jp	nz,bdt1
		inc	hl
		dec	c
		jp	nz,bdt0
		ret
bdt3:		pop	af
		ret

; bd_init: таблица bd_tab[4 * старый + новый] — 3 байта, бит i: у anim_set[i] шаблоны банков различаются
bd_init:	ld	hl,bd_tab
		xor	a
		ld	(tile_hi),a
bi0:		xor	a
		ld	(bk_new),a
bi1:		push	hl
		call	bank_diff_slow
		pop	hl
		ld	de,anim_set		; флаги -> 3 байта, флаги сбросить
		ld	c,3
bi2:		ld	b,8
		ld	(hl),0
bi3:		ld	a,(de)
		cp	0xFF
		jp	z,bi4
		push	hl
		ld	l,a
		ld	h,col_flag/256
		ld	a,(hl)
		ld	(hl),0
		pop	hl
		rrca
		ld	a,(hl)
		rra
		ld	(hl),a
		inc	de
		dec	b
		jp	nz,bi3
		jp	bi5
bi4:		ld	a,(hl)
		or	a
		rra
		ld	(hl),a
		dec	b
		jp	nz,bi4
bi5:		inc	hl
		dec	c
		jp	nz,bi2
		ld	a,(bk_new)
		inc	a
		ld	(bk_new),a
		cp	4
		jp	nz,bi1
		ld	a,(tile_hi)
		inc	a
		ld	(tile_hi),a
		cp	4
		jp	nz,bi0
		xor	a
		ld	(tile_hi),a
		ret

bank_diff_slow:
		ld	hl,anim_set
bd0:		ld	a,(hl)
		cp	0xFF
		jp	z,bd_end
		push	hl
		ld	c,a
		ld	a,(tile_hi)
bd_cmp:		call	pat_ptr			; прежний
		push	hl
		ld	a,(bk_new)
		call	pat_ptr			; новый
		pop	de
		ld	b,8
bd1:		ld	a,(de)
		cp	(hl)
		jp	nz,bd_ch
		inc	de
		inc	hl
		dec	b
		jp	nz,bd1
		jp	bd9
bd_ch:		ld	l,c
		ld	h,col_flag/256
		ld	(hl),1
bd9:		pop	hl
		inc	hl
		jp	bd0
bd_end:		ret

; pat_ptr: C = тайл, A = банк (0..3) -> HL = шаблон (8 байт) (C сохраняется)
pat_ptr:	or	a
		jp	z,pp_b0
		dec	a
		add	a,a
		add	a,a
		add	a,a
		ld	b,a
		ld	l,c
		ld	h,dslot/256
		ld	a,(hl)
		cp	0xFF
		jp	z,pp_b0
		ld	e,a			; dstore + 24 * номер + 8 * (банк - 1)
		ld	d,0
		ld	h,d
		ld	l,e
		add	hl,hl
		add	hl,de
		add	hl,hl
		add	hl,hl
		add	hl,hl
		ld	de,dstore
		add	hl,de
		ld	a,b
		jp	add_hl_a
pp_b0:		ld	l,c			; банк 0: E000 + 8 * тайл
		ld	h,0
		add	hl,hl
		add	hl,hl
		add	hl,hl
		ld	a,h
		add	a,0xE0
		ld	h,a
		ret

; bank_hi: A = номер банка шаблонов по R4 (0 -> 0, 1 -> 1, 2 -> 2, 5 -> 3)
bank_hi:	ld	a,(vregs+4)
		and	7
		cp	5
		ret	nz
		ld	a,3
		ret

; force_all: все клетки — к перерисовке
force_all:
		ld	hl,PND
		ld	bc,768
		ld	e,1
		call	memfill
		ld	a,1			; список — переполнен: вывод по строкам
		ld	(dl_ovf),a
		ld	hl,row_dirty
		ld	bc,24
		ld	e,1
		jp	memfill

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

; col_snapshot: col_shown := VCOL
col_snapshot:
		ld	hl,col_shown
		ld	de,VCOL
		ld	b,32
		jp	memcpyb

; col_changed: группы с новым цветом -> их клетки к перерисовке (палитра и режимы — при смене комнаты)
col_changed:
		xor	a
		ld	(col_oth),a
		ld	hl,VCOL
		ld	de,col_shown
		ld	b,0
		ld	c,0			; изменённых групп
cg1:		ld	a,(de)
		cp	(hl)
		jp	z,cg2
		ld	a,(hl)
		ld	(de),a
		ld	a,b			; группа не 1C, 1D — по карте
		and	0xFE
		cp	0x1C
		jp	z,cg1a
		ld	a,1
		ld	(col_oth),a
cg1a:		push	hl			; col_flag[8b .. 8b+7] := 1
		ld	a,b
		add	a,a
		add	a,a
		add	a,a
		ld	l,a
		ld	h,col_flag/256
		ld	a,1
		REPT	8
		ld	(hl),a
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
		ld	a,(col_oth)		; тайлы групп с новым цветом — их клетки к перерисовке: только группы
		or	a			; ленты и цепи (1C, 1D: тайлы E0-EF — живые) — по списку живых клеток,
		ld	a,col_flag/256		; иначе — по карте
		jp	nz,cgc1
		call	force_live_t
		jp	cgc2
cgc1:		call	force_tiles
cgc2:
		ld	hl,col_flag
		ld	bc,256
		ld	e,0
		jp	memfill

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
		or	a
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
dl_go:		xor	a
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
		or	a
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
dr_go:		xor	a
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

; modes_build: cmodes[байт цвета MSX] = режимы плоскостей 8000/A000/C000 (по 2 бита, 8000 — старшие:
; 0 — 00, 1 — шаблон, 2 — инверсия, 3 — FF) для индексов cmap[точки], cmap[фон] (0 -> 1)
modes_build:
		ld	hl,cmodes
mb0:		ld	a,l
		rrca
		rrca
		rrca
		rrca
		and	0x0F
		jp	nz,mb1
		inc	a
mb1:		push	hl
		ld	hl,cmap
		call	add_hl_a
		ld	d,(hl)			; D = индекс точек
		pop	hl
		ld	a,l
		and	0x0F
		jp	nz,mb2
		inc	a
mb2:		push	hl
		ld	hl,cmap
		call	add_hl_a
		ld	e,(hl)			; E = индекс фона
		pop	hl
		ld	b,4			; бит индекса: 4 (8000), 2 (A000), 1 (C000)
		ld	c,0
mb3:		ld	a,c
		add	a,a
		add	a,a
		ld	c,a
		ld	a,d
		and	b
		jp	z,mb4
		inc	c
mb4:		ld	a,e
		and	b
		jp	z,mb5
		inc	c
		inc	c
mb5:		ld	a,b
		rrca
		ld	b,a
		cp	0x80
		jp	nz,mb3
		ld	(hl),c
		inc	l
		jp	nz,mb0
		ret
