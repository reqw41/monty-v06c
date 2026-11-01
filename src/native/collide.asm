; Нативно: предметы, двери, огонь, столкновения, счёт, кадр героя (по src/model/collide.js).

; cpir: поиск A с HL, C байт (B = 0) — как CPIR Z80: Z — найден; HL — за найденным (или за концом), C — остаток.
; A сохраняется
cpir:		cp	(hl)
		jp	z,cpr_f
		inc	hl
		dec	c
		jp	nz,cpir
		push	bc			; не найден: NZ (A, B сохраняются)
		ld	b,a
		ld	a,1
		or	a
		ld	a,b
		pop	bc
		ret
cpr_f:		inc	hl			; найден: HL — за ним, C — остаток, Z
		dec	c
		cp	a
		ret

; L_840B: (HL) .. (HL + BC) := 0
L_840B:		ld	(hl),0
		ld	a,b
		or	c
		ret	z
		inc	hl
		dec	bc
		jp	L_840B

; очки за событие: 70BD := 50 / 100 / 3000 (BCD)
L_9067:		push	hl
		ld	hl,0x0050
		jp	sc70
L_906D:		push	hl
		ld	hl,0x0100
		jp	sc70
L_9073:		push	hl
		ld	hl,0x3000
sc70:		ld	(0x70BD),hl
		pop	hl
		ret

; L_908F: предмет A в инвентаре 71B2 (6 мест)? CF и Z — есть; HL, C — как после поиска (B = 0)
L_908F:		ld	hl,0x71B2
		ld	bc,6
		call	cpir
		scf
		ret	z
		ccf
		ret
; L_909C: убрать найденный (HL — за ним, C — остаток): сдвиг хвоста, перерисовать инвентарь
L_909C:		ld	a,c
		or	a
		jp	z,L_A548		; (у оригинала LDIR с BC = 0 — не бывает)
		ld	d,h
		ld	e,l
		dec	de
p9c1:		ld	a,(hl)
		ld	(de),a
		inc	hl
		inc	de
		dec	c
		jp	nz,p9c1
		jp	L_A548

; L_90A5: 71B0 -= смещение по C mod 4 (бит 0 — клетка влево, бит 1 — строка вверх), затем 90C8
L_90A5:		ld	a,c
		and	3
		ld	e,a
		ld	c,0
		and	1
		jp	z,p9a1
		inc	c
p9a1:		ld	a,e
		and	2
		jp	z,p9a2
		ld	a,c
		add	a,0x20
		ld	c,a
p9a2:		ld	hl,(0x71B0)
		ld	a,l
		sub	c
		ld	l,a
		ld	a,h
		sbc	a,0
		ld	h,a
		ld	(0x71B0),hl
; L_90C8: клетка (71B0) в списке объектов 72C0..72F1 (с конца, по парам; дословно) -> 92A2; нет — 90E3
L_90C8:		ld	de,0x72F2
		ld	hl,0x71B0
		ld	b,0x18
p9c_0:		dec	de
p9c_1:		dec	de
		ld	a,(de)
		cp	(hl)
		jp	nz,p9c_n
		inc	hl
		inc	de
		ld	a,(de)
		cp	(hl)
		IFDEF NES_FULL
		jp	nz,p9c_hi_miss	; NES-список может содержать чужой объект с тем же младшим байтом
		ELSE
		jp	nz,p9c_1		; исходный порядок MSX
		ENDIF
		ex	de,hl			; HL — старший байт места в списке
		jp	L_92A2
		IFDEF NES_FULL
p9c_hi_miss:	dec	de		; вернуться к младшему байту этой записи
		ld	hl,0x71B0	; следующую пару сравнивать с обоими байтами адреса
		jp	p9c_n
		ENDIF
p9c_n:		dec	b
		jp	nz,p9c_0
