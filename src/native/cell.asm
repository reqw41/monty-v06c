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
		cp	0xE0
		jp	c,tk_other
		cp	0xF0
		jp	nc,tk_other
		call	tile_belt_frames
		ld	c,a
		add	a,a
		add	a,c
		ld	c,a
		ret
tk_other:	ld	l,a
		ld	h,lv_idx/256
		ld	a,(hl)
		IFDEF NES_FULL
		jp nes_snake_tile_kind
		ELSE
		cp	17
		ld	c,4
		ret	c
		ld	c,1
		ret
		ENDIF
; Группы E0..EF: обычная лента A0, выключенный лазер 00, включённый 40.
tile_belt_frames:	ld	a,(rr_t)
		cp	0xE0
		ld	a,4
		ret	z
		ld	a,(rr_t)
		cp	0xE8
		ld	a,2
		ret	z
		ld	a,1
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
		IFDEF NES_FULL
		cp FULL_ANIM_N
		ELSE
		cp	17
		ENDIF
		ld	a,0
		jp	nc,tsel_add
		IFDEF NES_FULL
		call nes_snake_phase
		ELSE
		ld	a,(fire_shown)
		ENDIF
		jp	tsel_add
tsel_chain:	ld	a,(belt_shown)
		and	1
		jp	tsel_add
tsel_belt:	ld	a,(belt_shown)
tsel_add:	ld	c,a
		ld	a,(rr_t)
		cp	0xE0
		jp	c,tsel_color_done
		cp	0xF0
		jp	nc,tsel_color_done
		rrca
		rrca
		rrca
		and	31
		add	a,room_colors&255
		ld	l,a
		ld	h,room_colors/256
		ld	a,(hl)
		or	a
		jp	z,tsel_off
		cp	0x40
		jp	nz,tsel_color_done
		call	tile_belt_frames
		add	a,a
		jp	tsel_color_add
tsel_off:	call	tile_belt_frames
tsel_color_add:	add	a,c
		ld	c,a
tsel_color_done:	ld	a,c
		add	a,b
; tile_addr: A = номер образа -> HL = TILE_IMAGES + 24*A
tile_addr:	ld	l,a
		ld	h,0
		add	hl,hl
		add	hl,hl
		ld	d,h
		ld	e,l
		add	hl,hl
		add	hl,de
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
 IFDEF NES_FULL
 call dc_tile			; режимы первыми: C = 0 — клетка гаснет в темноте, готовые образы (двери B0/B7/C0/C7,
 ld a,c				; кирпичи, вазы) не берутся; иначе — как раньше (fix24)
 or a
 push bc
 push de
 call nz,style_image
 pop de
 pop bc
 jp c,tbuild_styled
 ELSE
 IFDEF NES_STYLE
 call style_image
 jp c,tbuild_styled
 ENDIF
		call	dc_tile
 ENDIF
		call	da_img
 IFDEF NES_FULL
 IFDEF NES_STABLE_COLORS
 call nes_terrain_image
 ELSE
 ld a,(rr_t)
 cp 0xE8
 call z,nes_platform_image
 ENDIF
 ENDIF
tbuild_styled:
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
		cp	0xE0
		jp	c,trc_rebuild
		cp	0xF0
		jp	c,trc_end
trc_rebuild:	ld	h,tile_slots/256
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
		call tile_belt_mode
 IFDEF NES_FULL
 call full_style_modes
 ELSE
 IFDEF NES_STYLE
 call style_modes
 ENDIF
 ENDIF
		ld	a,b
		cp	0xE0
		jp	z,dc_belt0
		cp	0xE8
		jp	z,dc_belt8
		ld	l,b
		ld	h,lv_idx/256
		ld	a,(hl)
		IFDEF NES_FULL
		cp FULL_ANIM_N
		ELSE
		cp	17
		ENDIF
		jp	nc,dc_base
 IFDEF NES_FULL
 add a,a
 add a,a
 ld b,a
 ld a,(tile_phase)
 add a,b
 ld hl,raw_anim
dc_strip_hl:                ; общий хвост с dc_base
 call add_hl_a
 ld a,(hl)
 jp full_strip
 ELSE
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
 ENDIF
dc_base:
 IFDEF NES_FULL
 ld a,(rr_t)
 ld hl,raw_base
 jp dc_strip_hl
 ELSE
	ld	a,(rr_t)
		ld	l,a
		ld	h,0
		add	hl,hl
		ld	de,raw_base
		add	hl,de
 ENDIF
dc_source:	ld	e,(hl)
		inc	hl
		ld	d,(hl)
		ret
 IFDEF NES_FULL
dc_belt0:
 ld a,(tile_phase)
 and 3
 ld hl,full_laser_v
 jp full_laser
dc_belt8:
 ld a,(tile_phase)
 and 3
 ld hl,full_laser_h
full_laser:
 call add_hl_a
 ld a,(hl)
full_strip:
 ld l,a
 ld h,0
 add hl,hl
 add hl,hl
 add hl,hl
 ld de,full_raw
 add hl,de
 ex de,hl
 ret
 ELSE
dc_belt0:	ld	a,(tile_phase)
		and	3
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

 ENDIF
; Все три цвета лент/лазеров готовы заранее, смена цвета только выбирает образ.
tile_belt_mode:	ld	a,b
		cp	0xE0
		ret	c
		cp	0xF0
		ret	nc
		push	bc
		call	tile_belt_frames
		ld	b,a
		ld	a,(tile_phase)
		cp	b
		jp	c,tbm_normal
		sub	b
		cp	b
		jp	c,tbm_off
		ld	a,(mb_d+4)
		jp	tbm_done
tbm_normal:	ld	a,(mb_d+10)
		jp	tbm_done
tbm_off:	xor	a
tbm_done:	pop	bc
		ld	c,a
		ret

; dc_scr: клетка -> экран (верхняя строка, плоскость 8000).
dc_scr:		ld	a,(rr_r)
		add	a,a
		add	a,a
		add	a,a
		cpl
		add a,(SCREEN_TOP+1)&255
 IFDEF NES_FULL
 ld b,a
 ld a,(rr_r)
 cp HUD_ROWS
 ld a,b
 jp c,dcs_hud
 sub FIELD_YSHIFT
 jp dcs_shifted
dcs_hud:
 sub HUD_YSHIFT
dcs_shifted:
 ENDIF
 IFDEF NES_STYLE
 IFNDEF NES_FULL
 ld b,a
 ld a,(rr_r)
 cp 3
 ld a,b
 jp nc,sts_normal
 add a,8
sts_normal:
 ENDIF
 ENDIF
		ld	l,a
		ld	a,(rr_c)
		add	a,0x80
		ld	h,a
		ret

draw_cell:
 IFDEF NES_STYLE
 IFNDEF NES_FULL
 ld a,(rr_t)
 call style_tile
 ld (rr_t),a
 ENDIF
 ENDIF
 call tile_ready
		ld	(tile_src),hl
		call	dc_scr
		jp	da_blit

 IFDEF NES_FULL
; Only room/reset/colour-change paths use this entry in NES_FULL.
; Share the general fill; its BC/DE/HL contract is the same for every caller.
memfill_f equ memfill
 ELSE
; Fill multiples of 16 without masking IRQ or changing SP; DE is preserved.
memfill_f:
		REPT	16
		ld	(hl),e
		inc	hl
		ENDR
		ld	a,c
		sub	16
		ld	c,a
		jp	nc,mff_count
		dec	b
mff_count:	ld	a,b
		or	c
		jp	nz,memfill_f
		ret

 ENDIF
