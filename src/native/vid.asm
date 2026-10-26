; Нативный вывод: вместо VDP — копии VNT (таблица имён), VCOL (цвета), VSAT (атрибуты спрайтов), регистры
; vregs; шаблоны тайлов — банк 0 в E000 (+ различия банков), шаблоны спрайтов — VSPR. Отметки для вывода
; (display.asm): row_dirty — строки таблицы имён (только при переполнении списка), vdirty — VD_NT (вся комната), VD_COL, VD_PAT, VD_REG.
; Клетки вне таблицы имён (0..2FF) запись пропускает, чтение даёт 0.

; vid_reg: B = регистр, C = значение. R1: экран включён — всё заново; R4 (банк шаблонов), R7 — VD_REG
vid_reg:
		push	af
		push	hl
		ld	a,b
		and	7
		ld	l,a
		ld	h,0
		push	de
		ld	de,vregs
		add	hl,de
		pop	de
		ld	a,(hl)
		ld	(hl),c
		cp	c
		jp	z,vr9
		ld	a,b
		cp	1
		jp	nz,vr2
		ld	a,c
		and	0x40
		jp	z,vr9
		ld	a,(vdirty)
		or	VD_NT
		ld	(vdirty),a
		ld	a,2
		ld	(nt_age),a
		jp	vr9
vr2:		cp	4
		jp	z,vr3
		cp	7
		jp	nz,vr9
vr3:		ld	a,(vdirty)
		or	VD_REG
		ld	(vdirty),a
vr9:		pop	hl
		pop	af
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
; (VD_NT, nt_age := 0, как у слоя OS7). Регистры сохраняются
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
		ld	a,(vdirty)
		or	VD_NT
		ld	(vdirty),a
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
		ld	a,(vdirty)		; комната будет нарисована целиком — без отметок, быстро
		and	VD_NT
		jp	nz,nf3
		ld	a,(nf_val)
		ld	(hl),a
		call	mark_row
nf2:		inc	de
		dec	bc
		jp	nf1
nf3:		ld	a,(nf_val)		; HL -> клетка, BC клеток (не дальше конца таблицы)
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

; col_put: HL = источник, E = группа, C = число — в VCOL (VD_COL). HL, DE, BC сохраняются
col_put:	push	hl
		push	de
		push	bc
		ld	d,VCOL/256
		ld	a,e
		add	a,VCOL&0xFF
		ld	e,a
cp1:		ld	a,(hl)
		ld	(de),a
		inc	hl
		inc	de
		dec	c
		jp	nz,cp1
		ld	a,(vdirty)
		or	VD_COL
		ld	(vdirty),a
		jp	np_x
; col_fill: E = группа, C = число, A = цвет
col_fill:	push	hl
		push	de
		push	bc
		ld	h,VCOL/256
		ld	b,a
		ld	a,e
		add	a,VCOL&0xFF
		ld	l,a
cf1:		ld	(hl),b
		inc	hl
		dec	c
		jp	nz,cf1
		ld	a,(vdirty)
		or	VD_COL
		ld	(vdirty),a
		jp	np_x

; pat_put: E = тайл, HL = источник (8 байт) — шаблон во всех банках (банк 0, различий у E0/E8 нет);
; отличается — pat_flag[тайл], VD_PAT. HL, DE, BC сохраняются
pat_put:	push	hl
		push	de
		push	bc
		push	hl
		ld	l,e			; DE = E000 + 8 * тайл
		ld	h,0
		add	hl,hl
		add	hl,hl
		add	hl,hl
		ld	a,h
		add	a,0xE0
		ld	h,a
		ex	de,hl
		pop	hl
		ld	b,8
		ld	c,0			; изменилось?
pp1:		ld	a,(de)
		cp	(hl)
		jp	z,pp2
		ld	a,(hl)
		ld	(de),a
		ld	c,1
pp2:		inc	hl
		inc	de
		dec	b
		jp	nz,pp1
		ld	a,c
		or	a
		jp	z,np_x
		pop	bc
		pop	de
		push	de
		push	bc
		ld	l,e
		ld	h,pat_flag/256
		ld	(hl),1
		ld	a,e			; не лента и не цепь (E0, E8) — отметка «другие» (pat_oth)
		cp	0xE0
		jp	z,pp3
		cp	0xE8
		jp	z,pp3
		ld	a,1
		ld	(pat_oth),a
pp3:
		ld	a,(vdirty)
		or	VD_PAT
		ld	(vdirty),a
		jp	np_x

; sat_copy: A = число — атрибуты 7300 в порядке 72E0 -> VSAT (WR_SPR_NM_TBL). Регистры сохраняются
sat_copy:	push	af
		push	bc
		push	de
		push	hl
		ld	b,a
		ld	de,VSAT
		ld	hl,0x72E0
sc1:		push	hl
		ld	l,(hl)
		ld	h,0
		add	hl,hl
		add	hl,hl
		push	bc
		ld	bc,0x7300
		add	hl,bc
		REPT	4
		ld	a,(hl)
		ld	(de),a
		inc	hl
		inc	de
		ENDR
		pop	bc
		pop	hl
		inc	hl
		dec	b
		jp	nz,sc1
		pop	hl
		pop	de
		pop	bc
		pop	af
		ret

; dl_add (mark_row): HL = адрес клетки в VNT -> в список изменённых клеток (dlist, до DL_MAX; больше — dl_ovf,
; вывод тогда по всем строкам). Регистры, кроме A, сохраняются
mark_row:
dl_add:		ld	a,(vdirty)		; комната будет нарисована целиком — клетки не отмечать
		and	VD_NT
		ret	nz
		push	de
		ld	e,(hl)			; в клетке живой тайл (огонь, лента...) — список живых клеток устарел
		ld	d,lv_idx/256
		ld	a,(de)
		inc	a
		jp	z,dla1
		ld	(lv_dirty),a
dla1:
		ld	a,h			; уже ждёт вывода — в списке есть
		add	a,(PND-VNT)/256
		ld	d,a
		ld	e,l
		ld	a,(de)
		or	a
		jp	nz,dla_x
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