; L_90E3: CF — прыжок запрещён/огонь отработан: на верёвке/цепи (08 под ногами) вне состояния 4 после
; вступления; иначе удержание огня (73EE биты 7-6 = C0) после отпускания (7075 = 80h) — сброс, CF
L_90E3:		ld	a,(0x7057)
		cp	8
		jp	z,p9e1
		ld	a,(0x7059)
		cp	8
		jp	nz,p9e2
p9e1:		ld	a,(0x7079)
		cp	4
		jp	z,p9e2
		ld	a,(0x705F)
		and	4
		jp	z,p9e2
		scf
		ret
p9e2:		ld	a,(0x73EE)
		and	0xC0
		cp	0xC0
		jp	nz,p9e3
		ld	a,(0x7075)
		cp	0x80
		jp	nz,p9e4
		xor	a
		ld	(0x7075),a
		scf
		ret
p9e4:		ld	a,0xC0
p9e3:		ld	(0x7075),a
		or	a			; CF = 0
		ret

; L_911E / L_9122: тайл A (911E — под ногами, 705B) — опора? CF — нет опоры; A = D2 — смертельный (913B)
L_911E:
 IFDEF NES_FULL
 jp nes_floor_at
 ELSE
 ld a,(0x705B)
 ENDIF
L_9122:		call	tile_floor
		jp	z,p912n			; проходим по полу: CF = 0
		cp	0xE8
		jp	nz,p912a
		ld	a,(0x7000)		; лазер E8: включён — нет опоры
		and	0x40
		ld	a,(0x7000)
		jp	z,p912n
		scf
		ret
p912a:		call	L_913B
		jp	nz,p912c
		ld	a,0xD2
p912n:		or	a			; CF = 0
		ret
p912c:		scf
		ret
; L_913B: Z — A среди 5 байт C_A00E (BC, HL сохраняются)
L_913B:		cp	0x38
		ret	z
		cp	0x40
		ret	c
		push	hl
		ld	l,a
		ld	h,0
		ld	a,(hl)
		and	0x30
		xor	0x10			; keys (30h) are not deadly
		ld	a,l
		pop	hl
		ret

; Z = tile from cartridge floor list 93FF. A/BC/HL are preserved.
tile_floor:	cp	4
		ret	c			; frequent empty tile, NZ
		cp	7
		jp	c,tf_yes
		cp	8
		ret	z
		cp	0x10
		ret	z
		cp	0x11
		ret	z
		cp	0x40
		jp	nc,tf_high
		cp	0xFF			; low non-floor, NZ
		ret
tf_yes:		cp	a
		ret
tf_high:	push	hl
		ld	l,a
		ld	h,0
		ld	a,(hl)
		and	0x71			; exclude item/key/fire/death kinds
		cp	1
		ld	a,l
		pop	hl
		ret

; L_919A: перерисовка комнаты (сброс спрайтов врагов 7308..7328)
L_919A:		ld	a,(0x7000)
		or	1
		ld	(0x7000),a
		xor	a
		ld	(0x707A),a
		ld	hl,0x7308
		ld	bc,0x20
		call	L_840B
		jp	L_A067

; L_91B0: 7096 := 7096 - 1 (или 3)
L_91B0:		ld	a,(0x7096)
		dec	a
		jp	p,p91b
		ld	a,3
p91b:		ld	(0x7096),a
		ret
; L_91BD: шаг ходьбы: 70AD -= 1; 0 — 70AD := 2, 70AA := 70AA - 1 (или 7)
 IFDEF NES_FULL
L_91BD equ L_92DC
 ELSE
L_91BD:
		ld	hl,0x70AD
		dec	(hl)
		ret	nz
		ld	(hl),2
		ld	a,(0x70AA)
		dec	a
		jp	p,p91c
		ld	a,7
p91c:		ld	(0x70AA),a
		ret
 ENDIF
; L_91D1: CF := |A - (HL)| < B (модуль по знаку байта)
L_91D1:		sub	(hl)
		jp	p,p91d
		cpl
		inc	a
p91d:		cp	b
		ret
; L_91D9: цвет группы 14h := A
L_91D9:		ld	e,0x14
		ld	c,1
		jp	room_color_fill
