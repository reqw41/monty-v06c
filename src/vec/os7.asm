; Платформенный слой вместо BIOS ColecoVision OS7 и VDP TMS9918A: виртуальная VRAM в ОЗУ Вектора.
; Функции сохраняют все регистры, кроме выходных (READ_REGISTER -> A). Синтаксис Z80, только i8080.
;
; Виртуальная VRAM (адрес VDP -> ОЗУ):
;   0000-07FF, 0800-0FFF, 1000-17FF, 2800-2FFF — банки шаблонов тайлов 0, 1, 2, 5 -> E000, E800, F000, F800
;   1800-1AFF — таблица имён -> VNT;  1B00-1B7F — атрибуты спрайтов -> VSAT;  2000-201F — цвета -> VCOL
;   3800-3FFF — шаблоны спрайтов -> VSPR;  остальное — запись пропадает, чтение даёт 0
; Изменения для вывода: записи в банки, цвета и R4/R7 поднимают флаги в vdirty (см. display.asm).
VD_PAT		equ	0x01			; шаблоны тайлов
VD_COL		equ	0x02			; цвета
VD_NT		equ	0x04			; таблица имён (полная перерисовка комнаты)
VD_REG		equ	0x08			; R4/R7

; --- vmap: HL = адрес VDP -> HL = адрес в ОЗУ, CY = 1 — вне карты --------------------------------------
vmap:
		push	af
		ld	a,h
		and	0x3F
		ld	h,a
		cp	0x18
		jp	c,vm_pat		; 0000-17FF
		cp	0x1B
		jp	c,vm_nt			; 1800-1AFF
		jp	z,vm_sat		; 1B00-1BFF
		cp	0x20
		jp	z,vm_col		; 2000-20FF
		cp	0x28
		jp	c,vm_none
		cp	0x30
		jp	c,vm_b5			; 2800-2FFF
		cp	0x38
		jp	c,vm_none
		add	a,0x7400/256-0x38	; 3800-3FFF -> VSPR
		ld	h,a
		jp	vm_ok
vm_pat:		add	a,0xE0
		ld	h,a
		jp	vm_ok
vm_b5:		add	a,0xF8-0x28
		ld	h,a
		jp	vm_ok
vm_nt:		add	a,VNT/256-0x18
		ld	h,a
		jp	vm_ok
vm_sat:		ld	a,l
		cp	0x80
		jp	nc,vm_none
		ld	h,VSAT/256
		ld	a,l
		add	a,VSAT&0xFF
		ld	l,a
		jp	vm_ok
vm_col:		ld	a,l
		cp	0x20
		jp	nc,vm_none
		ld	h,VCOL/256
		add	a,VCOL&0xFF
		ld	l,a
vm_ok:		pop	af
		or	a
		ret
vm_none:	pop	af
		scf
		ret

; vmark: HL = адрес VDP — отметить цвета (VD_COL) или шаблоны (VD_PAT); байт за байтом — vmark_byte
vmark:
		push	af
		ld	a,h
		and	0x3F
		cp	0x20
		jp	nz,vmk_x
		ld	a,(vdirty)
		or	VD_COL
		ld	(vdirty),a
vmk_x:		pop	af
		ret

; vmark_byte: HL = адрес в ОЗУ после vmap — строка таблицы имён -> row_dirty, тайл банка -> pat_flag
vmark_byte:
		push	af
		ld	a,h
		cp	VNT/256
		jp	c,vb_spr
		cp	VNT/256+3
		jp	c,vb_nt
		cp	0xE0
		jp	c,vb_x
		push	hl			; шаблон: тайл = (HL >> 3) & FF -> pat_flag[тайл] := 1
		ld	a,l
		rrca
		rrca
		rrca
		and	0x1F
		ld	l,a
		ld	a,h
		rrca
		rrca
		rrca
		and	0xE0
		or	l
		ld	l,a
		ld	h,pat_flag/256
		ld	(hl),1
		ld	a,(vdirty)
		or	VD_PAT
		ld	(vdirty),a
		pop	hl
		jp	vb_x
vb_nt:		push	hl			; строка = (HL - VNT) >> 5
		push	bc
		ld	a,l
		rlca
		rlca
		rlca
		and	0x07
		ld	b,a
		ld	a,h
		sub	VNT/256
		add	a,a
		add	a,a
		add	a,a
		or	b
		ld	hl,row_dirty
		call	add_hl_a
		ld	(hl),1
		pop	bc
		pop	hl
vb_x:		pop	af
		ret
vb_spr:		cp	VSPR/256		; шаблоны спрайтов: таблицы обрезки — заново
		jp	c,vb_x
		xor	a
		ld	(anim_ok),a
		jp	vb_x

