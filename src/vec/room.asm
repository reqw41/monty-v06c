; Декодер описаний комнат (повтор DRAW_ROOM A067 картриджа; спецификация и сверка — tools/roomdec.py).
; Пишет теневую таблицу имён NT (32x24 + запас). Предметы и двери рисуются, враги пропускаются (ещё не взятые —
; флаги взятых объектов пока не ведутся). Синтаксис Z80, только команды i8080.

; --- room_draw: A = номер комнаты (0..98), lv_cur — уровень 1..3 --------------------------------------
room_draw:
		push	af
		ld	hl,NT			; строки 0-4 := 8, остальное := 0 (CLEAR_ROOM A1DF)
		ld	bc,0x00A0
		ld	e,8
		call	memfill
		ld	bc,NT_SIZE-0x00A0
		ld	e,0
		call	memfill
		call	hud_frame
		xor	a
		ld	(rd_depth),a
		ld	(rd_mir),a
		pop	af
		jp	rd_run

; --- rd_run: A = номер описания; рекурсивно (подописания 3E/3F) --------------------------------------
rd_run:
		ld	hl,(rd_p)		; сохранить состояние родителя
		push	hl
		ld	hl,(rd_end)
		push	hl
		ld	l,a
		ld	h,0
		add	hl,hl
		ld	de,ROOM_TAB
		add	hl,de
		ld	e,(hl)
		inc	hl
		ld	d,(hl)
		inc	hl
		ex	de,hl
		ld	(rd_p),hl
		ex	de,hl
		ld	e,(hl)
		inc	hl
		ld	d,(hl)
		ex	de,hl
		ld	(rd_end),hl
rd_loop:
		ld	hl,(rd_p)		; конец потока: p >= end
		ex	de,hl
		ld	hl,(rd_end)
		ld	a,e
		sub	l
		ld	a,d
		sbc	a,h
		jp	nc,rd_ret
		ex	de,hl			; HL = p
		ld	a,(hl)
		ld	(rd_k),a
		inc	hl
		ld	a,(hl)
		ld	(rd_p1),a
		inc	hl
		ld	a,(hl)
		ld	(rd_p2),a
		inc	hl
		ld	a,(hl)
		ld	(rd_p3),a
		ld	a,(rd_k)
		and	0x3E
		cp	0x3E
		jp	z,rd_call
		ld	a,(rd_k)
		and	0x3F
		ld	(rd_kk),a
		cp	0x10
		jp	z,rd_cond
		cp	0x11
		jp	z,rd_cond
		ld	a,(rd_k)		; позиция = ((K >> 6) & 3) << 8 | p1
		rlca
		rlca
		and	3
		ld	h,a
		ld	a,(rd_p1)
		ld	l,a
		ld	de,NT
		add	hl,de
		ld	(rd_pos),hl
		ld	a,(rd_kk)		; набор тайлов: TILESETS + ROOM_TS[K & 3F]
		ld	e,a
		ld	d,0
		ld	hl,ROOM_TS
		add	hl,de
		ld	e,(hl)
		ld	hl,TILESETS
		add	hl,de
		ld	(rd_t),hl
		ld	a,(rd_kk)
		cp	0x0B
		jp	z,rd_col4
		cp	0x20
		jp	c,rd_prim
		ld	a,(rd_depth)		; объекты — только в описании самой комнаты
		or	a
		jp	nz,rd_adv2
		ld	a,(rd_kk)
		cp	0x29
		jp	c,rd_item
		cp	0x30
		jp	c,rd_door
		jp	rd_adv2			; враги — спрайты

rd_ret:		pop	hl
		ld	(rd_end),hl
		pop	hl
		ld	(rd_p),hl
		ret

rd_adv1:	ld	a,1
		jp	rd_adv
rd_adv2:	ld	a,2
		jp	rd_adv
rd_adv3:	ld	a,3
		jp	rd_adv
