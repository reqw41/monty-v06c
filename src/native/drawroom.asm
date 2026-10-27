; Нативно: рисование комнаты A067 и интерфейс (по src/model/drawroom.js, room.js). Рабочие ячейки — как у
; оригинала (7190-71B1, 72C0, 7086, 7304.., 707A, 71A2); указатели описаний (7190-7193) — адреса Вектора.
; Вывод — через L_AEA7 (блок клеток, src/native/block.asm), nt_fill, vid_reg.

; --- room.js -----------------------------------------------------------------------------------------------
; L_A4B5: A := ROW_BASE[71A7] + 71A8
L_A4B5:		ld	a,(0x71A7)
		ld	hl,C_A4C5
		call	add_hl_a
		ld	a,(0x71A8)
		add	a,(hl)
		ret
; L_A540: HL += A, A := (HL) (BC сохраняется)
L_A540:		add	a,l
		ld	l,a
		ld	a,h
		adc	a,0
		ld	h,a
		ld	a,(hl)
		ret
; L_A4CE: 71A5 := A; 7190..7193 := 4 байта таблицы описаний (C_9477 + 2A)
L_A4CE:		ld	(0x71A5),a
		add	a,a
		ld	hl,C_9477
		call	add_hl_a
		ld	de,0x7190
		ld	b,4
a4c1:		ld	a,(hl)
		ld	(de),a
		inc	hl
		inc	de
		dec	b
		jp	nz,a4c1
		ret
; L_A514: объект номер 71A2 (счётчик, +1) взят? бит n & 7 байта 70C0 + 71A1 + n / 8. CY — взят;
; выход: HL -> байт флагов, D = маска (для 92BE)
L_A514:		ld	a,(0x71A2)
		ld	b,a
		inc	a
		ld	(0x71A2),a
		ld	a,b
		rrca
		rrca
		rrca
		and	0x1F
		ld	c,a
		ld	a,(0x71A1)
		add	a,c
		ld	hl,0x70C0
		call	add_hl_a
		ld	a,b
		and	7
		ld	c,a
		ld	a,1
		inc	c
ob1:		dec	c
		jp	z,ob2
		add	a,a
		jp	ob1
ob2:		ld	d,a
		and	(hl)
		ret	z			; CY = 0 (после AND)
		scf
		ret

; --- вспомогательные ---------------------------------------------------------------------------------------
; ts_ptr: HL := C_9FD2 + (719A) + A (A — смещение от 9FD2: -1, 0, 2 ...)
ts9fd1:		ld	a,(0x719A)
		ld	hl,C_9FD1
		jp	add_hl_a
ts9fd2:		ld	a,(0x719A)
		ld	hl,C_9FD2
		jp	add_hl_a
; L_A4E3: 71B0 := (7197), 71B1 := старшие 2 бита (7196)
L_A4E3:		ld	a,(0x7196)
		rlca
		rlca
		and	3
		ld	(0x71B1),a
		ld	a,(0x7197)
		ld	(0x71B0),a
		ret
; L_A509: 71B0 += 20h
L_A509:		ld	hl,(0x71B0)
		ld	de,0x20
		add	hl,de
		ld	(0x71B0),hl
		ret
; L_A2D5: K & 1 — 71B0 += 1
L_A2D5:		ld	a,(0x7196)
		and	1
		ret	z
		ld	hl,(0x71B0)
		inc	hl
		ld	(0x71B0),hl
		ret
; aa96: AEA7 с шагом строки 32 (7000 бит 2)
L_AA96:		ld	a,(0x7000)
		or	4
		ld	(0x7000),a
		call	L_AEA7
		ld	a,(0x7000)
		and	0xFB
		ld	(0x7000),a
		ret

; --- примитивы описания (A21A..A340): выход A — длина команды -------------------------------------------------
; L_A257: D клеток тайла 719B в строке, E строк (71B0 — начало, по строке вниз); A := (71A0)
L_A257:		ld	a,d
		ld	(0x719D),a
		ld	a,e
		ld	(0x719E),a
