; Прослойка для Вектора вместо прослойки Muffie (MSX 2000-25AE): ввод, меню уровня, звук.

; --- клавиатура Вектора: kbmat[8], бит 1 — нажата (ряд 0: 4 влево, 5 вверх, 6 вправо, 7 вниз; ряд 7: 7 пробел;
; ряд 2: 1..3 — цифры 1..3) ------------------------------------------------------------------------------
kb_scan:
		ld	a,0x8A
		out	(0x00),a
		ld	hl,kbmat
		ld	b,0xFE
ks0:		ld	a,b
		out	(0x03),a
		in	a,(0x02)
		cpl
		ld	(hl),a
		inc	hl
		ld	a,b
		rlca
		ld	b,a
		jp	c,ks0
		ld	a,0x88
		out	(0x00),a
		ld	a,0xFF
		out	(0x03),a
		ret

; --- CONTROLLER_SCAN (OS7 1F76 -> MSX 2011): 73EE/73EF — 0 вверх, 1 вправо, 2 вниз, 3 влево, 6 огонь;
; 73F0/73F1 — код клавиатуры Coleco | 80h (цифры 1..3 — 02, 08, 03; нет — 80h) ---------------------------
os7_CONTROLLER_SCAN:
		push	af
		push	bc
		push	hl
		ld	a,(kbmat+0)
		ld	b,0
		rla				; бит 7 — вниз
		jp	nc,cs1
		ld	c,a
		ld	a,b
		or	0x04
		ld	b,a
		ld	a,c
cs1:		rla				; бит 6 — вправо
		jp	nc,cs2
		ld	c,a
		ld	a,b
		or	0x02
		ld	b,a
		ld	a,c
cs2:		rla				; бит 5 — вверх
		jp	nc,cs3
		ld	c,a
		ld	a,b
		or	0x01
		ld	b,a
		ld	a,c
cs3:		rla				; бит 4 — влево
		jp	nc,cs4
		ld	a,b
		or	0x08
		ld	b,a
cs4:		ld	a,(kbmat+7)		; пробел — огонь
		and	0x80
		jp	z,cs5
		ld	a,b
		or	0x40
		ld	b,a
cs5:		ld	a,b
		ld	(0x73EE),a
		ld	(0x73EF),a
		ld	a,0x80
		ld	(0x73F0),a
		ld	(0x73F1),a
		pop	hl
		pop	bc
		pop	af
		ret

; --- 2227: меню прослойки — ждать «1».. «3», уровень -> 8195 ----------------------------------------------
ad_2227:
		ei				; («тренер» Muffie, F202, не переносится: F202 на Векторе — банк шаблонов 2)
am1:		ld	a,(kbmat+2)
		ld	b,1
		rrca
		rrca				; бит 1 — «1»
		jp	c,am2
		inc	b
		rrca
		jp	c,am2
		inc	b
		rrca
		jp	c,am2
		jp	am1
am2:		ld	a,b
		jp	L_8195

; --- 2209: A := 0, если 705F бит 0 = 0 и уровень 1, иначе 76h; 705F бит 0 := 1 -------------------------
ad_2209:
		push	bc
		push	hl
		ld	b,0
		ld	a,(0x705F)
		and	1
		jp	z,a29a
		ld	b,0x76
a29a:		ld	a,(0x71A6)
		cp	1
		jp	z,a29b
		ld	b,0x76
a29b:		ld	hl,0x705F
		ld	a,(hl)
		or	1
		ld	(hl),a
		ld	a,b
		pop	hl
		pop	bc
		ret

; --- 21DE: звук — тишина, инициализация звука игры (8413), разрешить прерывания ---------------------------
ad_21DE:
		call	os7_TURN_OFF_SOUND
		call	L_8413
		ei
		ret

; --- вывод байта SN76489 (у Coleco OUT (FFh)); Muffie: 211E -> AY. Здесь — состояние каналов для ВИ53 ----
; 21C5: вывод A; A := (HL).  21CA: вывод A; HL+1.  21CF: A |= (HL), вывод.  21D4: вывод A, вывод (7034).
ad_21C5:	call	sn_out
		ld	a,(hl)
		ret
ad_21CA:	call	sn_out
		inc	hl
		ret
ad_21CF:	or	(hl)
		jp	sn_out
ad_21D4:	call	sn_out
		push	af
		ld	a,(0x7034)
		call	sn_out
		pop	af
		ret

; sn_out: A = байт SN76489. Защёлка (бит 7): канал = биты 6-5, тип = бит 4 (1 — ослабление), данные = биты 3-0;
; байт данных — старшие 6 бит периода последнего защёлкнутого канала. sn_per[4] (слова), sn_att[4].
sn_out:
		push	af
		push	bc
		push	hl
		ld	c,a
		and	0x80
		jp	z,sno_d
		ld	a,c
		rrca
		rrca
		rrca
		rrca
		and	0x07			; канал*2 + тип
		ld	(sn_latch),a
		rrca
		jp	c,sno_att
		and	3			; период: младшие 4 бита
		call	sn_perp
		ld	a,(hl)
		and	0xF0
		ld	b,a
		ld	a,c
		and	0x0F
		or	b
		ld	(hl),a
		jp	sno_x
sno_att:	and	3
		ld	hl,sn_att
		call	add_hl_a
		ld	a,c
		and	0x0F
		ld	(hl),a
		jp	sno_x
sno_d:		ld	a,(sn_latch)		; байт данных: старшие 6 бит периода
		rrca
		jp	c,sno_x
		and	3
		call	sn_perp
		ld	a,c
		and	0x3F
		rlca
		rlca
		rlca
		rlca
		ld	b,a
		ld	a,(hl)
		and	0x0F
		or	b
		ld	(hl),a
		inc	hl
		ld	a,c
		and	0x3F
		rrca
		rrca
		rrca
		rrca
		and	0x03
		ld	(hl),a
sno_x:		ld	a,1
		ld	(sn_chg),a
		pop	hl
		pop	bc
		pop	af
		ret
sn_perp:	add	a,a			; HL = sn_per + 2 * A
		ld	hl,sn_per
		jp	add_hl_a

; TURN_OFF_SOUND: все каналы — максимальное ослабление
os7_TURN_OFF_SOUND:
		push	af
		push	hl
		ld	hl,sn_att
		ld	a,0x0F
		ld	(hl),a
		inc	hl
		ld	(hl),a
		inc	hl
		ld	(hl),a
		inc	hl
		ld	(hl),a
		ld	a,1
		ld	(sn_chg),a
		pop	hl
		pop	af
		ret