rd_adv4:	ld	a,4
rd_adv:		ld	hl,(rd_p)
		add	a,l
		ld	l,a
		ld	a,h
		adc	a,0
		ld	h,a
		ld	(rd_p),hl
		jp	rd_loop

; 10/11: конец потока, если уровень < 2/6 + ((K >> 6) & 3)
rd_cond:
		ld	b,2
		cp	0x10
		jp	z,rdc1
		ld	b,6
rdc1:		ld	a,(rd_k)
		rlca
		rlca
		and	3
		add	a,b
		ld	b,a
		ld	a,(lv_cur)
		cp	b
		jp	c,rd_ret
		jp	rd_adv1

; 3E/3F: подописание (номер — байт после кода со сдвигом на флаг зеркала текущего потока)
rd_call:
		ld	hl,(rd_p)
		ld	a,(rd_mir)
		inc	a
		add	a,l
		ld	l,a
		ld	a,h
		adc	a,0
		ld	h,a
		ld	b,(hl)			; номер подописания
		ld	a,(rd_mir)		; сохранить флаг родителя и код вызова
		push	af
		ld	a,(rd_k)
		push	af
		and	1
		ld	(rd_mir),a
		ld	hl,rd_depth
		inc	(hl)
		ld	a,b
		call	rd_run
		ld	hl,rd_depth
		dec	(hl)
		pop	af			; код вызова
		and	1
		call	nz,rd_mirror
		pop	af
		ld	(rd_mir),a
		jp	rd_adv2

; T(n): A = n -> A = байт набора
rd_tn:		ld	hl,(rd_t)
		add	a,l
		ld	l,a
		ld	a,h
		adc	a,0
		ld	h,a
		ld	a,(hl)
		ret

; 0B: столбец ширины T(0) из тайлов T(1..), 4 строки
rd_col4:	ld	c,4
		ld	hl,(rd_pos)
		call	col_rows
		jp	rd_adv2

; примитивы: (K & 3F) < 20, вид (K >> 2) & 7
rd_prim:
		ld	a,(rd_kk)
		rrca
		rrca
		and	7
		cp	0
		jp	z,rp_rect
		cp	4
		jp	z,rp_rect
		cp	1
		jp	z,rp_tri
		cp	5
		jp	z,rp_tri
		cp	3
		jp	z,rp_strip
		cp	7
		jp	z,rp_pat
		; 2, 6: столбец ширины T(0), p2 строк; 6 — верхняя строка следующими T(0) тайлами
		push	af
		ld	a,(rd_p2)
		ld	c,a
		ld	hl,(rd_pos)
		call	col_rows
		pop	af
		cp	6
		jp	nz,rd_adv3
		xor	a
		call	rd_tn
		ld	b,a
		ld	hl,(rd_t)
		inc	hl
		ld	e,a
		ld	d,0
		add	hl,de
		ex	de,hl
		ld	hl,(rd_pos)
		call	memcpyb
		jp	rd_adv3

; col_rows: HL = клетка, C = строк: каждая строка — T(0) тайлов T(1..)
col_rows:	inc	c
		dec	c
		ret	z
		push	hl
		xor	a
		call	rd_tn
		ld	(rd_w),a
		pop	hl
cr1:		push	hl
		ld	hl,(rd_t)
		inc	hl
		ex	de,hl
		pop	hl
		push	hl
		ld	a,(rd_w)
		ld	b,a
		call	memcpyb
		pop	hl
		ld	de,32
		add	hl,de
		dec	c
		jp	nz,cr1
		ret

; 0,4: прямоугольник тайла T(1): K&1 ? (p2 x p3, длина 4) : (p2>>4 x p2&F, длина 3)
rp_rect:
		ld	a,1
		call	rd_tn
		ld	e,a			; E = тайл
		ld	a,(rd_k)
		and	1
		jp	z,rr1
		ld	a,(rd_p2)
		ld	b,a
		ld	a,(rd_p3)
		ld	c,a
		call	rect
		jp	rd_adv4
