; Нативно: цвета и экраны (по src/model/screen.js) — таблицы цветов (AE00 с таблицей 4), 8308, цвета ряда и
; темнота 8EB0, сокровищница A60B.

; tab4: HL -> таблица (dw источник, db группа, db число)..., слово со старшим 0 — конец: цвета групп
tab4:		ld	e,(hl)
		inc	hl
		ld	d,(hl)
		inc	hl
		ld	a,d
		or	a
		ret	z
		ld	a,(hl)			; группа
		inc	hl
		ld	c,(hl)			; число
		inc	hl
		push	hl
		ex	de,hl
		ld	e,a
		call	room_color_write
		pop	hl
		jp	tab4

; L_8308: цвета групп 00-1B
L_8308:		ld	hl,C_830D
		jp	tab4

; L_8EB0: цвета групп 1-7 по ряду (C_93C0 + 7 * min(ряд, 8)); темнота — ряд >= 9 - уровень без факела (53),
; кроме сокровищницы (таблица C_8EF5)
L_8EB0:		call	L_8308
		ld	a,(0x71A7)
		cp	8
		jp	c,eb1
		ld	a,8
eb1:		ld	c,a			; 7 * ряд
		add	a,a
		add	a,a
		add	a,a
		sub	c
		ld	hl,C_93C0
		call	add_hl_a
		ld	e,1
		ld	c,7
		call	room_color_write
		ld	a,(0x71A6)
		ld	b,a
		ld	a,9
		sub	b
		ld	b,a
		ld	a,(0x71A7)
		cp	b
		ret	c
 IFDEF NES_FULL
		ld	a,0x8C			; NES: темноту снимает факел (предмет 0C -> 8C); 53 здесь — амулет с таймером
 ELSE
		ld	a,0x53
 ENDIF
		call	L_908F
		ret	c
		ld	a,(0x705F)
		and	0x20
		ret	nz
		ld	hl,C_8EF5
		jp	tab4

 IFDEF NES_FULL
 INCLUDE "nes_treasure.asm"
 ELSE
; L_A60B: сокровищница — экран выкл., поле пусто; 25 верёвок разной длины (случайные байты — у оригинала из
; ПЗУ картриджа по счётчику 7047, здесь — из кода 0000-2EFF), драгоценности (уровень / 2 + 8) по диагонали,
; стены по краям (кроме столбца 10), счёт; экран вкл.
L_A60B:		ld	a,(0x705F)
		and	0xF7
		ld	(0x705F),a
		call	video_off
		ld	de,0
		ld bc,NT_CELLS
		xor	a
		call	nt_fill
		ld	a,(0x70AC)
		cp	1
		jp	z,a60c
		ld	hl,(0x7047)
		ld	a,h
		and	0x2E
		ld	h,a
		ld	b,0x19
a60a:		push	bc
		ld	a,(hl)			; строк = (байт & 7) | 2
		and	7
		or	2
		ld	b,a
		inc	hl
		inc	hl
		ld	e,(hl)			; клетка 100h + байт
		ld	d,1
		inc	hl
		push	hl
		ld	c,1
		ld	hl,C_A9AD
		call	L_AA96
		pop	hl
		pop	bc
		dec	b
		jp	nz,a60a
		ld	a,(0x71A6)		; драгоценностей: уровень / 2 + 8
		or	a
		rra
		add	a,8
		ld	b,a
		ld	a,(0x7047)
		and	0x1F
		ld	e,a
		ld	d,1
a60b:		push	bc
		ex	de,hl
		ld	(0x71B0),hl
		ex	de,hl
		ld	a,0x44
		call	L_A378
		ld	hl,0x27
		add	hl,de
		ex	de,hl
		pop	bc
		dec	b
		jp	nz,a60b
a60c:		ld	a,(0x71A8)		; стены по краям (кроме столбца 10)
		cp	0x0A
		jp	z,a60d
		IFDEF NES_FULL
 ld de,HUD_ROWS*32
 ELSE
		ld	de,0
 ENDIF
		ld	hl,C_A9AE
		cp	0x0B
		jp	nz,a60e
		ld	hl,C_A9B0
		IFDEF NES_FULL
 ld de,HUD_ROWS*32+0x1D
 ELSE
		ld	de,0x1D
 ENDIF
a60e:		ld	bc,0x1803
		call	L_AA96
a60d:
 IFDEF NES_FULL
 call L_A548
 ELSE
		call	L_AEFE
 ENDIF
		jp	video_on

 ENDIF
