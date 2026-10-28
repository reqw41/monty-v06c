; Обработчик кадра игры и прямые фазы анимации (по src/model/frame.js).
; Значения ОЗУ игры 7085/73F9 сохраняются как у MSX.

; L_A894: Z = wall, A/BC/HL preserved.
L_A894:		cp	8
		ret	z
		cp	0x0B
		ret	z
		cp	0x40
		ret	c			; low tile, NZ
		push	hl
		ld	l,a
		ld	h,0
		ld	a,(hl)
		and	0x80
		xor	0x80			; Z = wall
		ld	a,l
		pop	hl
		ret

; Кадры огня и лент — переменные игры. Графика всех кадров неизменяема.
L_A92F:		ld	a,(0x73F9)
		ld	(0x7085),a
		ld	c,0
		or	a
		jp	z,fa_set
		inc	c
		cp	8
		jp	z,fa_set
		inc	c
		cp	0x10
		jp	z,fa_set
		inc	c
fa_set:		ld	a,c
		ld	(fire_frame),a
		ld	a,(0x7096)
		ld	(belt_frame),a
		ld	a,(video_dirty)
		or	DIRTY_FIRE+DIRTY_BELT
		ld	(video_dirty),a
		ret

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
		call	room_color_write
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
		jp	room_color_write

; frame_handler (A9B3): раз в кадр — 919A (70B1 бит 3), A60B (705F бит 3), 8EB0 (70B1 бит 4), счётчики
; 7097, 7047, смена банка анимации (7011), 7207 -= 1, шаг звука
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
 IFDEF NES_FULL
 ld a,(room_colors+1)
 push af
 ENDIF
		call L_8EB0
 IFDEF NES_FULL
 pop af
 ld hl,room_colors+1
 cp (hl)
 jp z,fh2
 ld a,(video_dirty)
 or DIRTY_ROOM
 ld (video_dirty),a
 ENDIF
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
		IFDEF	STRICT			; звук синхронно с логикой — для сравнения с MSX
		call	L_AC6D			; шаг звука: как у оригинала; иначе — в прерывании (isr), по времени
		call	snd_vi53
		ENDIF
		ld	hl,0x70B1
		ld	a,(hl)
		and	0x7F
		ld	(hl),a
		ret