; L_92A2: снять/поставить флаг взятия объекта по месту HL (старший байт) в списке 72C0 (на уровнях 4+ при
; 7000 бит 3 — нет)
L_92A2:		ld	a,(0x71A6)
		cp	4
		jp	c,p92a
		ld	a,(0x7000)
		and	8
		ret	nz
p92a:		dec	hl
		ld	a,l
		sub	0xC0
		or	a			; / 2 со знаком (место в 72C0..72FF — положительно)
		rra
L_92BE:		dec	a
		ld	(0x71A2),a
		call	L_A4B5
		add	a,a
		ld	(0x71A1),a
		call	L_A514
		ld	a,(hl)
		xor	d
		ld	(hl),a
		ret
; L_92D1: 7098 ^= 80h; 0 — 91B0
L_92D1:		ld	a,(0x7098)
		xor	0x80
		ld	(0x7098),a
		ret	nz
		jp	L_91B0

; L_AF70 ADD_SCORE: счёт 7017-7019 (BCD, старший первым) += HL; перенос в 7017 — жизнь (кроме уровней 5+
; при нечётном результате), вывод жизней, звук 0. Регистры сохраняются
L_AF70:		push	af
		push	hl
		push	de
		push	bc
		ld	a,(0x7019)
		add	a,l
		daa
		ld	(0x7019),a
		jp	nc,af71
		push	hl
		ld	a,1
		call	af7m
		pop	hl
af71:		ld	a,h
		call	af7m
		pop	bc
		pop	de
		pop	hl
		pop	af
		ret
af7m:		ld	b,a			; 7018 += A (BCD); перенос — сотни тысяч
		ld	a,(0x7018)
		add	a,b
		daa
		ld	(0x7018),a
		ret	nc
		and	1
		jp	z,af7l
		ld	a,(0x71A6)
		cp	5
		jp	nc,af7n
af7l:		ld	hl,0x7049
		inc	(hl)
af7n:		ld	a,(0x7017)
		add	a,1
		daa
		ld	(0x7017),a
		call	L_AABB
		xor	a
		jp	L_AC1A
; L_A587: очки HL и вывод счёта
L_A587:		call	L_AF70
		jp	L_AEFE

; L_A56C: предмет C в инвентарь (CF — полон); 44h (драгоценность) — не хранится, 1000 очков; иначе очки 70BD
L_A56C:		ld	hl,0x71B2
a56a:		ld	a,(hl)
		cp	0xFF
		jp	z,a56b
		inc	hl
		jp	a56a
a56b:		ld	a,l
		cp	0xB7
		scf
		ret	z
		ld	a,c
		cp	0x44
		jp	nz,a56c
		push	hl
		ld	hl,0x1000
		ld	(0x70BD),hl
		pop	hl
		jp	a56d
a56c:		ld	(hl),c
a56d:		push	hl
		call	L_A548
		ld	hl,(0x70BD)
		call	L_A587
		pop	hl
		or	a
		ret
; L_901B: взять предмет A (место — остаток C поиска): в инвентарь, звук 2, стереть 2x2 (набор 0B), 8EB0
L_901B:
		IFDEF NES_FULL
		push	af		; тип предмета нужен после L_A56C
		ENDIF
		push	bc
		ld	c,a
		call	L_A56C
		pop	bc
		IFDEF NES_FULL
		pop	de		; D = исходный A; флаги L_A56C сохранены
		ret	c
		ld	a,d
		ELSE
		ret	c
		ENDIF
		IFDEF NES_FULL
		cp	0x53		; NES предмет 09: временная защита от врагов
		jp	nz,p901_draw
		ld	a,(nes_amulet_ticks)
		ld	d,a
		ld	a,(nes_amulet_ticks+1)
		or	d
		jp	nz,p901_draw
		ld	hl,427		; 2 x 256 кадров при 60 Гц ~= 427 шагов при 50 Гц
		ld	(nes_amulet_ticks),hl
