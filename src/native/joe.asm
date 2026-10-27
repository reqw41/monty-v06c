; Джо: единый образ в F900..F9CE (бывший фон верхнего слоя).
; N=3*R: маска сохранения N байт, затем N пар (маска, данные A000).
; 8000: данные 0; C000: данные = ~маска. Цвета 6/11 имеют индексы 3/1.
; Фон остаётся в FA00..FACE, исходные маски слоёв D0..FF не трогаются.
; Код работает из свободных хвостов FB30..FECF: фон врага занимает <=48 байт.
joe_source0:
		DISP 0xFB30
joe_prepare:
		ld a,(joe_changed)
		or a
		ret z
		ld a,(joe_fast)
		ld (joe_was_fast),a
		xor a
		ld (joe_fast),a
		ld a,(spr_rec)		; прежний верхний слой не должен иметь фона
		or a
		jp z,jp_attrs
		ld a,(spr_rec+14)
		or a
		ret nz
jp_attrs:	ld a,(spr_new+15)
		dec a
		ret nz
		ld a,(spr_new+16+15)
		or a
		ret nz
		ld a,(spr_new+14)
		or a
		ret z
		ld a,(spr_new+16+14)
		or a
		ret z
		ld a,(spr_new+4)
		ld b,a
		ld a,(spr_new+16+4)
		add a,b
		cp 17
		ret nz
		ld a,b
		cp 6
		ld a,0x2F		; CMA: 6 снизу, 11 сверху
		jp nz,jp_color
		xor a			; NOP: 6 сверху
jp_color:	ld c,a
		call joe_cache_test
		jp z,joe_cached_ready
		ld a,(joe_rows)
		add a,3
		rrca
		rrca
		and 0x3F
		ld (joe_groups),a
		ld a,(joe_rows)
		ld b,a
		add a,a
		add a,b
		ld (joe_n),a
		ld b,a
		add a,a
		add a,b
		ld (jm_end+1),a
		ld hl,live_code
		ld de,0xF9D0
		ld bc,spr_new+9
		call joe_expand
		ld hl,0xF900
		ld de,0xFAD0
		ld bc,spr_new+16+9
		call joe_expand
		jp joe_merge
jb_done:	ld a,c
jb_bg_sub:	sub 0
		ld c,a
		ld a,(sp_pm)
		sub 0x20
		ld (sp_pm),a
		cp 0x60
		jp nz,jb_plane
		ret
joe_dirty_set:	ld a,1
		ld (joe_dirty),a
		ret
joe_cached_ready:	ld a,1
		ld (joe_fast),a
		ret
		ENT
joe_end0:
		ASSERT joe_end0-joe_source0 <= 160

joe_source1:
		DISP 0xFC30
; HL — назначение (3*R байт), DE — маски слоя, BC — его геометрия.
joe_expand:
		push de
		push bc
		push hl
		ld a,(joe_n)
		ld b,a
		xor a
je_zero:	ld (hl),a
		inc hl
		dec b
		jp nz,je_zero
		pop de
		pop hl
		ld a,(svr+4)
		sub (hl)
		call add_de_a
		inc l
		inc l
		ld b,(hl)		; строки исходного слоя
		inc l
		ld a,(hl)
		ld (en_zero),a
		pop hl			; исходная маска
		ld a,3
		ld (cl_n),a
je_col:	push bc
		push hl
		push de
		ld a,(en_zero)
		rrca
		ld (en_zero),a
		jp c,je_next
je_row:	ld a,(hl)
		ld (de),a
		inc hl
		inc de
		dec b
		jp nz,je_row
je_next:	pop de
		ld a,(joe_rows)
		call add_de_a
		pop hl
		ld a,16
		call add_hl_a
		pop bc
		ld a,(cl_n)
		dec a
		ld (cl_n),a
		jp nz,je_col
		ret
add_de_a:	add a,e
		ld e,a
		ret nc
		inc d
		ret
joe_merge:
		ld de,live_code
		ld hl,0xF900
		ld b,h
		ld a,(joe_n)
		ld c,a
