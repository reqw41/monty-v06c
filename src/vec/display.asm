; Вывод виртуальной VRAM на экран Вектора раз в кадр (из прерывания).
; Отметки: row_dirty[24] (записи в таблицу имён), pat_flag[256] (тайлы с новыми шаблонами), vdirty (VD_*).
; Показанное: NTS (копия таблицы имён), col_shown (цвета), tile_hi (номер банка шаблонов 0-3), spr_last.
; Пока экран VDP выключен (R1 бит 6 = 0) — не рисуем; при включении — полная перерисовка с палитрой.

display:
		ld	a,(vregs+1)
		and	0x40
		ret	z
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
dp1:		ld	a,(vdirty)
		and	VD_REG			; R4 — фаза анимации
		jp	z,dp2
		ld	a,(vdirty)
		and	0xFF-VD_REG
		ld	(vdirty),a
		call	bank_hi
		ld	hl,tile_hi
		cp	(hl)
		jp	z,dp2
		ld	(hl),a
		ld	h,anim_flag/256		; анимированные тайлы — из кэша изображений
		call	cache_drop_flags
		call	force_live
dp2:		ld	a,(vdirty)
		and	VD_PAT
		jp	z,dp3
		ld	a,(vdirty)
		and	0xFF-VD_PAT
		ld	(vdirty),a
		ld	h,pat_flag/256		; тайлы с новыми шаблонами — из кэша изображений
		call	cache_drop_flags
		ld	a,(pat_flag+0xE0)	; шаблоны только E0/E8 (анимация цепи и ленты) — по списку
		ld	b,a
		ld	a,(pat_flag+0xE8)
		or	b
		ld	(pat_flag+0xE0),a
		ld	(pat_flag+0xE8),a
		push	af
		xor	a
		ld	(pat_flag+0xE0),a
		ld	(pat_flag+0xE8),a
		ld	hl,pat_flag		; другие тайлы отмечены?
		ld	b,0
		xor	a
dpp1:		or	(hl)
		inc	l
		dec	b
		jp	nz,dpp1
		ld	b,a
		pop	af
		or	a
		call	nz,force_live
		ld	a,b
		or	a
		ld	a,pat_flag/256
		call	nz,force_tiles
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
dp4:		call	spr_changed		; спрайты изменились или есть строки к перерисовке: фон назад, клетки, спрайты
		jp	nz,dp5
		ld	hl,row_dirty
		ld	b,24
		xor	a
dp4a:		or	(hl)
		inc	hl
		dec	b
		jp	nz,dp4a
		or	a
		ret	z
dp5:		call	spr_erase		; клетки под прежними спрайтами — к перерисовке, затем клетки, затем спрайты
		call	draw_rows
		jp	spr_draw

; room_redraw: таблица анимации, палитра, всё к перерисовке
room_redraw:
		ld	hl,col_flag
		ld	bc,256
		ld	e,0
		call	memfill
		ld	a,(anim_ok)		; таблица анимации — после изменения шаблонов (кроме E0/E8)
		or	a
		jp	nz,rr1
		call	anim_build
		call	trim_build
		ld	a,1
		ld	(anim_ok),a
rr1:		call	cache_flush
		call	pal_build
		call	pal_fill
		call	modes_build
		ld	a,3
		ld	(pal_load),a
		call	force_all
		ld	a,(vdirty)
		and	0xFF-VD_NT-VD_COL
		ld	(vdirty),a
		call	bank_hi
		ld	(tile_hi),a
		call	live_build
		jp	col_snapshot

; live_build: список «живых» клеток (анимированные тайлы и E0-EF) — смещения в VNT по 2 байта, конец FFFF
live_build:
		ld	de,live_list
		ld	hl,VNT
lb1:		ld	a,(hl)
		cp	0xE0
		jp	nc,lb2
		push	de
		ld	e,a
		ld	d,anim_flag/256
		ld	a,(de)
		pop	de
		or	a
		jp	z,lb3
lb2:		ld	a,e			; не больше LIVE_MAX
		cp	(live_list+2*LIVE_MAX)&0xFF
		jp	z,lb3
		ld	a,l
		ld	(de),a
		inc	de
		ld	a,h
		ld	(de),a
		inc	de
lb3:		inc	hl
		ld	a,h
		cp	(VNT+768)/256
		jp	nz,lb1
		ld	a,0xFF
		ld	(de),a
		inc	de
		ld	(de),a
		ret