p901_draw:
		ENDIF
		push	bc
		ld	a,2			; в сокровищнице звук 2 глушится в nes_event_ready (поверх музыки бонуса)
		call	L_AC1A
		call	L_90A5
		ld	hl,(0x71B0)
		ex	de,hl
		ld	a,0x0B
		call	L_A378
		ld	hl,0x70B1
		ld	a,(hl)
		or	0x10
		ld	(hl),a
		pop	bc
		ret

; L_8F5F (процесс): двери, огонь/лазеры, предметы под героем
L_8F5F:
proc_8F5F:	ld	a,(0x7079)
		cp	9
		ret	z
		ld	a,(0x7011)
		xor	0x80
		ld	(0x7011),a
		call	L_9156
		ld	a,(0x7078)
		and	0x80
		ld	a,(0x7057)
		jp	nz,p8f1
		ld	a,(0x71B0)		; смотрит вправо: клетка + 2 (младший байт), тайл справа
		add	a,2
		ld	(0x71B0),a
		ld	a,(0x7059)
p8f1:		ld	d,0x70			; дверь: (тайл, цвет ключа -> 7084, ключ)
		ld	e,0x5D
		cp	0x9C
		jp	z,p8fd
		ld	d,0x69
		ld	e,0x58
		cp	0xB7
		jp	z,p8fd
		ld	d,0x77
		ld	e,0x62
		cp	0xC7
		jp	nz,p8f2
p8fd:		ld	a,d
		ld	(0x7084),a
		ld	a,e
		call	L_908F
		jp	nz,p8f2
		call	L_909C
		ld	hl,(0x71B0)
		ld	de,0xFFA0		; - 60h
		add	hl,de
		ld	(0x71B0),hl
		call	L_90C8
		ld	a,(0x7084)
		call	L_A3F1
		ld	a,8
		call	L_AC1A
		ld	hl,0x0300
		jp	L_A587
p8f2:		call	L_9156			; огонь/лазер под героем (9428)
		ld	hl,0x71B0
		inc	(hl)
		ld	a,(0x7058)
		IFDEF NES_FULL
		cp	0xA0		; только неподвижная змея; огонь остаётся смертелен
		jp	c,p8f_no_amulet
		cp	0xA8
		jp	nc,p8f_no_amulet
		ld	b,a
		ld	a,(nes_amulet_ticks)
		ld	d,a
		ld	a,(nes_amulet_ticks+1)
		or	d
		ld	a,b
		ret	nz
p8f_no_amulet:
 cp 0xD0
 jp nc,p8f3
		ENDIF
		cp	0x40
		jp	c,p8f3
		ld	l,a
		ld	h,0
		ld	b,(hl)
		ld	a,b
		and	0x40
		ld	a,l
		jp	z,p8f3
		ld	a,b
		and	7
		ld	c,a			; original CPIR remainder (corner of the fire)
		ld	a,(0x704A)
		or	a
		ret	nz
		ld	a,(0x7000)
		or	8
		ld	(0x7000),a
		call	L_90A5
		ld	a,(0x7000)
		and	0xF7
		ld	(0x7000),a
		ld	c,0
		ld	e,0
		jp	L_8DA2
p8f3:
		IFNDEF	STRICT
		call	it_pick			; допуск: в средней колонке предмета нет — соседняя (71B0 +- 1)
		ENDIF
		cp	0x40
		ret	c
		ld	l,a
		ld	h,0
		ld	a,(hl)
		and	0x20
		ld	a,l
		ret	z			; no item, A unchanged
		ld	a,(hl)
		and	0x0F
		ld	c,a			; original CPIR remainder
		ld	a,(hl)
		and	0x10
		jp	z,p8f4
		call	L_9067
		ld	a,l			; key tile (HL points into logic_class)
		and	0xF8
		cp	0x78
		jp	z,p8k1
		cp	0x68
		jp	z,p8k2
		ld	a,0x62
		jp	L_901B
p8k1:		ld	a,0x58
		jp	L_901B
p8k2:		ld	a,0x5D
		jp	L_901B