a25a:		push	de			; E — счётчик строк (719E остаётся числом строк)
		ld	a,(0x719D)
		ld	b,a
		ld	c,1
		ld	hl,(0x71B0)
		ex	de,hl
		ld	hl,0x719B
		call	L_AEA7
		call	L_A509
		pop	de
		dec	e
		jp	nz,a25a
		ld	a,(0x71A0)
		ret
; L_A21A: прямоугольник тайла T(1)
L_A21A:		call	L_A4E3
		call	ts9fd2
		ld	a,(hl)
		ld	(0x719B),a
		ld	a,(0x7196)
		and	1
		jp	z,a21b
		ld	a,(0x7198)
		ld	d,a
		ld	a,(0x7199)
		ld	e,a
		ld	a,4
		ld	(0x71A0),a
		jp	L_A257
a21b:		ld	a,(0x7198)
		ld	e,a
		rrca
		rrca
		rrca
		rrca
		and	0x0F
		ld	d,a
		ld	a,e
		and	0x0F
		ld	e,a
		ld	a,3
		ld	(0x71A0),a
		jp	L_A257
; L_A27C: треугольник
L_A27C:		call	L_A4E3
		ld	a,(0x719A)
		ld	hl,C_9FD4
		call	add_hl_a
		ld	a,(hl)
		ld	(0x719B),a
		ld	a,(0x7198)
		ld	d,a
		ld	e,a
		ld	a,(0x7196)
		and	0x10
		jp	z,a27a
		ld	a,e
		add	a,a
		ld	e,a
a27a:		call	L_A257
		call	L_A4E3
		call	ts9fd2
		ld	a,(hl)
		ld	(0x719B),a
		call	L_A2D5
a27b:		ld	hl,0x7198
		dec	(hl)
		ld	a,3
		ret	z
		ld	d,(hl)
		ld	a,(0x7196)
		and	0x10
		rrca
		rrca
		rrca
		rrca
		inc	a
		ld	e,a
		call	L_A257
		call	L_A2D5
		jp	a27b
; L_A2F0: столбец: ширина T(0), (7198) строк тайлов T(1)..
L_A2F0:		call	L_A4E3
		call	ts9fd1
		ld	c,(hl)
		inc	hl
		ld	a,(0x7198)
		ld	b,a
		ex	de,hl
		ld	hl,(0x71B0)
		ex	de,hl
		call	L_AA96
		ld	a,3
		ret
; L_A30E: столбец + строка следующими T(0) тайлами (DE — как после AA96, т. е. прежний)
L_A30E:		call	L_A2F0
		ld	b,0
		add	hl,bc
		ld	b,1
		call	L_AA96
		ld	a,3
		ret
; L_A318: полоса с концами
L_A318:		call	L_A4E3
		call	ts9fd2
		ex	de,hl
		ld	hl,(0x71B0)
		ex	de,hl
		ld	c,1
		ld	a,(0x7198)
		ld	b,a
		call	L_AEA7
		inc	hl
		dec	b
		call	L_AEA7
		inc	hl
		ld	b,1
		call	L_AEA7
		ld	a,3
		ret
; L_A340: узор
L_A340:		call	L_A4E3
		call	ts9fd1
		ld	a,(hl)
		cp	0xFF
		jp	nz,a34a
		ld	a,(0x7198)
		ld	c,a
		ld	b,1
		jp	a34b
a34a:		ld	c,a
		ld	a,(0x7198)
		ld	b,a
a34b:		inc	hl
		ex	de,hl
		ld	hl,(0x71B0)
		ex	de,hl
		call	L_AEA7
		ld	a,3
		ret
; L_A2E3: код 0B — столбец в 4 строки
L_A2E3:		ld	a,4
		ld	(0x7198),a
		call	L_A2F0
		ld	a,2
		ret

; --- объекты ---------------------------------------------------------------------------------------------
; L_A394: HL := 72C0 + 2 * (71A2), A := (HL)
L_A394:		ld	a,(0x71A2)
		add	a,a
		ld	hl,0x72C0
		jp	L_A540