; --- vwrite: HL = адрес VDP, DE = источник, BC = байт: копирование в виртуальную VRAM ------------------
; Быстрый путь: начало и конец в одной непрерывной области — прямое копирование и отметка диапазона.
vwrite:
		ld	a,b
		or	c
		ret	z
		call	vmark
		call	vspan			; HL = ОЗУ начала, CY = 1 — не непрерывно
		jp	c,vw_slow
		push	hl			; копирование
		push	bc
vwf1:		ld	a,(de)
		ld	(hl),a
		inc	hl
		inc	de
		dec	bc
		ld	a,b
		or	c
		jp	nz,vwf1
		pop	bc
		pop	hl
		jp	vmark_range
vw_slow:	ld	hl,(vs_v)
vw1:		push	hl
		call	vmap
		jp	c,vw2
		ld	a,(de)
		ld	(hl),a
		call	vmark_byte
vw2:		pop	hl
		inc	hl
		inc	de
		dec	bc
		ld	a,b
		or	c
		jp	nz,vw1
		ret

; vread: HL = адрес VDP, DE = приёмник, BC = байт
vread:
		ld	a,b
		or	c
		ret	z
		call	vspan
		jp	c,vr_slow
vrf1:		ld	a,(hl)
		ld	(de),a
		inc	hl
		inc	de
		dec	bc
		ld	a,b
		or	c
		jp	nz,vrf1
		ret
vr_slow:	ld	hl,(vs_v)
vr1:		push	hl
		call	vmap
		ld	a,0
		jp	c,vr2
		ld	a,(hl)
vr2:		ld	(de),a
		pop	hl
		inc	hl
		inc	de
		dec	bc
		ld	a,b
		or	c
		jp	nz,vr1
		ret

; vspan: HL = адрес VDP, BC = байт -> HL = ОЗУ начала, CY = 0, если начало и конец отображаются непрерывно
; (vs_v := исходный HL)
vspan:
		ld	(vs_v),hl
		push	de
		push	hl
		add	hl,bc			; конец = начало + BC - 1
		dec	hl
		call	vmap
		jp	c,vsp_no
		ex	de,hl			; DE = ОЗУ конца
		pop	hl
		push	hl
		call	vmap
		jp	c,vsp_no
		push	hl			; ОЗУ конца - ОЗУ начала = BC - 1 ?
		ld	a,e
		sub	l
		ld	l,a
		ld	a,d
		sbc	a,h
		ld	h,a
		inc	hl
		ld	a,l
		cp	c
		jp	nz,vsp_no2
		ld	a,h
		cp	b
		jp	nz,vsp_no2
		pop	hl
		pop	de			; исходный HL
		pop	de
		or	a
		ret
vsp_no2:	pop	hl
vsp_no:		pop	hl
		pop	de
		scf
		ret

; vmark_range: HL = ОЗУ начала, BC = байт (непрерывно) — строки таблицы имён / тайлы банков / шаблоны спрайтов
vmark_range:
		ld	a,h
		cp	VNT/256
		jp	c,vmr_spr
		cp	VNT/256+3
		jp	c,vmr_nt
		cp	0xE0
		ret	c
		push	hl			; тайлы: от (HL >> 3) & FF, (BC + 7) / 8 + 1 штук
		push	bc
		ld	a,l
		rrca
		rrca
		rrca
		and	0x1F
		ld	e,a
		ld	a,h
		rrca
		rrca
		rrca
		and	0xE0
		or	e
		ld	l,a
		ld	h,pat_flag/256
		ld	a,c			; штук = BC / 8 + 2 (не больше 256)
		rrca
		rrca
		rrca
		and	0x1F
		ld	e,a
		ld	a,b
		rlca
		rlca
		rlca
		rlca
		rlca
		and	0xE0
		or	e
		add	a,2
		jp	nc,vmt1
		ld	a,0xFF
vmt1:		ld	e,a
vmt2:		ld	(hl),1
		inc	l
		dec	e
		jp	nz,vmt2
		ld	a,(vdirty)
		or	VD_PAT
		ld	(vdirty),a
		pop	bc
		pop	hl
		ret
vmr_nt:		push	hl			; строки: от (HL - VNT) >> 5 до (HL + BC - 1 - VNT) >> 5
		push	bc
		call	vnt_row
		ld	e,a
		add	hl,bc
		dec	hl
		call	vnt_row
		ld	d,a
		ld	hl,row_dirty
		ld	a,e
		call	add_hl_a
vmn1:		ld	(hl),1
		inc	hl
		ld	a,e
		cp	d
		jp	z,vmn2
		inc	e
		jp	vmn1
