; Готовая клетка: 24 байта, полосы 8000/A000/C000 по 8 строк сверху вниз.
; В обычном рисовании нет выбора банков, цветов или режимов плоскостей.
tile_slots equ 0xF300

tiles_reset:	ld	hl,tile_slots
		ld	bc,256
		ld	e,0xFF
		call	memfill_f
		xor	a
		ld	(tile_count),a
		ret

; Все варианты живого тайла строятся вместе; смена кадра только выбирает образ.
tile_kind:	ld	a,(rr_t)
		cp	0xE8
		ld	c,2
		ret	z
		cp	0xE0
		ld	c,4
		ret	z
		ld	l,a
		ld	h,lv_idx/256
		ld	a,(hl)
		cp	17
		ret	c
		ld	c,1
		ret

tile_ready:	ld	a,(rr_t)
		ld	l,a
		ld	h,tile_slots/256
		ld	a,(hl)
		cp	0xFF
		jp	nz,tile_select
		push	hl
		call	tile_kind
		ld	a,c
		ld	(tile_frames),a
		ld	a,(tile_count)
		add	a,c
		cp	TILE_CAP+1
		push	bc
		call	nc,tiles_reset
		pop	bc
		ld	a,(tile_count)
		pop	hl
		ld	(hl),a
		push	af
		add	a,c
		ld	(tile_count),a
		pop	af
		call	tile_build
		jp	tile_ready

tile_select:	ld	b,a
		ld	a,(rr_t)
		cp	0xE0
		jp	z,tsel_belt
		cp	0xE8
		jp	z,tsel_chain
		ld	l,a
		ld	h,lv_idx/256
		ld	a,(hl)
		cp	17
		ld	a,0
		jp	nc,tsel_add
		ld	a,(fire_shown)
		jp	tsel_add
tsel_chain:	ld	a,(belt_shown)
		and	1
		jp	tsel_add
tsel_belt:	ld	a,(belt_shown)
tsel_add:	add	a,b
; tile_addr: A = номер образа -> HL = TILE_IMAGES + 24*A
tile_addr:	ld	l,a
		ld	h,0
		add	hl,hl
		add	hl,hl
		ld	d,h
		ld	e,l
		add	hl,de
		add	hl,hl
		add	hl,hl
		ld	de,TILE_IMAGES
		add	hl,de
		ret

; tile_build: A = базовая ячейка; tile_frames — вариантов. Только вход/смена цвета.
tile_build:	ld	(tile_i),a
		xor	a
		ld	(tile_phase),a
tbuild0:	ld	a,(tile_i)
		call	tile_addr
		ld	(tile_dst),hl
		call	dc_tile
		call	da_img
		ld	hl,tile_i
		inc	(hl)
		ld	hl,tile_phase
		inc	(hl)
		ld	a,(tile_frames)
		cp	(hl)
		jp	nz,tbuild0
		ret

; tile_recolor: L = тайл с новым цветом; сохранить выделенное место и перестроить варианты.
tile_recolor:	push	af
		push	bc
		push	de
		push	hl
		ld	a,l
		ld	(rr_t),a
		ld	h,tile_slots/256
		ld	a,(hl)
		cp	0xFF
		jp	z,trc_end
		push	af
		call	tile_kind
		ld	a,c
		ld	(tile_frames),a
		pop	af
		call	tile_build
trc_end:	pop	hl
		pop	de
		pop	bc
		pop	af
		ret

; dc_tile используется только построителем образов: C = режимы группы, DE = исходная полоса.
dc_tile:	ld	a,(rr_t)
		ld	b,a
		rrca
		rrca
		rrca
		and	31
		ld	hl,group_modes
		call	add_hl_a
		ld	c,(hl)
		ld	a,b
		cp	0xE0
		jp	z,dc_belt0
		cp	0xE8
		jp	z,dc_belt8
		ld	l,b
		ld	h,lv_idx/256
		ld	a,(hl)
		cp	17
		jp	nc,dc_base
		add	a,a
		add	a,a
		add	a,a
		ld	b,a
		ld	a,(tile_phase)
		add	a,a
		add	a,b
		ld	hl,raw_anim
		call	add_hl_a
		jp	dc_source
dc_base:	ld	a,(rr_t)
		ld	l,a
		ld	h,0
		add	hl,hl
		ld	de,raw_base
		add	hl,de
dc_source:	ld	e,(hl)
		inc	hl
		ld	d,(hl)
		ret
dc_belt0:	ld	a,(tile_phase)
		add	a,a
		ld	hl,C_85BC
		jp	dc_belt
dc_belt8:	ld	a,(tile_phase)
		and	1
		add	a,a
		add	a,a
		add	a,a
		ld	hl,C_85CA
dc_belt:	call	add_hl_a
		ex	de,hl
		ret

; dc_scr: клетка -> экран (верхняя строка, плоскость 8000).
dc_scr:		ld	a,(rr_r)
		add	a,a
		add	a,a
		add	a,a
		cpl
		add	a,0xE0
		ld	l,a
		ld	a,(rr_c)
		add	a,0x80
		ld	h,a
		ret

draw_cell:	call	tile_ready
		ld	(tile_src),hl
		call	dc_scr
		jp	da_blit

; memfill_f: HL = начало, BC = число байт (кратно 16, не меньше 16), E = байт — через стек по 16 байт (~10 тактов
; на байт против ~70 у memfill). Прерывания на время запрещены, после — разрешены (только там, где разрешены и так)
memfill_f:	ld	a,e
		ld	(mf_v),a
		add	hl,bc			; HL = конец (стек пишет вниз)
		ld	a,c			; BC := BC / 16 — блоков
		rrca
		rrca
		rrca
		rrca
		and	0x0F
		ld	c,a
		ld	a,b
		rlca
		rlca
		rlca
		rlca
		and	0xF0
		or	c
		ld	c,a
		ld	a,b
		rrca
		rrca
		rrca
		rrca
		and	0x0F
		ld	b,a
		di
		ex	de,hl
		ld	hl,0
		add	hl,sp
		ld	(mf_sp),hl
		ex	de,hl
		ld	sp,hl
		ld	a,(mf_v)
		ld	h,a
		ld	l,a
mfl:		REPT	8
		push	hl
		ENDR
		dec	bc
		ld	a,b
		or	c
		jp	nz,mfl
		ld	hl,(mf_sp)
		ld	sp,hl
		ld	a,(in_isr)
		or	a
		ret	nz
		ei
		ret