; L_A3A0: позиция объекта (71B0) — в список 72C0
L_A3A0:		call	L_A394
		ex	de,hl
		ld	hl,(0x71B0)
		ex	de,hl
		ld	(hl),e
		inc	hl
		ld	(hl),d
		ret
; L_A378: предмет 2x2 набора A в клетку DE (DE — сохраняется)
L_A378:		ld	hl,C_9FD2
		call	L_A540
		ld	bc,0x0102
		call	L_AEA7
		inc	hl
		inc	hl
		push	de
		ex	de,hl
		ld	bc,0x20
		add	hl,bc
		ex	de,hl
		ld	bc,0x0102
		call	L_AEA7
		pop	de
		ret
; L_A36A: предмет
L_A36A:		call	L_A514
		jp	c,a36x
		call	L_A4E3
		call	L_A3A0
		ld	a,(0x719A)
		call	L_A378
a36x:		ld	a,2
		ret
; L_A3D5: 2 тайла набора A в клетку (71B0)
L_A3D5:		ld	hl,C_9FD2
		call	add_hl_a
		ld	bc,0x0102
		ex	de,hl
		ld	hl,(0x71B0)
		ex	de,hl
		jp	L_AEA7
; L_A3F1: открытая дверь набора A в клетке (71B0): 2x1 и 2x3 под ними
L_A3F1:		call	L_A3D5
		inc	hl
		inc	hl
		ex	de,hl
		ld	bc,0x20
		add	hl,bc
		ex	de,hl
		ld	bc,0x0302
		call	L_AA96
		ld	a,2
		ret
; L_A3AB: дверь
L_A3AB:		call	L_A514
		jp	nc,a3b1
		call	L_A4E3			; открыта
		ld	a,(0x719A)
		add	a,2
		jp	L_A3F1
a3b1:		call	L_A4E3
		call	L_A3A0
		call	ts9fd2
		ld	bc,0x0301
		ex	de,hl
		ld	hl,(0x71B0)
		ex	de,hl
		call	L_AA96
		inc	hl
		ex	de,hl
		ld	bc,0x60
		add	hl,bc
		ex	de,hl
		ld	bc,0x0101
		call	L_AEA7
		ld	a,2
		ret
; L_A405: враг — атрибуты спрайта 7304 + 4n, список 7086, позиция в 72C0
L_A405:		call	L_A514
		ld	a,2
		ret	c
		ld	hl,0x707A
		inc	(hl)
		ld	a,(hl)
		ld	(a4_n),a
		add	a,a
		add	a,a
		ld	c,a
		call	L_A394
		ld	(hl),c
		inc	hl
		ld	(hl),0xFF
		ld	hl,0x7304		; p = 7304 + 4n
		ld	a,c
		call	add_hl_a
		push	hl
		ld	a,(0x7197)		; Y := ENEMY_Y[младшая тетрада]
		and	0x0F
		ld	de,C_A496
		call	de_add_a
		ld	a,(de)
		ld	(hl),a
		inc	hl
		ld	a,(0x7197)		; X := A4A5[старшая тетрада]
		rrca
		rrca
		rrca
		rrca
		and	0x0F
		ld	de,C_A4A5
		call	de_add_a
		ld	a,(de)
		ld	(hl),a
		inc	hl
		ld	a,(0x719A)
		ld	e,0x48
		cp	0x86
		jp	nz,a40a
		dec	hl			; набор 86: Y - 2
		dec	hl
		dec	(hl)
		dec	(hl)
		inc	hl
		inc	hl
		jp	a40c
a40a:		ld	e,0x10
		cp	0x88
		jp	z,a40c
		ld	e,8
a40c:		push	hl
		ld	hl,0x7086		; свободное место списка врагов
a40d:		ld	a,(hl)
		cp	0xFF
		jp	z,a40e
		inc	hl
		inc	hl
		jp	a40d
a40e:		ld	a,(a4_n)
		inc	a
		add	a,e
		ld	(hl),a
		inc	hl
		ld	a,(0x7196)
		and	0x40
		jp	z,a40f
		ld	a,0x80