vmn2:		pop	bc
		pop	hl
		ret
vmr_spr:	cp	VSPR/256
		ret	c
		xor	a
		ld	(anim_ok),a
		ret
; vnt_row: HL = адрес в VNT -> A = строка (до 23); остальные регистры сохраняются
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

; --- FILL_VRAM: HL = адрес VDP, DE = число, A = байт -------------------------------------------------
os7_FILL_VRAM:
		push	af
		push	bc
		push	de
		push	hl
		ld	b,a
		call	vmark
		ld	a,h			; очистка таблицы имён (от 1800h, от 100h байт) — новая комната: палитра заново
		and	0x3F
		cp	0x18
		jp	nz,fv1
		ld	a,d
		or	a
		jp	z,fv1
		ld	a,(vdirty)
		or	VD_NT
		ld	(vdirty),a
		xor	a
		ld	(nt_age),a
fv1:		ld	a,d
		or	e
		jp	z,fv3
		push	hl
		call	vmap
		jp	c,fv2
		ld	(hl),b
		call	vmark_byte
fv2:		pop	hl
		inc	hl
		dec	de
		jp	fv1
fv3:		ld	a,b			; выход как у OS7: HL, B — как на входе, C = значение, DE = 0,
		ld	(fv_val),a		; A = статус (чтение статуса в конце сбрасывает флаг кадра)
		pop	hl
		pop	de
		pop	bc
		pop	af
		ld	a,(fv_val)
		ld	c,a
		ld	de,0
		ld	a,(vstat)
		push	af
		xor	a
		ld	(vstat),a
		pop	af
		ret

; --- адрес элемента таблицы: A = таблица, DE = элемент -> HL = адрес VDP, C = сдвиг (log2 размера) -----
; размер элемента: 0 атрибуты спрайта 4, 1 шаблон спрайта 8, 2 имя 1, 3 шаблон 8, 4 цвет 1 (Graphics I)
tab_addr:
		push	af
		push	de
		ld	c,0
		cp	0
		jp	nz,ta1
		ld	c,2
ta1:		cp	1
		jp	z,ta3
		cp	3
		jp	nz,ta2
ta3:		ld	c,3
ta2:		add	a,a			; база: (73F2 + 2 * таблица) — INIT_TABLE
		ld	l,a
		ld	h,0
		ld	de,0x73F2
		add	hl,de
		ld	e,(hl)
		inc	hl
		ld	d,(hl)
		pop	hl			; элемент
		push	hl
		ld	a,c
ta4:		or	a
		jp	z,ta5
		add	hl,hl
		dec	a
		jp	ta4
ta5:		add	hl,de
		pop	de
		pop	af
		ret

; число байт: z_iy << C -> BC
tab_count:
		push	hl
		ld	hl,(z_iy)
		ld	a,c
tc1:		or	a
		jp	z,tc2
		add	hl,hl
		dec	a
		jp	tc1
tc2:		ld	b,h
		ld	c,l
		pop	hl
		ret

; --- PUT_VRAM: A = таблица, DE = первый элемент, HL = источник, z_iy = число элементов ------------------
; Выход как у OS7 (1C27 -> 1D01): HL = источник + байт, BC = 0098h, D = FFh, E = младший байт числа байт,
; A = старший байт адреса VDP | 40h; особый путь (таблица 0 при 73C7 = 1, LDIR в ОЗУ): HL, DE += n, BC = 0.
os7_PUT_VRAM:
		cp	0			; таблица 0 при 73C7 = 1 — в копию атрибутов в ОЗУ ((8002) = 7300)
		jp	nz,pv1
		push	af
		ld	a,(0x73C7)
		cp	1
		jp	nz,pv0
		pop	af
		ex	de,hl			; DE = источник, HL = элемент
		add	hl,hl
		add	hl,hl
		ld	bc,0x7300
		add	hl,bc
		ex	de,hl			; DE = приёмник, HL = источник
		push	hl
		ld	hl,(z_iy)
		add	hl,hl
		add	hl,hl
		ld	b,h
		ld	c,l
		pop	hl
		jp	z_ldir
pv0:		pop	af
pv1:		push	hl			; источник
		call	tab_addr		; HL = адрес VDP, C = сдвиг
		call	tab_count		; BC = байт
		pop	de
		push	hl
		push	bc
		call	vwrite			; DE (источник) продвинут на BC
		pop	bc
		pop	hl
		ld	a,h
		or	0x40
		jp	vio_out