jm_row:	ld a,(de)
jm_alpha:	cpl
		ld (jm_bits+1),a
		ld a,(de)
		or (hl)
		cpl
		ld (hl),a
		ld (bc),a
		inc c
		cpl
jm_bits:	and 0
		ld (bc),a
		inc c
		inc l
		inc de
		ld a,c
jm_end:	cp 0
		jp nz,jm_row
		ld a,1
		ld (joe_fast),a
		ret
joe_cache_test:
		ld hl,jm_alpha
		ld a,c
		cp (hl)
		ld (hl),a
		call nz,joe_dirty_set
		ld a,(svr+6)
		ld hl,joe_rows
		cp (hl)
		ld (hl),a
		call nz,joe_dirty_set
		jp joe_cache_rest
		ENT
joe_end1:
		ASSERT joe_end1-joe_source1 <= 160

joe_source2:
		DISP 0xFD30
joe_blit:
		ld a,0xC0
		ld (sp_pm),a
		call joe_bg_setup
jb_plane:
		ld hl,spr_rec+16+9
		call en_load
		ld a,(joe_rows)
		ld (en_stride),a
		ld hl,jr_and
		ld a,(sp_pm)
		cp 0xA0
		ld a,0
		jp nz,jb_entry
		ld a,(en_stride)
		add a,a
		ld (en_stride),a
		ld hl,jr_mix
		ld a,(joe_n)
jb_entry:	ld (en_mask),a
		ld a,(sp_pm)
		cp 0xC0
		jp nz,jb_skip
		ld hl,jr_or
jb_skip:	ld a,(joe_rows)
		cpl
		inc a
		and 3
		jp z,jb_address
		ld e,a
		add a,a
		add a,a
		add a,a
		ld d,a
		ld a,(sp_pm)
		cp 0x80
		ld a,d
		jp z,jb_and_offset
		add a,e
		jp jb_offset
jb_and_offset:	sub e
jb_offset:	call add_hl_a
jb_address:	ld (jb_call+1),hl
		ld a,3
		ld (cl_n),a
jb_col:	ld a,(en_zero)
		rrca
		ld (en_zero),a
		jp c,jb_next
		ld a,(sv_col)
		cp 32
		jp nc,jb_done
		ld d,a
		ld a,(sp_pm)
		add a,d
		ld d,a
		ld a,(sv_lo)
		ld e,a
		ld a,(en_mask)
		ld l,a
		ld h,0xF9
		ld a,(joe_groups)
		ld (jr_ac+1),a
		ld (jr_mc+1),a
		ld (jr_oc+1),a
jb_call:	call jr_and
		jp jb_next
		ENT
joe_end2:
		ASSERT joe_end2-joe_source2 <= 160

		ORG video_raw_end
joe_source3:
		DISP 0xFE30
jb_next:	ld hl,sv_col
		inc (hl)
		ld a,(en_stride)
		ld hl,en_mask
		add a,(hl)
		ld (hl),a
		ld hl,cl_n
		dec (hl)
		jp nz,jb_col
		jp jb_done

; Один проход: прежний экран -> фон, затем маска и данные -> экран.
jr_and:
		REPT 4
		ld a,(de)
		ld (bc),a
		and (hl)
		ld (de),a
		inc l
		inc c
		dec e
		ENDR
jr_ac:		ld a,0
		dec a
		ld (jr_ac+1),a
		jp nz,jr_and
		ret
jr_mix:
		REPT 4
		ld a,(de)
		ld (bc),a
		and (hl)
		inc l
		or (hl)
		ld (de),a
		inc l
		inc c
		dec e
		ENDR
jr_mc:		ld a,0
		dec a
		ld (jr_mc+1),a
		jp nz,jr_mix
		ret
jr_or:
		REPT 4
		ld a,(de)
		ld (bc),a
		cpl
		and (hl)
		cpl
		ld (de),a
		inc l
		inc c
		dec e
		ENDR
jr_oc:		ld a,0
		dec a
		ld (jr_oc+1),a
		jp nz,jr_or
		ret
		ENT
joe_end3:
		ASSERT joe_end3-joe_source3 <= 160
		ASSERT $ <= VNT