a40f:		ld	(hl),a
		call	ts9fd1			; имя, цвет из T(0), T(1)
		ld	d,(hl)
		inc	hl
		ld	a,(hl)
		pop	hl
		ld	(hl),a
		inc	hl
		ld	(hl),d
		pop	de
		ld	a,2
		ret

; --- зеркало AB29: строки 5..22 — пары тайлов (AB0C) и разворот (строка 23 читается, но не пишется) --------
L_AB29:		push	hl
		push	de
		push	bc
		push	af
		ld	a,0x13
		ld	(0x7002),a
		ld	de,0xA0
ab1:		push	de
		ld	hl,0x7200		; строка -> 7200
		ld	c,0x20
		call	nt_get
		ld	hl,0x7200		; пары тайлов
		ld	b,0x20
ab2:		ld	a,(hl)
		cp	8
		jp	z,ab5
		or	a
		jp	z,ab5
		push	hl
		ld	c,a
		ld	hl,C_AB0C
ab3:		ld	a,(hl)
		cp	0xFF
		jp	z,ab4
		cp	c
		jp	z,ab3y
		inc	hl
		inc	hl
		jp	ab3
ab3y:		inc	hl
		ld	a,(hl)
		pop	hl
		ld	(hl),a
		jp	ab5
ab4:		pop	hl
ab5:		inc	hl
		dec	b
		jp	nz,ab2
		pop	de
		ld	hl,0x7002
		dec	(hl)
		jp	z,ab9
		ld	hl,0x7200		; разворот -> 7280..729F
		push	de
		ld	de,0x729F
		ld	b,0x20
ab6:		ld	a,(hl)
		ld	(de),a
		inc	hl
		dec	de
		dec	b
		jp	nz,ab6
		pop	de
		ld	hl,0x7280
		ld	c,0x20
		call	nt_put
		ld	hl,0x20
		add	hl,de
		ex	de,hl
		jp	ab1
ab9:		pop	af
		pop	bc
		pop	de
		pop	hl
		ret

; --- интерфейс ------------------------------------------------------------------------------------------------
; L_AAA8: строка B x C тайлов AA94 с клетки DE и AA95 на 4 строки ниже
L_AAA8:		ld	hl,C_AA94
		call	L_AEA7
		ex	de,hl
		ld	de,0x80
		add	hl,de
		ex	de,hl
		ld	hl,C_AA95
		jp	L_AEA7
; L_AA5D: рамка интерфейса
L_AA5D:		ld	de,1
		ld	bc,0x0A01
		call	L_AAA8
		ld	bc,0x0801
		ld	de,0x17
		call	L_AAA8
		ld	hl,C_AA88
		ld	bc,0x030C
		ld	de,0x20
		call	L_AA96
		ld	de,0x36
		ld	hl,C_AA89
		ld	bc,0x030A
		jp	L_AA96
; L_A1DF: очистка поля (строки 5..23); вне вступления или в столбце 10 — верх (строки 0..4) и рамка
L_A1DF:		ld	de,0xA0
		ld	bc,0x0260
		xor	a
		call	nt_fill
		ld	a,(0x705F)
		and	4
		jp	z,a1d1
		ld	a,(0x71A8)
		cp	0x0A
		ret	nz
a1d1:		ld	de,0
		ld	bc,0xA0
		ld	a,8
		call	nt_fill
		jp	L_AA5D
; L_AF66: тайл A в клетку HL (HL += 1; DE сохраняется)
L_AF66:		push	de
		push	bc
		ex	de,hl
		ld	bc,1
		call	nt_fill
		ex	de,hl
		inc	hl
		pop	bc
		pop	de
		ret
; L_AF54: цифра младшей тетрады A (ведущие нули — пусто, флаг 70B1 бит 0), основа C
L_AF54:		and	0x0F
		jp	nz,af5a
		push	hl
		ld	hl,0x70B1
		ld	a,(hl)
		and	1
		pop	hl
		jp	z,L_AF66		; A = 0: пустая клетка
		xor	a
af5a:		add	a,c
		push	hl
		ld	hl,0x70B1
		ld	b,a
		ld	a,(hl)
		or	1
		ld	(hl),a
		ld	a,b
		pop	hl
		jp	L_AF66