p8f4:		ld	a,c
		cp	4
		jp	nc,p8f5
		call	L_906D			; факел
		ld	a,0xA0
		ld	(0x704A),a
		ld	a,0x8C
		jp	L_901B
p8f5:		cp	8
		jp	nc,p8f6
		ld	a,0x44			; драгоценность
		call	L_9067
		ld	a,0x44
		jp	L_901B
p8f6:		cp	0x0C
		jp	nc,p8f7
		call	L_9073			; амулет?
		ld	a,0x53
		jp	L_901B
p8f7:		call	L_9067			; меч
		ld	a,0x91
		jp	L_901B

; L_91E5 (процесс): таймер факела 704A (мигание цвета группы 14), амулет 8C; столкновение героя с врагом:
; меч (91) — враг гибнет, очки 2000/3000; иначе гибель героя (8DA2), на уровнях 1-4 враг тоже снимается
L_91E5:
proc_91E5:
 IFNDEF NES_FULL
 ld a,(0x70AC)
 dec a
 jp nz,p9e5
 ld a,1
p9e5:
 ld (0x70AC),a
 ENDIF
		ld	a,(0x7079)
		cp	8
		ret	nc
		ld	a,(0x704A)
		or	a
		jp	z,p9e7
		dec	a
		ld	(0x704A),a
		jp	z,p9e6
		ld	a,0xE0			; мигает
		call	L_91D9
		jp	p9e8
p9e6:		ld	a,0xC0			; кончился
		call	L_91D9
		xor	a
		ld	(0x704A),a
p9e7:		ld	a,0x8C			; амулет — снять (если есть)
		call	L_908F
		call	z,L_909C
p9e8:		call	L_92D1
		ld	a,(0x704A)
		or	a
		ret	nz
		IFDEF NES_FULL
		ld	a,(nes_amulet_ticks)
		ld	b,a
		ld	a,(nes_amulet_ticks+1)
		or	b
		ret	nz
		ENDIF
		ld	a,(0x7300)
		ld	(0x7084),a
		ld	a,(0x7301)
		ld	(0x7085),a
		ld	hl,0x72C1
p9e9:		inc	hl
		ld	c,(hl)
		inc	hl
		ld	a,(hl)
		cp	0xFE
		ret	z
		cp	0xFF
		jp	nz,p9e9
		push	hl			; враг: спрайт 7304 + C
		ld	hl,0x7304
		ld	a,c
		call	add_hl_a
		ld	a,(0x7084)
		ld	b,0x0D
		call	L_91D1
		jp	nc,p9ex
		inc	hl
		ld	a,(0x7085)
		ld	b,8
		call	L_91D1
		jp	nc,p9ex
		inc	hl
		inc	hl
		ld	a,(hl)			; цвет 0 — враг уже снят
		or	a
		jp	z,p9ex
		push	hl
		ld	a,0x91
		call	L_908F
		jp	nz,p9ey
		call	L_909C			; меч: враг гибнет
		ld	a,3
		call	L_AC1A
		pop	hl
		ld	a,(hl)
		ld	(hl),0
		cp	0x0F
		ld	hl,0x2000
		jp	z,p9ez
		ld	hl,0x3000
p9ez:		call	L_A587
		pop	hl
		jp	L_92A2
p9ey:		pop	hl			; без меча — гибель героя
		pop	hl
		ld	a,(0x71A6)
		cp	5
		call	c,L_92A2
		ld	c,0
		ld	e,0
		jp	L_8DA2
p9ex:		pop	hl
		jp	p9e9
		IFDEF NES_FULL
nes_amulet_step:
		ld	hl,(nes_amulet_ticks)
		ld	a,h
		or	l
		ret	z
		dec	hl
		ld	(nes_amulet_ticks),hl
		ld	a,h
		or	l
		ret	nz
		ld	a,0x53		; время вышло: убрать амулет из инвентаря
		call	L_908F
		ret	nz
		jp	L_909C
		ENDIF

