 ; Данные карты игры и прямые уведомления вывода.
; video_off/on: временно остановить вывод при построении комнаты.
video_off:	push	af
		xor	a
		ld	(video_enabled),a
		pop	af
		ret
video_on:	push	af
		ld	a,(video_enabled)
		or	a
		jp	nz,vo_done
		inc	a
		ld	(video_enabled),a
		ld	a,(video_dirty)
		or	DIRTY_ROOM
		ld	(video_dirty),a
		ld	a,2
		ld	(nt_age),a
vo_done:	pop	af
		ret

; nt_put: HL = источник, DE = клетка, C = число (B не используется) — в VNT, строки к перерисовке.
; HL, DE, BC сохраняются
nt_put:		push	hl
		push	de
		push	bc
		ld	a,c
		or	a
		jp	z,np_x
np1:		ld	a,d			; клетка < 300h?
		cp	3
		jp	nc,np_s
		push	hl
		ld	hl,VNT
		add	hl,de
		ex	(sp),hl			; (SP) = VNT + клетка, HL = источник
		ld	a,(hl)
		ex	(sp),hl
		ld	(hl),a
		call	mark_row
		pop	hl
np_s:		inc	hl
		inc	de
		dec	c
		jp	nz,np1
np_x:		pop	bc
		pop	de
		pop	hl
		ret

; nt_get: HL = приёмник, DE = клетка, C = число — из VNT (вне таблицы — 0). HL, DE, BC сохраняются
nt_get:		push	hl
		push	de
		push	bc
		ld	a,c
		or	a
		jp	z,np_x
ng1:		xor	a
		ld	b,a
		ld	a,d
		cp	3
		jp	nc,ng2
		push	hl
		ld	hl,VNT
		add	hl,de
		ld	b,(hl)
		pop	hl
ng2:		ld	(hl),b
		inc	hl
		inc	de
		dec	c
		jp	nz,ng1
		jp	np_x

; nt_read3: DE = клетка, HL = приёмник — 3 байта (для tiles.asm у края таблицы)
nt_read3:	push	bc
		ld	c,3
		call	nt_get
		pop	bc
		ret

; nt_fill: DE = клетка, BC = число, A = тайл. Очистка с первых 256 клеток длиной от 256 — новая комната
; (DIRTY_ROOM, nt_age := 0, как у слоя OS7). Регистры сохраняются
nt_fill:	push	af
		push	bc
		push	de
		push	hl
		ld	(nf_val),a
		ld	a,d
		or	a
		jp	nz,nf1
		ld	a,b
		or	a
		jp	z,nf1
		ld	a,(video_dirty)
		or	DIRTY_ROOM
		ld	(video_dirty),a
		xor	a
		ld	(nt_age),a
nf1:		ld	a,b
		or	c
		jp	z,nf9
		ld	a,d
		cp	3
		jp	nc,nf2
		ld	hl,VNT
		add	hl,de
		ld	a,(video_dirty)		; комната будет нарисована целиком — без отметок, быстро
		and	DIRTY_ROOM
		jp	nz,nf3
		ld	a,(nf_val)
		ld	(hl),a
		call	mark_row
nf2:		inc	de
		dec	bc
		jp	nf1
nf3:		push	hl			; BC := min(BC, конец таблицы - HL)
		ld	a,(VNT+768)&0xFF
		sub	l
		ld	e,a
		ld	a,(VNT+768)/256
		sbc	a,h
		ld	d,a			; DE = до конца
		ld	a,e
		sub	c
		ld	a,d
		sbc	a,b
		jp	nc,nf3b
		ld	b,d
		ld	c,e
nf3b:		pop	hl
		ld	a,c			; через стек — часть, кратная 16
		and	0xF0
		ld	e,a
		ld	a,b
		or	e
		jp	z,nf3a
		push	bc
		push	hl
		ld	c,e
		ld	a,(nf_val)
		ld	e,a
		call	memfill_f
		pop	hl
		pop	bc
		ld	a,c			; HL += сделанное, BC := остаток (< 16)
		and	0xF0
		add	a,l
		ld	l,a
		ld	a,h
		adc	a,b
		ld	h,a
		ld	a,c
		and	0x0F
		ld	c,a
		ld	b,0
		or	a
		jp	z,nf9
nf3a:		ld	a,(nf_val)		; HL -> клетка, BC клеток (не дальше конца таблицы)
nf4:		ld	(hl),a
		inc	hl
		dec	bc
		ld	e,a
		ld	a,h
		cp	(VNT+768)/256
		ld	a,e
		jp	z,nf9
		ld	a,b
		or	c
		ld	a,e
		jp	nz,nf4
nf9:		pop	hl
		pop	de
		pop	bc
		pop	af
		ret

; vnt_row: HL = адрес в VNT -> A = строка (до 23); регистры сохраняются
vnt_row:	push	de
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
		pop	de
		cp	24
		ret	c
		ld	a,23
		ret

; room_color_write: HL = источник, E = группа, C = число — в room_colors (DIRTY_COLOR). HL, DE, BC сохраняются
room_color_write:	push	hl
		push	de
		push	bc
		ld	d,room_colors/256
		ld	a,e
		add	a,room_colors&0xFF
		ld	e,a
cp1:		ld	a,(hl)
		ld	(de),a
		inc	hl
		inc	de
		dec	c
		jp	nz,cp1
		ld	a,(video_dirty)
		or	DIRTY_COLOR
		ld	(video_dirty),a
		jp	np_x
; room_color_fill: E = группа, C = число, A = цвет
room_color_fill:	push	hl
		push	de
		push	bc
		ld	h,room_colors/256
		ld	b,a
		ld	a,e
		add	a,room_colors&0xFF
		ld	l,a
cf1:		ld	(hl),b
		inc	hl
		dec	c
		jp	nz,cf1
		ld	a,(video_dirty)
		or	DIRTY_COLOR
		ld	(video_dirty),a
		jp	np_x

; dl_add (mark_row): HL = адрес клетки в VNT -> в список изменённых клеток (dlist, до DL_MAX; больше — dl_ovf,
; вывод тогда по всем строкам). Регистры, кроме A, сохраняются
mark_row:
dl_add:		ld	a,(video_dirty)		; комната будет нарисована целиком — клетки не отмечать
		and	DIRTY_ROOM
		ret	nz
		push	de
		ld	e,(hl)			; в клетке живой тайл (огонь, лента...) — список живых клеток устарел
		ld	d,lv_idx/256
		ld	a,(de)
		inc	a
		jp	z,dla1
		ld	(lv_dirty),a
dla1:
		ld	a,h			; уже ждёт вывода (PND бит 0; бит 1 — под спрайтом, force_live_t) — в списке есть
		add	a,(PND-VNT)/256
		ld	d,a
		ld	e,l
		ld	a,(de)
		call	cover_dirty
		ld	a,(de)
		rrca
		jp	c,dla_x
		rlca
		inc	a
		ld	(de),a
		ld	a,(dl_n)
		cp	DL_MAX
		jp	nc,dla_o
		inc	a
		ld	(dl_n),a
		dec	a
		add	a,a
		ld	e,a
		ld	d,dlist/256
		ld	a,l
		ld	(de),a
		inc	e
		ld	a,h
		ld	(de),a
		pop	de
		ret
dla_o:		ld	a,1
		ld	(dl_ovf),a
dla_x:		pop	de
		ret