; L_AF32: 3 байта BCD 7017.. -> 6 цифр с клетки HL (основа C)
L_AF32:		ld	de,0x7017
		ld	b,3
af31:		push	bc
		ld	a,(de)
		rrca
		rrca
		rrca
		rrca
		call	L_AF54
		pop	bc
		push	bc
		ld	a,(de)
		call	L_AF54
		pop	bc
		inc	de
		dec	b
		jp	nz,af31
		ld	a,(0x70B1)
		and	0xFE
		ld	(0x70B1),a
		ret
; L_AEFE: счёт (две строки цифр) и номер уровня (регистры сохраняются)
L_AEFE:		push	hl
		push	bc
		push	de
		push	af
		ld	hl,0x38
		ld	c,0x18
		call	L_AF32
		ld	hl,0x58
		ld	c,0x28
		call	L_AF32
		ld	hl,0x34
		ld	a,(0x71A6)
		add	a,0x18
		call	L_AF66
		ld	hl,0x54
		ld	a,(0x71A6)
		add	a,0x28
		call	L_AF66
		pop	af
		pop	de
		pop	bc
		pop	hl
		ret
; L_AABB: жизни — (7049) - 1 шляп (6F) с клетки 61h и 77h (не в сокровищнице)
L_AABB:		ld	a,(0x705F)
		and	0x20
		ret	nz
		ld	de,0x61
		ld	bc,8
		xor	a
		call	nt_fill
		ld	de,0x77
		call	nt_fill
		ld	a,(0x7049)
		cp	1
		ret	z
		dec	a
		ld	c,a
		ld	b,0
		ld	de,0x61
		cp	0x0B
		jp	c,ab_l
		ld	c,0x0A			; 10 в первую строку, остаток (до 8) — во вторую
		ld	a,0x6F
		call	nt_fill
		ld	a,(0x7049)
		sub	0x0B
		ld	c,8
		cp	9
		jp	nc,ab_m
		ld	c,a
ab_m:		ld	de,0x77
ab_l:		ld	a,0x6F
		jp	nt_fill
; L_A548: инвентарь — счёт, очистка поля 3x10 с 21h, предметы из 71B2.., жизни
L_A548:		call	L_AEFE
		ld	de,0x21
		ld	hl,C_85D7
		ld	bc,0x030A
		call	L_AA96
		ld	hl,0x71B2
a548a:		ld	a,(hl)
		cp	0xFF
		jp	z,L_AABB
		push	hl
		push	de
		call	L_A378
		pop	de
		inc	de
		inc	de
		pop	hl
		inc	hl
		jp	a548a

; --- AE77 / AE83: прерывание VDP выкл. (70B3 += 1, R1 := 82) / вкл. при 70B3 = 0 (R1 := E2) -----------------
L_AE77:		ld	hl,0x70B3
		inc	(hl)
		jp	video_off
L_AE83:		ld	hl,0x70B3
		dec	(hl)
		ret	nz
		jp	video_on

; --- L_A067 DRAW_ROOM -----------------------------------------------------------------------------------------
L_A067:		call	L_AE77
		call	snd_off
		ld	hl,0x7086		; список врагов пуст
		ld	b,15
		ld	a,0xFF
a06a:		ld	(hl),a
		inc	hl
		dec	b
		jp	nz,a06a
		ld	hl,0x72C0		; список объектов пуст, конец — FE FE
		ld	b,30
		xor	a
a06b:		ld	(hl),a
		inc	hl
		dec	b
		jp	nz,a06b
		ld	(hl),0xFE
		inc	hl
		ld	(hl),0xFE
		call	L_A1DF
		call	L_A4B5
		ld	(0x7015),a
		call	L_A4CE
		xor	a
		ld	(0x71A2),a
		ld	a,(0x71A5)
		add	a,a
		ld	(0x71A1),a
dr_loop:	ld	hl,(0x7190)		; конец потока?
		ex	de,hl
		ld	hl,(0x7192)
		ld	a,e
		cp	l
		jp	nz,dr_k
		ld	a,d
		cp	h
		jp	z,dr_end