; --- кадр героя ---------------------------------------------------------------------------------------------
; L_9369: CF := герой смотрит вправо (7078 бит 7 = 0); A сохраняется
 IFDEF NES_FULL
L_9369 equ L_91BD
L_9305 equ L_91BD
 ELSE
L_9369:		push	af
		ld	a,(0x7078)
		and	0x80
		jp	nz,p936
		pop	af
		scf
		ret
p936:		pop	af
		or	a
		ret
; L_9305: кадр A из таблицы HL: 7302 := (HL + 2A), 7306 := (HL + 2A + 1)
L_9305:		add	a,a
		call	L_A540
		ld	(0x7302),a
		inc	hl
		ld	a,(hl)
		ld	(0x7306),a
		ret
 ENDIF
; L_92DC: кадр спрайта героя по состоянию 7079
 IFDEF NES_FULL
L_92DC equ nphys_noop
 ELSE
L_92DC:
		ld	a,(0x7079)
		or	a
		jp	z,p92w0			; standing uses walking frame zero
		cp	1
		jp	z,p92w
		cp	2
		jp	nz,p92b
		ld	hl,C_9388
		call	L_9369
		jp	c,p92a0
		ld	hl,C_938A
p92a0:		xor	a
		jp	L_9305
p92b:		cp	3
		jp	nz,p92c
		ld	a,(0x705F)
		and	0x40
		jp	z,p92b1
		ld	a,(0x705F)
		and	0xBF
		ld	(0x705F),a
		ret
p92b1:		ld	hl,C_938E
p92aa:		ld	a,(0x70AA)
		or	a
		rra
		jp	L_9305
p92c:		cp	4
		jp	nz,p92d
		ld	hl,C_9396
		jp	p92aa
p92d:		cp	5
		jp	nz,p92e
		ld	hl,C_938C
		xor	a
		jp	L_9305
p92e:		cp	9
		jp	nz,p92f
		ld	hl,C_939E
		ld	a,(0x7096)
		jp	L_9305
p92f:		cp	8
		ret	z
		cp	0x0A
		ret	z
		xor	a			; прочие — как ходьба с кадром 0
		jp	p92w0
p92w:		ld	a,(0x70AA)		; ходьба: кадр 70AA / 2; не 0 — звук шага
		or	a
		rra
p92w0:		or	a
		jp	z,p92w1
		push	af
		ld	a,9
		call	L_AC1A
		pop	af
p92w1:		ld	hl,C_9380
		call	L_9369
		jp	nc,L_9305
		ld	hl,C_9378
		jp	L_9305

 ENDIF

		IFNDEF	STRICT
; Допуск у предметов (отступление от оригинала; -DSTRICT — как у MSX): предмет 2 x 2 клетки берётся, когда
; клетка предмета — в средней колонке у героя (7058); здесь — и в соседних (7057, 7059): клетка 71B0 — она же,
; дальше — как у оригинала (угол предмета — по тайлу). A — тайл на входе и выходе
it_pick:	call	it_is
		ret	z
		ld	a,(0x7057)
		call	it_is
		jp	z,itp_l
		ld	a,(0x7059)		; предмет правее: только если Джо заходит на него хотя бы на 4 точки
		call	it_is
		jp	nz,itp_n
		ld	a,(0x7301)
		inc	a
		and	7
		cp	4
		jp	nc,itp_r
itp_n:		ld	a,(0x7058)
		ret
itp_l:		ld	hl,(0x71B0)
		dec	hl
		ld	(0x71B0),hl
		ld	a,(0x7057)
		ret
itp_r:		ld	hl,(0x71B0)
		inc	hl
		ld	(0x71B0),hl
		ld	a,(0x7059)
		ret
; it_is: Z — тайл A — клетка предмета (9430 — ключи, 9418 — прочие); A сохраняется
it_is:		cp	0x40
		ret	c			; all items are >= 40h; NZ
		push	hl
		ld	l,a
		ld	h,0
		ld	a,(hl)
		and	0x20
		xor	0x20
		ld	a,l
		pop	hl
		ret
		ENDIF
