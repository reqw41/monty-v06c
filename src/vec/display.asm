; Вывод виртуальной VRAM на экран Вектора раз в кадр (из прерывания).
; Отметки: row_dirty[24] (записи в таблицу имён), pat_flag[256] (тайлы с новыми шаблонами), vdirty (VD_*).
; Показанное: NTS (копия таблицы имён), col_shown (цвета), tile_hi (банк шаблонов), spr_last (атрибуты спрайтов).
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
		ld	a,anim_flag/256
		call	force_tiles
dp2:		ld	a,(vdirty)
		and	VD_PAT
		jp	z,dp3
		ld	a,(vdirty)
		and	0xFF-VD_PAT
		ld	(vdirty),a
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
dp4:		call	spr_changed		; NZ — атрибуты спрайтов изменились
		push	af
		call	nz,spr_erase
		call	draw_rows
		pop	af
		jp	nz,spr_draw
		ld	a,(drew_any)		; спрайты на месте: перерисовать, только если под ними что-то рисовали
		or	a
		jp	nz,spr_draw
		ret

; room_redraw: таблица анимации, палитра, всё к перерисовке
room_redraw:
		call	anim_build
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
		jp	col_snapshot

; bank_hi: A = старший байт банка шаблонов по R4 (0 -> E0, 1 -> E8, 2 -> F0, 5 -> F8)
bank_hi:	ld	a,(vregs+4)
		and	7
		cp	5
		jp	nz,bh1
		ld	a,3
bh1:		add	a,a
		add	a,a
		add	a,a
		add	a,0xE0
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
ft_mark:	push	de			; NTS[i] := не VNT[i]; строка = i >> 5
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
		jp	ftn

; col_snapshot: col_shown := VCOL
col_snapshot:
		ld	hl,col_shown
		ld	de,VCOL
		ld	b,32
		jp	memcpyb

; col_changed: группы с новым цветом -> col_flag (8 тайлов на группу) -> force_tiles
col_changed:
		ld	hl,col_flag
		ld	bc,256
		ld	e,0
		call	memfill
		ld	hl,VCOL
		ld	de,col_shown
		ld	b,0
cg1:		ld	a,(de)
		cp	(hl)
		jp	z,cg2
		push	hl			; col_flag[8b .. 8b+7] := 1
		ld	a,b
		add	a,a
		add	a,a
		add	a,a
		ld	l,a
		ld	h,col_flag/256
		ld	c,8
cg0:		ld	(hl),1
		inc	l
		dec	c
		jp	nz,cg0
		pop	hl
cg2:		inc	hl
		inc	de
		inc	b
		ld	a,b
		cp	32
		jp	nz,cg1
		call	col_snapshot
		call	pal_fill
		call	modes_build
		ld	a,col_flag/256
		jp	force_tiles

; draw_rows: в отмеченных строках перерисовать клетки, где VNT != NTS
draw_rows:
		xor	a
		ld	(rr_r),a
dr0:		ld	hl,row_dirty
		ld	a,(rr_r)
		call	add_hl_a
		ld	a,(hl)
		or	a
		jp	z,dr9
		ld	(hl),0
		ld	a,(rr_r)		; HL = VNT + 32 * r, DE = NTS + 32 * r
		ld	l,a
		ld	h,0
		add	hl,hl
		add	hl,hl
		add	hl,hl
		add	hl,hl
		add	hl,hl
		push	hl
		ld	de,NTS
		add	hl,de
		ex	de,hl
		pop	hl
		ld	bc,VNT
		add	hl,bc
		xor	a
		ld	(rr_c),a
dr1:		ld	a,(de)
		cp	(hl)
		jp	z,dr2
		ld	a,(hl)
		ld	(de),a
		ld	(rr_t),a
		ld	a,1
		ld	(drew_any),a
		push	hl
		push	de
		call	draw_cell
		pop	de
		pop	hl
dr2:		inc	hl
		inc	de
		ld	a,(rr_c)
		inc	a
		ld	(rr_c),a
		cp	32
		jp	nz,dr1
dr9:		ld	a,(rr_r)
		inc	a
		ld	(rr_r),a
		cp	24
		jp	nz,dr0
		ret

; anim_build: anim_flag[t] := 1, если шаблоны тайла t в банках 0, 1, 2, 5 различаются
anim_build:
		ld	hl,anim_flag
		ld	bc,256
		ld	e,0
		call	memfill
		ld	c,0			; тайл
ab0:		ld	l,c			; HL = E000 + 8 * тайл
		ld	h,0
		add	hl,hl
		add	hl,hl
		add	hl,hl
		ld	a,h
		add	a,0xE0
		ld	h,a
		ld	b,8
ab1:		ld	d,h
		ld	e,(hl)
		ld	a,h
		add	a,0x08
		ld	h,a
		ld	a,e
		cp	(hl)
		jp	nz,ab_diff
		ld	a,h
		add	a,0x08
		ld	h,a
		ld	a,e
		cp	(hl)
		jp	nz,ab_diff
		ld	a,h
		add	a,0x08
		ld	h,a
		ld	a,e
		cp	(hl)
		jp	nz,ab_diff
		ld	h,d
		inc	hl
		dec	b
		jp	nz,ab1
		jp	ab_next
ab_diff:	ld	l,c
		ld	h,anim_flag/256
		ld	(hl),1
ab_next:	inc	c
		jp	nz,ab0
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