dr_k:		ex	de,hl			; HL = указатель
		ld	a,(hl)
		ld	(0x7196),a
		and	0x3E
		cp	0x3E
		jp	z,dr_sub
		inc	hl			; 3 байта параметров -> 7197..7199
		ld	de,0x7197
		ld	b,3
dr_p:		ld	a,(hl)
		ld	(de),a
		inc	hl
		inc	de
		dec	b
		jp	nz,dr_p
		ld	a,(0x7196)		; A4F8: 719A := ROOM_TS[K & 3F]
		and	0x3F
		ld	hl,C_9444
		call	add_hl_a
		ld	a,(hl)
		ld	(0x719A),a
		ld	a,(0x7196)
		and	0x3F
		cp	0x10
		jp	z,dr_lv
		cp	0x11
		jp	z,dr_lv
		cp	0x0B
		jp	nz,dr_c
		call	L_A2E3
		jp	dr_adv
dr_c:		cp	0x20
		jp	nc,dr_obj
		ld	a,(0x7196)		; примитив по (K >> 2) & 7
		rrca
		ld	l,a
		and	0x0E
		ld	hl,dr_tab
		call	add_hl_a
		ld	a,(hl)
		inc	hl
		ld	h,(hl)
		ld	l,a
		ld	de,dr_adv
		push	de
		jp	(hl)
dr_obj:		ld	b,a
		ld	a,(0x7194)
		or	a
		ld	a,2
		jp	nz,dr_adv
		ld	a,b
		cp	0x29
		jp	nc,dr_o2
		call	L_A36A
		ld	a,2
		jp	dr_adv
dr_o2:		cp	0x30
		jp	nc,dr_o3
		call	L_A3AB
		ld	a,2
		jp	dr_adv
dr_o3:		call	L_A405
		ld	a,2
dr_adv:		ld	hl,(0x7190)		; указатель += A
		call	add_hl_a
		ld	(0x7190),hl
		jp	dr_loop
dr_lv:		ld	b,2			; 10/11: конец потока на младших уровнях
		cp	0x11
		jp	nz,dr_l1
		ld	b,6
dr_l1:		ld	a,(0x7196)
		rlca
		rlca
		and	3
		add	a,b
		ld	b,a
		ld	a,(0x71A6)
		cp	b
		jp	c,dr_end
		ld	a,1
		jp	dr_adv
dr_sub:		ld	a,(0x7190)		; в стек: 7190..7193, 7195
		ld	c,a
		ld	a,(0x7191)
		ld	b,a
		push	bc
		ld	a,(0x7192)
		ld	c,a
		ld	a,(0x7193)
		ld	b,a
		push	bc
		ld	a,(0x7195)
		ld	c,a
		push	bc
		ld	hl,(0x7190)		; номер подописания = (p + 7195 + 1)
		call	add_hl_a
		inc	hl
		ld	b,(hl)
		ld	a,(0x7196)
		and	1
		ld	(0x7195),a
		ld	hl,0x7194
		inc	(hl)
		ld	a,b
		call	L_A4CE
		jp	dr_loop
dr_end:		ld	a,(0x7194)		; конец потока: подописание — назад, иначе всё
		or	a
		jp	z,dr_fin
		dec	a
		ld	(0x7194),a
		ld	a,(0x7195)
		or	a
		call	nz,L_AB29
		pop	bc
		ld	a,c
		ld	(0x7195),a
		pop	bc
		ld	a,c
		ld	(0x7192),a
		ld	a,b
		ld	(0x7193),a
		pop	bc
		ld	a,c
		ld	(0x7190),a
		ld	a,b
		ld	(0x7191),a
		ld	a,2
		jp	dr_adv
dr_fin:		ld	a,(0x705F)		; интерфейс (кроме вступления не в столбце 10)
		and	4
		jp	z,dr_f1
		ld	a,(0x71A8)
		cp	0x0A
		jp	nz,dr_f2
dr_f1:		call	L_A548
dr_f2:		jp	L_AE83

dr_tab:		dw	L_A21A, L_A27C, L_A2F0, L_A318, L_A21A, L_A27C, L_A30E, L_A340
