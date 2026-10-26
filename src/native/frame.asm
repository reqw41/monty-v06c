; Нативно: обработчик кадра A9B3, кадр анимации банков A92F, лазеры A8D6, A894 (по src/model/frame.js).
; Банки шаблонов у нативной сборки общие (различия — в dstore), поэтому кадр ленты E0/E8 пишется один раз,
; а не в каждый из 4 банков; итог в ОЗУ (7085, 73F9) и R4 — как у оригинала.

; L_A894: Z — A есть среди 8 байт C_943C (стены); HL, BC сохраняются
L_A894:		push	hl
		push	bc
		ld	hl,C_943C
		ld	b,8
a89a:		cp	(hl)
		jp	z,a89x
		inc	hl
		dec	b
		jp	nz,a89a
		inc	b			; не найден: NZ (A сохраняется)
a89x:		pop	bc
		pop	hl
		ret

; frame_anim (A92F): 7085 := 73F9; кадр ленты (7096): E0 <- C_85BC + 2f, E8 <- C_85CA + 8 (f & 1); R4 := банк
; по 73F9 (0 -> 0, 8 -> 1, 10 -> 2, 28 -> 5, иначе 5)
L_A92F:		ld	a,(0x73F9)
		ld	(0x7085),a
		ld	a,(0x7096)
		push	af
		add	a,a
		ld	hl,C_85BC
		call	add_hl_a
		ld	e,0xE0
		call	pat_put
		pop	af
		and	1
		add	a,a
		add	a,a
		add	a,a
		ld	hl,C_85CA
		call	add_hl_a
		ld	e,0xE8
		call	pat_put
		ld	a,(0x7085)
		ld	c,0
		or	a
		jp	z,a92r
		ld	c,1
		cp	8
		jp	z,a92r
		ld	c,2
		cp	0x10
		jp	z,a92r
		ld	c,5
a92r:		ld	b,4
		jp	vid_reg

; L_A8D6 LASERS: таймер 70A8 (60h..1); 60h — включить обе группы (1D, 1C), 48h / 30h — выключить
L_A8D6:
proc_A8D6:	ld	a,(0x70A8)
		dec	a
		jp	nz,a8d1
		ld	a,0x60
a8d1:		ld	(0x70A8),a
		cp	0x60
		jp	nz,a8d2
		ld	a,(0x7000)
		or	0x40
		ld	(0x7000),a
		ld	hl,C_ABCD
		jp	a8d3
a8d2:		cp	0x48
		jp	nz,a8d4
		ld	a,(0x7000)
		and	0xBF
		ld	(0x7000),a
		ld	hl,C_A92E
a8d3:		ld	e,0x1D
		ld	c,1
		call	col_put
a8d4:		ld	a,(0x70A8)
		cp	0x60
		jp	nz,a8d5
		ld	a,(0x7000)
		or	0x20
		ld	(0x7000),a
		ld	hl,C_ABCD
		jp	a8d6
a8d5:		cp	0x30
		ret	nz
		ld	a,(0x7000)
		and	0xDF
		ld	(0x7000),a
		ld	hl,C_A92E
a8d6:		ld	e,0x1C
		ld	c,1
		jp	col_put

; frame_handler (A9B3): раз в кадр — 919A (70B1 бит 3), A60B (705F бит 3), 8EB0 (70B1 бит 4), счётчики
; 7097, 7047, смена банка анимации (7011), 7207 -= 1, атрибуты спрайтов -> VSAT, шаг звука
frame_handler:
		ld	hl,0x70B1
		ld	a,(hl)
		and	0x80
		ret	nz
		ld	a,(hl)
		or	0x80
		ld	(hl),a
		and	8
		jp	z,fh1
		ld	a,(hl)
		and	0xF7
		ld	(hl),a
		call	L_919A
fh1:		ld	a,(0x705F)
		and	8
		call	nz,L_A60B
		ld	hl,0x70B1
		ld	a,(hl)
		and	0x10
		jp	z,fh2
		ld	a,(hl)
		and	0xEF
		ld	(hl),a
		call	L_8EB0
fh2:		ld	hl,0x7097
		inc	(hl)
		ld	hl,(0x7047)
		inc	hl
		ld	(0x7047),hl
		ld	a,(0x7011)		; 7011 + 1: бит 7 — пропуск; 1..4 — банк 0, 1, 2, 5
		inc	a
		ld	b,a
		and	0x80
		jp	nz,fh5
		ld	a,b
		ld	(0x7011),a
		ld	c,0
		cp	1
		jp	z,fh3
		ld	c,8
		cp	2
		jp	z,fh3
		ld	c,0x10
		cp	3
		jp	z,fh3
		cp	4
		jp	nz,fh5
		xor	a
		ld	(0x7011),a
		ld	c,0x28
fh3:		ld	a,c
		ld	(0x73F9),a
		call	L_A92F
		ld	a,(0x7011)
		xor	0x80
		ld	(0x7011),a
fh5:		ld	hl,0x7207
		dec	(hl)
		IFDEF	STRICT			; (атрибуты спрайтов -> VSAT — перед выводом, disp_prep)
		call	L_AC6D			; шаг звука: как у оригинала; иначе — в прерывании (isr), по времени
		call	snd_vi53
		ENDIF
		ld	hl,0x70B1
		ld	a,(hl)
		and	0x7F
		ld	(hl),a
		ret
