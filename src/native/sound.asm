; Нативно: звуковые эффекты (по src/model/sound.js) — AC1A (запуск), AC6D (шаг раз в кадр), AC77 (конец),
; snd_off (1FD6). Байты SN76489 -> sn_out: состояние каналов sn_per/sn_att (вывод на ВИ53 — по нему).
; Переменные эффекта — 702C-7035 (как у оригинала; 702E — указатель, адрес Вектора).

; L_AC06: инвентарь 71B2-71B8 := FF (регистры сохраняются)
L_AC06:		push	hl
		push	bc
		ld	hl,0x71B2
		ld	b,7
ac0:		ld	(hl),0xFF
		inc	hl
		dec	b
		jp	nz,ac0
		pop	bc
		pop	hl
		ret

; L_AC1A: эффект A (меньший номер важнее; 1 и 9 не перезапускаются). Регистры и флаги сохраняются
L_AC1A:		push	af
		push	hl
		push	de
		push	bc
		ld	b,a
		ld	a,(0x702C)
		and	0x80
		jp	z,ac1n
		ld	a,(0x702D)		; идёт эффект cur: cur < b — оставить; cur = b = 1 или 9 — оставить
		cp	b
		jp	c,ac1x
		jp	nz,ac1n
		cp	9
		jp	z,ac1x
		cp	1
		jp	z,ac1x
ac1n:		ld	a,b
		ld	(0x702D),a
		ld	a,(0x702C)
		or	0xA0
		and	0xBF
		ld	(0x702C),a
		ld	a,b			; указатель эффекта: C_AD0B[2b]
		add	a,a
		ld	hl,C_AD0B
		call	add_hl_a
		ld	a,(hl)
		inc	hl
		ld	h,(hl)
		ld	l,a
		ld	a,(hl)
		ld	(0x7030),a
		dec	a
		ld	(0x7032),a
		inc	hl
		ld	a,(hl)
		ld	(0x7035),a
		and	3
		ld	(0x7031),a
		inc	hl
		ld	(0x702E),hl
		xor	a
		ld	(0x7033),a
ac1x:		pop	bc
		pop	de
		pop	hl
		pop	af
		ret

; L_AC77: эффект окончен — тишина
L_AC77:		ld	a,(0x702C)
		and	0x3F
		ld	(0x702C),a
		jp	snd_off

; L_AC6D: шаг эффекта раз в (7030) кадров: первый шаг — период/ослабление каналов 1, 0 и шум; затем (7031)
; нот (байт: период — биты 7-2, ослабление — биты 1-0; 0 — конец эффекта)
L_AC6D:		ld	a,(0x702C)
		ld	c,a
		and	0x80
		ret	z
		ld	a,c
		and	0x40
		jp	nz,L_AC77
		ld	hl,0x7032
		inc	(hl)
		ld	a,(0x7030)
		cp	(hl)
		ret	nz
		ld	(hl),0
		ld	a,c
		and	0x20
		jp	z,ac6n
		ld	a,c
		and	0xDF
		ld	(0x702C),a
		ld	hl,(0x702E)
		ld	a,(hl)
		and	0x0F
		or	0xD0
		call	sn_out
		ld	a,(hl)
		rrca
		rrca
		rrca
		rrca
		and	0x0F
		or	0xF0
		call	sn_out
		inc	hl
		ld	a,(hl)
		and	0x0F
		or	0x90
		call	sn_out
		ld	a,(hl)
		rrca
		rrca
		rrca
		rrca
		and	0x0F
		or	0xB0
		call	sn_out
		inc	hl
		ld	(0x702E),hl
		ld	a,(0x7035)
		or	0xE3
		call	sn_out
ac6n:		ld	a,(0x7031)		; ноты
		ld	b,a
		ld	a,(0x7033)
		cp	b
		jp	nz,ac6a
		xor	a
		ld	(0x7033),a
		ret
ac6a:		inc	a
		ld	(0x7033),a
		ld	c,a
		ld	hl,(0x702E)
		ld	a,(hl)
		or	a
		jp	z,L_AC77
		push	af
		and	0xFC
		rrca
		rrca
		ld	(0x7034),a
		pop	af
		and	3
		add	a,a
		add	a,a
		ld	b,a
		ld	a,c			; ((k ^ 7) << 5) | ослабление
		xor	7
		rrca
		rrca
		rrca
		or	b
		inc	hl
		ld	(0x702E),hl
		call	sn_out
		ld	a,(0x7034)
		call	sn_out
		jp	ac6n

; snd_off (1FD6): все каналы и шум — без звука
snd_off:	ld	a,0x9F
		call	sn_out
		ld	a,0xBF
		call	sn_out
		ld	a,0xDF
		call	sn_out
		ld	a,0xFF
		jp	sn_out

; sn_out: A = байт SN76489. Защёлка (бит 7): канал = биты 6-5, тип = бит 4 (1 — ослабление), данные — биты
; 3-0; байт данных — старшие 6 бит периода последнего защёлкнутого канала. sn_per[4] (слова), sn_att[4].
; Регистры сохраняются
sn_out:		push	af
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
		and	0x07
		ld	(sn_latch),a
		rrca
		jp	c,sno_att
		and	3
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
sno_d:		ld	a,(sn_latch)
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
sn_perp:	add	a,a
		ld	hl,sn_per
		jp	add_hl_a