; --- GET_VRAM: A = таблица, DE = первый элемент, HL = приёмник, z_iy = число; выход как у OS7 (1BA3 -> 1D3E):
; HL = приёмник + байт, BC = 0098h, D = FFh, E = младший байт числа, A = старший байт адреса VDP
os7_GET_VRAM:
		push	hl
		call	tab_addr
		call	tab_count
		pop	de
		push	hl
		push	bc
		call	vread
		pop	bc
		pop	hl
		ld	a,h
vio_out:	ex	de,hl			; HL = источник/приёмник после копирования
		ld	e,c
		ld	d,0xFF
		ld	bc,0x0098
		ret

; --- WRITE_REGISTER: B = регистр, C = значение ----------------------------------------------------------
os7_WRITE_REGISTER:
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
		jp	z,wr9
		ld	a,b
		cp	0
		jp	nz,wr1
		ld	a,c
		ld	(0x73C3),a
		jp	wr9
wr1:		cp	1
		jp	nz,wr2
		ld	a,c
		ld	(0x73C4),a
		and	0x40			; экран включён — перерисовать всё (пока был выключен, не рисовали)
		jp	z,wr1a
		ld	a,(vdirty)
		or	VD_NT
		ld	(vdirty),a
		ld	a,2
		ld	(nt_age),a
wr1a:		jp	wr9			; (разрешение прерывания кадра: обработчик — в ближайшем ожидании, nmi_poll)
wr2:		cp	4
		jp	z,wr3
		cp	7
		jp	nz,wr9
wr3:		ld	a,(vdirty)
		or	VD_REG
		ld	(vdirty),a
wr9:		pop	hl
		pop	af
		ret

; --- READ_REGISTER: A = статус VDP (бит 7 — кадр), флаг сбрасывается ----------------------------------
os7_READ_REGISTER:
		ld	a,(vstat)
		push	af
		xor	a
		ld	(vstat),a
		pop	af
		ret

; --- MODE_1: регистры и базы таблиц режима Graphics I (18E9) --------------------------------------------
os7_MODE_1:
		push	af
		push	bc
		push	hl
		ld	bc,0x0000
		call	os7_WRITE_REGISTER
		ld	bc,0x0180
		call	os7_WRITE_REGISTER
		ld	hl,0x1800
		ld	(0x73F2+4),hl
		ld	hl,0x2000
		ld	(0x73F2+8),hl
		ld	hl,0x0000
		ld	(0x73F2+6),hl
		ld	hl,0x1B00
		ld	(0x73F2+0),hl
		ld	hl,0x3800
		ld	(0x73F2+2),hl
		ld	bc,0x0700
		call	os7_WRITE_REGISTER
		pop	hl
		pop	bc
		pop	af
		ret

; --- LOAD_ASCII: шрифт OS7 (158B, символы 1D..7C) и символ 0 (15A3) в таблицу шаблонов ------------------
os7_LOAD_ASCII:
		push	af
		push	de
		push	hl
		ld	hl,(z_iy)
		push	hl
		ld	hl,0x0060
		ld	(z_iy),hl
		ld	hl,os7_font
		ld	de,0x001D
		ld	a,3
		call	os7_PUT_VRAM
		ld	hl,1
		ld	(z_iy),hl
		ld	hl,os7_font+0x18
		ld	de,0
		ld	a,3
		call	os7_PUT_VRAM
		pop	hl
		ld	(z_iy),hl
		pop	hl
		pop	de
		pop	af
		ret

; --- INIT_SPR_ORDER: A = число спрайтов; таблица порядка ((8004) = 72E0) := 0, 1, … -------------------
os7_INIT_SPR_ORDER:
		push	af
		push	bc
		push	hl
		ld	b,a
		xor	a
		ld	hl,0x72E0
iso1:		ld	(hl),a
		inc	hl
		inc	a
		cp	b
		jp	nz,iso1
		pop	hl
		pop	bc
		pop	af
		ret

; --- WR_SPR_NM_TBL: A = число; атрибуты 7300 в порядке 72E0 -> VSAT -------------------------------------
os7_WR_SPR_NM_TBL:
		push	af
		push	bc
		push	de
		push	hl
		ld	b,a
		ld	de,VSAT
		ld	hl,0x72E0
wsn1:		push	hl
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
		jp	nz,wsn1
		ld	a,(vdirty)
		or	VD_SPR
		ld	(vdirty),a
		pop	hl
		pop	de
		pop	bc
		pop	af
		ret
VD_SPR		equ	0x10