rr1:		ld	a,(rd_p2)
		rrca
		rrca
		rrca
		rrca
		and	0x0F
		ld	b,a
		ld	a,(rd_p2)
		and	0x0F
		ld	c,a
		call	rect
		jp	rd_adv3

; rect: с rd_pos, B = ширина, C = высота, E = тайл
rect:		ld	hl,(rd_pos)
rect_hl:	inc	c
		dec	c
		ret	z
rc1:		push	hl
		push	bc
		ld	a,e
		call	fillb
		pop	bc
		pop	hl
		push	de
		ld	de,32
		add	hl,de
		pop	de
		dec	c
		jp	nz,rc1
		ret

; 1,5: треугольник: прямоугольник T(3) p2 x p2*tall, лесенка T(1) ширинами p2-1..1 по tall строк,
; сдвиг вправо на 1 на ступень при K&1 (A27C)
rp_tri:
		ld	a,(rd_k)
		and	0x10
		ld	a,1
		jp	z,rt1
		inc	a
rt1:		ld	(rd_tall),a
		ld	a,3
		call	rd_tn
		ld	e,a
		ld	a,(rd_p2)
		ld	b,a
		ld	c,a
		ld	a,(rd_tall)
		cp	2
		jp	nz,rt2
		ld	a,c
		add	a,a
		ld	c,a
rt2:		call	rect
		ld	a,(rd_k)
		and	1
		ld	(rd_sh),a
		ld	hl,(rd_pos)
		call	add_hl_a		; q = pos + (K & 1)
		ld	a,1
		push	hl
		call	rd_tn
		pop	hl
		ld	e,a			; E = T(1)
		ld	a,(rd_p2)
		ld	d,a			; D = n
rt3:		dec	d
		jp	z,rd_adv3
		ld	a,(rd_tall)
		ld	c,a
		ld	b,d
		push	de
		push	hl
		call	rect_hl
		pop	hl
		ld	a,(rd_tall)		; q += 32 * tall + (K & 1)
		ld	de,32
		add	hl,de
		cp	1
		jp	z,rt4
		add	hl,de
rt4:		ld	a,(rd_sh)
		call	add_hl_a
		pop	de
		jp	rt3

; 3: полоса p2 клеток: T(1) x p2, T(2) x (p2-1), T(3) x 1 — все с начала полосы
rp_strip:
		ld	a,1
		call	rd_tn
		ld	e,a
		ld	a,(rd_p2)
		ld	b,a
		ld	hl,(rd_pos)
		ld	a,e
		call	fillb
		ld	a,2
		call	rd_tn
		ld	e,a
		ld	a,(rd_p2)
		dec	a
		ld	b,a
		ld	hl,(rd_pos)
		ld	a,e
		call	fillb
		ld	a,3
		call	rd_tn
		ld	hl,(rd_pos)
		ld	(hl),a
		jp	rd_adv3

; 7: T(0) == FF ? p2 подряд тайлов T(1..) : p2 раз подряд узор T(1..T(0))
rp_pat:
		xor	a
		call	rd_tn
		ld	hl,(rd_t)
		inc	hl
		ex	de,hl
		ld	hl,(rd_pos)
		cp	0xFF
		jp	nz,rpp1
		ld	a,(rd_p2)
		ld	b,a
		call	memcpyb
		jp	rd_adv3
rpp1:		ld	c,a			; ширина узора
		ld	a,(rd_p2)
		or	a
		jp	z,rd_adv3
rpp2:		push	af
		push	de
		ld	b,c
		call	memcpyb			; HL продвигается
		pop	de
		pop	af
		dec	a
		jp	nz,rpp2
		jp	rd_adv3

; предмет 2x2: T(1) T(2) / T(3) T(4)
rd_item:
		ld	hl,(rd_t)
		inc	hl
		ex	de,hl
		ld	hl,(rd_pos)
		ld	b,2
		call	memcpyb
		ld	hl,(rd_pos)
		ld	bc,32
		add	hl,bc
		ld	b,2
		call	memcpyb
		jp	rd_adv2

