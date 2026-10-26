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
		ld	a,1
		ld	(snd_busy),a
		pop	af
		push	af
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
		xor	a
		ld	(snd_busy),a
		pop	af
		ret

; L_AC77: эффект окончен — тишина
L_AC77:		ld	a,(0x702C)
		and	0x3F
		ld	(0x702C),a
		jp	snd_off0

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
; snd_quiet: эффект прервать, каналы — без звука (меню)
snd_quiet:	ld	a,(0x702C)
		and	0x3F
		ld	(0x702C),a
snd_off:	ld	a,1			; из логики — под флагом (звук идёт в прерывании)
		ld	(snd_busy),a
		call	snd_off0
		xor	a
		ld	(snd_busy),a
		ret
snd_off0:	ld	a,0x9F
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

; --- вывод на ВИ53 (из прерывания; в сборке STRICT — из обработчика кадра) -----------------------------------------------------
; Тон k (0..2) SN76489 -> счётчик k ВИ53 (порты 0Bh, 0Ah, 09h; управляющее слово — 08h), меандр (режим 3).
; Делитель = период SN * 13,41 (SN: 3,58 МГц / 32 / период; ВИ53 тактируется 1,5 МГц). Громкости у ВИ53 нет:
; канал звучит при ослаблении < VI_ATT. Шум SN (у игры всегда с частотой тона 2) — на счётчике 2, если его тон
; молчит: периодический — меандр в 16 раз ниже тона 2; белый — щелчки (частый — каждый кадр, редкий — случайно). Пишется только изменившееся (новое значение без управляющего слова подхватывается с конца полупериода).
VI_ATT		equ	13
snd_vi53:	ld	c,0
sv0:		ld	a,c			; ослабление k
		ld	hl,sn_att
		call	add_hl_a
		ld	a,(hl)
		cp	VI_ATT
		ld	hl,0
		jp	nc,sv1
		ld	a,c			; период k -> DE
		add	a,a
		ld	hl,sn_per
		call	add_hl_a
		ld	e,(hl)
		inc	hl
		ld	d,(hl)
		call	vi_div
sv1:		ld	a,c
		cp	2			; счётчик 2 свободен — шум?
		jp	nz,sv2
		ld	a,h
		or	l
		jp	nz,sv2
		ld	a,(sn_att+3)
		cp	VI_ATT
		jp	nc,sv2
		ld	hl,(sn_per+4)		; высота шума — от периода тона 2 (режим 3 у всех эффектов игры)
		ex	de,hl
		call	vi_div
		ld	a,(sn_per+6)		; FB = 0 — периодический: в 16 раз ниже
		and	4
		jp	nz,sv5
		add	hl,hl
		jp	c,sv6
		add	hl,hl
		jp	c,sv6
		add	hl,hl
		jp	c,sv6
		add	hl,hl
		jp	nc,sv2
sv6:		ld	hl,0xFFFF
		jp	sv2
sv5:		ld	hl,(sn_per+4)		; белый: сдвиги шума с частотой тона 2 (3,58 МГц / 32 / N) — только щелчки
		ld	a,h			; (тон на шуме звучит писком): N < 70h (чаще ~1000 сдвигов/с) — щелчок
		or	a			; каждый кадр, реже — через кадр в среднем (случайно)
		jp	nz,sv_cl
		ld	a,l
		cp	0x70
		jp	c,sv_c1
sv_cl:		call	vi_rndn
		rrca
		jp	nc,sv_c2
sv_c1:		call	vi_click
sv_c2:		ld	hl,0
		jp	sv2
; vi_rndn: A := следующее случайное (x := 5x + 1)
vi_rndn:	ld	a,(vi_rnd)
		ld	b,a
		add	a,a
		add	a,a
		add	a,b
		inc	a
		ld	(vi_rnd),a
		ret
; vi_click: щелчок счётчиком 2 — режим 0: выход в 0, через 1 мс (600h отсчётов) — в 1; дальше тон — заново
; с управляющим словом (vi_dv[2] := 0)
vi_click:	ld	a,0xB0
		out	(0x08),a
		xor	a
		out	(0x09),a
		ld	a,6
		out	(0x09),a
		ld	hl,0
		ld	(vi_dv+4),hl
		ret
sv2:		ld	a,c
		call	vi_set
		inc	c
		ld	a,c
		cp	3
		jp	nz,sv0
		ret
; vi_div: DE = период SN -> HL = делитель ВИ53 = 13N + N/2 - N/16 - N/32 (~13,41N); 0 -> 0
vi_div:		ld	h,d
		ld	l,e
		add	hl,hl
		add	hl,de			; 3N
		add	hl,hl
		add	hl,hl			; 12N
		add	hl,de			; 13N
		call	de_srl			; N/2
		add	hl,de
		call	de_srl
		call	de_srl
		call	de_srl			; N/16
		ld	a,l
		sub	e
		ld	l,a
		ld	a,h
		sbc	a,d
		ld	h,a
		call	de_srl			; N/32
		ld	a,l
		sub	e
		ld	l,a
		ld	a,h
		sbc	a,d
		ld	h,a
		ret
de_srl:		ld	a,d
		or	a
		rra
		ld	d,a
		ld	a,e
		rra
		ld	e,a
		ret
; vi_set: A = счётчик, HL = делитель (0 — молчать) — в ВИ53, если изменился. BC сохраняется
vi_set:		push	bc
		ld	c,a
		add	a,a
		ld	de,vi_dv
		add	a,e
		ld	e,a			; (vi_dv в одной странице)
		ld	a,(de)
		cp	l
		jp	nz,vs1
		inc	de
		ld	a,(de)
		dec	de
		cp	h
		jp	z,vs_x
vs1:		ld	a,(de)			; был ли звук (B = 0 — молчал)
		ld	b,a
		inc	de
		ld	a,(de)
		or	b
		ld	b,a
		ld	(de),a			; (старший — ниже заново)
		ld	a,h
		ld	(de),a
		dec	de
		ld	a,l
		ld	(de),a
		ld	a,h
		or	l
		jp	z,vs_off
		ld	a,c
		or	a
		jp	z,vs_c0
		dec	a
		jp	z,vs_c1
		ld	a,b			; счётчик 2
		or	a
		ld	a,0xB6
		call	z,vs_w2
		ld	a,l
		out	(0x09),a
		ld	a,h
		out	(0x09),a
		jp	vs_x
vs_w2:		out	(0x08),a
		ret
vs_c1:		ld	a,b
		or	a
		ld	a,0x76
		call	z,vs_w2
		ld	a,l
		out	(0x0A),a
		ld	a,h
		out	(0x0A),a
		jp	vs_x
vs_c0:		ld	a,b
		or	a
		ld	a,0x36
		call	z,vs_w2
		ld	a,l
		out	(0x0B),a
		ld	a,h
		out	(0x0B),a
		jp	vs_x
vs_off:		ld	a,c			; молчать: режим 0 — выход в 0 до счёта
		rrca
		rrca
		or	0x30
		out	(0x08),a
vs_x:		pop	bc
		ret
; vi_off: все счётчики молчат (при старте)
vi_off:		ld	a,0x30
		out	(0x08),a
		ld	a,0x70
		out	(0x08),a
		ld	a,0xB0
		out	(0x08),a
		ld	hl,0
		ld	(vi_dv),hl
		ld	(vi_dv+2),hl
		ld	(vi_dv+4),hl
		ret