; --- REFLECT_VERTICAL / REFLECT_HORIZONTAL / ENLARGE: A = таблица, DE = исходный элемент, HL = первый ----
; приёмник, BC = число. Элемент — 8 байт (шаблоны тайлов и спрайтов). VERTICAL — зеркально слева направо
; (биты каждого байта задом наперёд), HORIZONTAL — сверху вниз (байты задом наперёд), ENLARGE — каждый
; элемент в 4 (2x2, точка -> 2x2): приёмник HL, HL+1, HL+2, HL+3 — верх-лево, низ-лево, верх-право, низ-право.
os7_REFLECT_VERTICAL:
		push	af
		ld	a,1
		jp	gx
os7_REFLECT_HORIZONTAL:
		push	af
		ld	a,2
		jp	gx
os7_ENLARGE:
		push	af
		ld	a,3
gx:		ld	(gx_op),a
		pop	af
		push	af
		push	bc
		push	de
		push	hl
		ld	(gx_tab),a
		ld	(gx_dst),hl
gx1:		ld	a,b
		or	c
		jp	z,gx9
		push	bc
		push	de			; прочитать элемент DE в gx_buf
		ld	hl,1
		ld	(z_iy),hl
		ld	hl,gx_buf
		ld	a,(gx_tab)
		call	os7_GET_VRAM
		ld	a,(gx_op)
		cp	1
		call	z,gx_vert
		cp	2
		call	z,gx_horz
		cp	3
		jp	z,gx_enl
		ld	hl,(gx_dst)		; записать 1 элемент
		ex	de,hl
		ld	hl,gx_out
		ld	a,(gx_tab)
		call	os7_PUT_VRAM
		ld	hl,(gx_dst)
		inc	hl
		ld	(gx_dst),hl
gx2:		pop	de
		inc	de
		pop	bc
		dec	bc
		jp	gx1
gx9:		pop	hl
		pop	de
		pop	bc
		pop	af
		ret
gx_enl:		call	gx_enlarge		; 4 элемента в gx_big
		ld	hl,4
		ld	(z_iy),hl
		ld	hl,(gx_dst)
		ex	de,hl
		ld	hl,gx_big
		ld	a,(gx_tab)
		call	os7_PUT_VRAM
		ld	hl,(gx_dst)
		inc	hl
		inc	hl
		inc	hl
		inc	hl
		ld	(gx_dst),hl
		ld	hl,1
		ld	(z_iy),hl
		jp	gx2

gx_vert:	push	af			; gx_out[i] = биты gx_buf[i] задом наперёд
		ld	hl,gx_buf
		ld	de,gx_out
		ld	b,8
gv1:		ld	a,(hl)
		push	bc
		ld	c,a
		ld	b,8
gv2:		ld	a,c
		rra
		ld	c,a
		ld	a,(gx_t)
		rla
		ld	(gx_t),a
		dec	b
		jp	nz,gv2
		pop	bc
		ld	(de),a
		inc	hl
		inc	de
		dec	b
		jp	nz,gv1
		pop	af
		ret
gx_horz:	push	af			; gx_out[i] = gx_buf[7 - i]
		ld	hl,gx_buf+7
		ld	de,gx_out
		ld	b,8
gh1:		ld	a,(hl)
		ld	(de),a
		dec	hl
		inc	de
		dec	b
		jp	nz,gh1
		pop	af
		ret
gx_enlarge:	; строка y элемента -> строки 2y, 2y+1; левая половина байта -> левый элемент
		ld	hl,gx_buf
		ld	de,gx_big
		ld	b,8
ge1:		ld	a,(hl)			; левая половина: старшие 4 бита -> 8 бит
		rrca
		rrca
		rrca
		rrca
		call	ge_dbl
		push	af
		ld	a,(hl)
		call	ge_dbl			; правая половина
		push	hl
		ld	hl,16			; правые элементы: +16 (верх-право = 3-й элемент)
		add	hl,de
		ld	(hl),a
		inc	hl
		ld	(hl),a
		pop	hl
		pop	af
		ld	(de),a
		inc	de
		ld	(de),a
		inc	de
		inc	hl
		dec	b
		jp	nz,ge1
		ret
ge_dbl:		; младшие 4 бита A -> каждый бит дважды (бит 3 -> биты 7,6 …)
		push	hl
		and	0x0F
		ld	hl,dbl_tab
		add	a,l
		ld	l,a
		ld	a,h
		adc	a,0
		ld	h,a
		ld	a,(hl)
		pop	hl
		ret
dbl_tab:	db	0x00,0x03,0x0C,0x0F,0x30,0x33,0x3C,0x3F,0xC0,0xC3,0xCC,0xCF,0xF0,0xF3,0xFC,0xFF

; --- TURN_OFF_SOUND, CONTROLLER_SCAN — см. sound.asm и input.asm -----------------------------------------