; дверь (закрытая): T(1) в трёх клетках столбца, T(2) под ними
rd_door:
		ld	a,1
		call	rd_tn
		ld	e,a
		ld	a,2
		call	rd_tn
		ld	d,a
		ld	hl,(rd_pos)
		ld	bc,32
		ld	(hl),e
		add	hl,bc
		ld	(hl),e
		add	hl,bc
		ld	(hl),e
		add	hl,bc
		ld	(hl),d
		jp	rd_adv2

; зеркалирование строк 5-23 (MIRROR_ROOM AB29): пары mirror_pairs (кроме 0 и 8), разворот строки
rd_mirror:
		ld	hl,NT+5*32
		ld	c,19
rm1:		push	hl
		ld	b,32
rm2:		ld	a,(hl)
		or	a
		jp	z,rm4
		cp	8
		jp	z,rm4
		ld	d,a
		push	hl
		ld	hl,mirror_pairs
rm3:		ld	a,(hl)
		cp	0xFF
		jp	z,rm3x
		cp	d
		inc	hl
		jp	z,rm3f
		inc	hl
		jp	rm3
rm3f:		ld	e,(hl)
		pop	hl
		ld	(hl),e
		jp	rm4
rm3x:		pop	hl
rm4:		inc	hl
		dec	b
		jp	nz,rm2
		pop	hl			; разворот строки: HL — начало, DE — конец
		push	hl
		ld	a,l
		add	a,31
		ld	e,a
		ld	a,h
		adc	a,0
		ld	d,a
		ld	b,16
rm5:		ld	a,(de)
		push	af
		ld	a,(hl)
		ld	(de),a
		pop	af
		ld	(hl),a
		inc	hl
		dec	de
		dec	b
		jp	nz,rm5
		pop	hl
		ld	de,32
		add	hl,de
		dec	c
		jp	nz,rm1
		ret

; --- рамка интерфейса (AA5D) и интерфейс после потока (A548) ------------------------------------------
hud_frame:
		ld	hl,NT+0x01
		ld	b,10
		ld	a,0x09
		call	fillb
		ld	hl,NT+0x81
		ld	b,10
		ld	a,0x0C
		call	fillb
		ld	hl,NT+0x17
		ld	b,8
		ld	a,0x09
		call	fillb
		ld	hl,NT+0x97
		ld	b,8
		ld	a,0x0C
		call	fillb
		ld	hl,NT+0x20
		ld	c,3
hf1:		push	hl
		ld	de,hud_box
		ld	b,12
		call	memcpyb
		pop	hl
		push	hl
		ld	de,0x16
		add	hl,de
		ld	de,hud_box+1
		ld	b,10
		call	memcpyb
		pop	hl
		ld	de,32
		add	hl,de
		dec	c
		jp	nz,hf1
		ret

; счёт 0, уровень, пустой инвентарь, жизни (hud_lives - 1 шляп)
hud_after:
		ld	hl,NT+0x38
		ld	b,6
		xor	a
		call	fillb
		ld	hl,NT+0x58
		ld	b,6
		xor	a
		call	fillb
		ld	a,(lv_cur)
		add	a,0x18
		ld	(NT+0x34),a
		add	a,0x10
		ld	(NT+0x54),a
		ld	hl,NT+0x21
		ld	c,3
ha1:		push	hl
		ld	de,inv_blank
		ld	b,10
		call	memcpyb
		pop	hl
		ld	de,32
		add	hl,de
		dec	c
		jp	nz,ha1
		ld	hl,NT+0x61
		ld	b,8
		xor	a
		call	fillb
		ld	hl,NT+0x77
		ld	b,8
		xor	a
		call	fillb
		ld	a,(hud_lives)
		dec	a
		ret	z
		ld	b,a
		ld	hl,NT+0x61
		ld	a,0x6F
		jp	fillb