; force_live: клетки из списка — к перерисовке
force_live:
		ld	hl,live_list
fl1:		ld	e,(hl)
		inc	hl
		ld	d,(hl)
		inc	hl
		ld	a,d
		cp	0xFF
		ret	z
		push	hl
		ex	de,hl			; HL = адрес в VNT
		call	ft_mark1
		pop	hl
		jp	fl1

; bank_hi: A = номер банка шаблонов по R4 (0 -> 0, 1 -> 1, 2 -> 2, 5 -> 3)
bank_hi:	ld	a,(vregs+4)
		and	7
		cp	5
		ret	nz
		ld	a,3
		ret

; force_all: все клетки — к перерисовке
force_all:
		ld	hl,NTS
		ld	de,VNT
		ld	bc,768
fa1:		ld	a,(de)
		cpl
		ld	(hl),a
		inc	hl
		inc	de
		dec	bc
		ld	a,b
		or	c
		jp	nz,fa1
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
ft_mark:	call	ft_mark1
		jp	ftn
; ft_mark1: HL = адрес клетки в VNT — NTS := не VNT, строка к перерисовке (регистры сохраняются)
ft_mark1:	push	de
		push	hl
		ld	a,(hl)
		cpl
		ld	e,a
		ld	a,h
		add	a,(NTS-VNT)/256		; NTS выровнена так же, как VNT
		ld	h,a
		ld	(hl),e
		pop	hl
		push	hl
		ld	a,l
		rlca
		rlca
		rlca
		and	7
		ld	e,a
		ld	a,h
		sub	VNT/256
		add	a,a
		add	a,a
		add	a,a
		or	e
		ld	hl,row_dirty
		call	add_hl_a
		ld	(hl),1
		pop	hl
		pop	de
		ret

; col_snapshot: col_shown := VCOL
col_snapshot:
		ld	hl,col_shown
		ld	de,VCOL
		ld	b,32
		jp	memcpyb

; col_changed: группы с новым цветом -> их клетки к перерисовке (палитра и режимы — при смене комнаты)
col_changed:
		ld	hl,VCOL
		ld	de,col_shown
		ld	b,0
		ld	c,0			; изменённых групп
cg1:		ld	a,(de)
		cp	(hl)
		jp	z,cg2
		ld	a,(hl)
		ld	(de),a
		push	hl			; col_flag[8b .. 8b+7] := 1
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
		ld	h,col_flag/256		; тайлы групп с новым цветом — из кэша изображений
		call	cache_drop_flags
		ld	a,col_flag/256
		call	force_tiles
		ld	hl,col_flag
		ld	bc,256
		ld	e,0
		jp	memfill

; draw_rows: в отмеченных строках перерисовать клетки, где VNT != NTS (VNT и NTS выровнены одинаково)
draw_rows:
		xor	a
		ld	(rr_r),a
		ld	hl,row_dirty
dr0:		ld	a,(hl)
		or	a
		jp	z,dr9
		ld	(hl),0
		push	hl
		ld	a,(rr_r)		; HL = VNT + 32 * r, DE = NTS + 32 * r
		ld	l,a
		ld	h,0
		add	hl,hl
		add	hl,hl
		add	hl,hl
		add	hl,hl
		add	hl,hl
		ld	a,h
		add	a,NTS/256
		ld	d,a
		ld	e,l
		ld	a,h
		add	a,VNT/256
		ld	h,a
		ld	b,32
dr1:		ld	a,(de)
		cp	(hl)
		jp	nz,dr_draw
dr2:		inc	l
		inc	e
		dec	b
		jp	nz,dr1
		pop	hl
dr9:		inc	hl
		ld	a,(rr_r)
		inc	a
		ld	(rr_r),a
		cp	24
		jp	nz,dr0
		ret
dr_draw:	ld	a,(hl)
		ld	(de),a
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

; anim_build: anim_flag[t] := 1, если у тайла t есть различие банков (dslot)
anim_build:
		ld	hl,anim_flag
		ld	de,dslot
anb1:		ld	a,(de)
		inc	a			; FF -> 0
		jp	z,anb2
		ld	a,1
anb2:		ld	(hl),a
		inc	l
		inc	e
		jp	nz,anb1
		ret

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
