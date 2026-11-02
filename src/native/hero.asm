; Нативно: герой — процесс 88D1 (по src/model/hero.js). Состояние 7079: 0/1 — стоит/идёт, 2 — прыжок, 3 — спуск
; с конвейера, 4 — на лестнице/верёвке, 5/6 — падение, 7 — с верёвки вниз, 8 — гибель, 9 — пауза перед
; возрождением, A — гибель от падения. Ветка состояния оставляет в B, C шаг (как у оригинала: от B зависит 8DE8).

; L_8C1F: ввод -> 73EE..73F1 (вверх 1, вправо 2, вниз 4, влево 8, огонь 40; 73F0 = 80h), 73EE |= 73F0 & C0
L_8C1F:		ld	b,0
		ld	a,(kbmat+0)
		and	0xF0
		jp	z,in4			; no directional keys, preserve C
		rla				; бит 7 — вниз
		jp	nc,in1
		ld	c,a
		ld	a,b
		or	4
		ld	b,a
		ld	a,c
in1:		rla				; бит 6 — вправо
		jp	nc,in2
		ld	c,a
		ld	a,b
		or	2
		ld	b,a
		ld	a,c
in2:		rla				; бит 5 — вверх
		jp	nc,in3
		ld	c,a
		ld	a,b
		or	1
		ld	b,a
		ld	a,c
in3:		rla				; бит 4 — влево
		jp	nc,in4
		ld	a,b
		or	8
		ld	b,a
in4:		ld	a,(kbmat+7)		; пробел — огонь
		and	0x80
		jp	z,in5
		ld	a,b
		or	0x40
		ld	b,a
in5:		ld	a,1			; следующий опрос клавиатуры — в ближайшем прерывании
		ld	(kb_req),a
		ld	a,b
		ld	(0x73EF),a
		or	0x80
		ld	(0x73EE),a
		ld	a,0x80
		ld	(0x73F0),a
		ld	(0x73F1),a
		ret

; L_8B20 / L_8B27: X героя (7301, 7305) := (X & F0) + (младшая тетрада < 8 ? E : C); C := новая тетрада
 IFDEF NES_FULL
L_8B20 equ nphys_ladder_snap
 ELSE
L_8B20:
		ld	c,0x0F
		ld	e,7
		jp	snap
 ENDIF
 IFDEF NES_FULL
L_8B27:
 ld a,(0x7305)
 and 248
 or 4
 ld (0x7301),a
 ld (0x7305),a
 scf
 ret
 ELSE
L_8B27:		ld	c,0x0C
		ld	e,4
snap:		ld	a,(0x7301)
		and	0x0F
		cp	8
		jp	nc,snp1
		ld	c,e
snp1:		ld	a,(0x7301)
		and	0xF0
		add	a,c
		ld	(0x7301),a
		ld	(0x7305),a
		scf
		ret
 ENDIF
; L_8C44: A != 0 — шаг ходьбы (91BD), 705F бит 6 := 0; иначе := 1 (BC сохраняется)
 IFDEF NES_FULL
L_8C3F equ L_91BD
L_8C44 equ L_91BD
 ELSE
L_8C3F:		ld	a,(0x73EE)
		and	5
L_8C44:		or	a
		jp	z,p8c4
		call	L_91BD
		ld	a,(0x705F)
		and	0xBF
		ld	(0x705F),a
		ret
p8c4:		ld	a,(0x705F)
		or	0x40
		ld	(0x705F),a
		ret
 ENDIF
; L_8F37: конвейер под ногами (705B в C_9412): B += 1 (первые 3) или -1; не в гибели (7079 < 8)
L_8F37:		ld	a,(0x7079)
 IFDEF NES_FULL
		cp	2			; NES $A0AA: конвейер сносит только стоящего/идущего (состояние 0/1), не Джо в воздухе
 ELSE
		cp	8
 ENDIF
		ret	nc
 IFDEF NES_FULL
 call L_911E
 ELSE
		ld	a,(0x705B)
 ENDIF
		cp	4
		ret	c
		cp	7
		jp	c,belt_left
		cp	0x9B
		jp	z,belt_right
		cp	0xB8
		ret	c
		cp	0xBB
		ret	nc
belt_right:	inc	b
		ld	a,b
		ret
belt_left:	dec	b
		ld	a,b
		ret
; L_8DD4: герой (оба слоя) += (C по Y, B по X); A := X второго слоя
L_8DD4:		ld	hl,0x7300
		ld	a,(hl)
		add	a,c
		ld	(hl),a
		inc	hl
		ld	a,(hl)
		add	a,b
		ld	(hl),a
		ld	l,4
		ld	a,(hl)
		add	a,c
		ld	(hl),a
		inc	hl
		ld	a,(hl)
		add	a,b
		ld	(hl),a
		ret
; L_8DA2: гибель героя (если ещё не): звук 5, состояние 8, таймер 70A9 = 70h, кадр D4, жизнь; сдвиг (C, E)
L_8DA2:		call jn_capture_death
		ld	a,(0x7079)
		cp	8
		jp	z,p8da
		ld	a,5
		call	L_AC1A
		ld	a,8
		ld	(0x7079),a
		ld	a,0x70
		ld	(0x70A9),a
 IFNDEF NES_FULL
		ld	a,0xD4
		ld	(0x7306),a
 ENDIF
		ld	hl,0x7049
		IFDEF NES_FULL
		call cheat_lose_life
		ELSE
		dec	(hl)
		ENDIF
p8da:		ld	b,e
		jp	L_8DD4
L_8D80:
 IFDEF NES_FULL
 INCLUDE "nes_walls.asm"
 ELSE
		ld	a,b
		and	0x80
		ld	a,(0x7057)
		jp	nz,p8d1
		ld	a,(0x71B0)
		add	a,2
		ld	(0x71B0),a
		ld	a,(0x7059)
p8d1:
 IFDEF NES_FULL
 call nes_wall_at
 ELSE
 call L_A894
 ENDIF
		jp	nz,p8d2
		ld	a,c			; стена: вверх не шли — dX := 0; по X стоим
		and	0x80
		jp	nz,p8d1a
		xor	a
		ld	(0x7076),a
p8d1a:		ld	e,0
		ld	b,e
		jp	L_8DD4
p8d2:		ld	a,(0x7058)
		cp	0xE0
		jp	nz,p8d3
		ld	a,(0x7000)
		and	0x20
		jp	z,L_8DA2
p8d3:		ld	b,e
		jp	L_8DD4
 ENDIF
; Snapshot respawn state, both attributes and fall origin.
L_8E7E:
 IFDEF NES_FULL
 xor a
 ld (0x7072),a              ; счётчик прыжка/края — заново (после гибели в прыжке оставался 0Fh/80h)
 ld hl,(0x7076)
 ld a,l
 ld l,h
 ld h,a
 ld (0x707D),hl
 ld hl,(0x7078)
 ld a,l
 ld l,h
 ld h,a
 ld (0x707F),hl
 ELSE
		ld	a,(0x7077)
		ld	(0x707D),a
		ld	a,(0x7076)
		ld	(0x707E),a
		ld	a,(0x7079)
		ld	(0x707F),a
		ld	a,(0x7078)
		ld	(0x7080),a
 ENDIF
		ld	a,(0x7075)
		ld	(0x7081),a
		ld	a,(0x7300)
		ld	(0x707C),a
		ld	hl,0x7300
		ld	de,0x704B
		ld	b,8
p8e7:		ld	a,(hl)
		ld	(de),a
		inc	hl
		inc	de
		dec	b
		jp	nz,p8e7
L_8EA8:		ld	hl,0x70B1
		ld	a,(hl)
		or	0x10
		ld	(hl),a
		ret
; L_8C13: ждать кадр с перерисовкой комнаты (70B1 бит 3 — 919A в обработчике кадра)
L_8C13:		ld	hl,0x70B1
		ld	a,(hl)
		or	8
		ld	(hl),a
p8c1:		ld	a,(0x70B1)
		and	8
		ret	z
		call	frame_wait
		jp	p8c1
; L_8E0C: смена комнаты (BC — сдвиг героя): ниже 9-го ряда — сокровищница или следующий уровень (после
; сокровищницы, состояние 5); иначе — кадр с перерисовкой и точка возрождения
L_8E0C:
 IFDEF NES_FULL
 ld a,(0x705F)
 and 0x20
 jp nz,nf_bonus_edge
 ld a,(0x71A7)
 cp 9
 jp z,nf_bonus_edge
 call nf_valid_room
 jp nc,nf_room_edge
nf_bonus_edge:
 ENDIF
		ld	a,(0x71A7)
		cp	9
		jp	c,p8e1
		ld	a,1
		call	L_AC1A
 IFDEF NES_FULL
 ld a,(0x70AC)           ; NES bonus ends at the next exit after its timer
 cp 1
 ELSE
		ld	a,(0x7079)
		cp	5
 ENDIF
		jp	nz,p8e2
 IFDEF NES_FULL
 ld a,(0x705F)
 and 0xD7
 ld (0x705F),a
 ELSE
		xor	a			; следующий уровень
		ld	(0x71A7),a
		IFDEF NES_FULL
 ld a,10
 ELSE
		ld	a,8
 ENDIF
		ld	(0x71A8),a
		ld	a,(0x705F)
		and	0xD7
		or	4
		ld	(0x705F),a
 ENDIF
nes_next_level:
		ld	a,(0x71A6)
nes_level_number:
		cp	9
		jp	nc,p8e3
		inc	a
		ld	(0x71A6),a
p8e3:
		IFNDEF STRICT
		call nes_pyramid
		ENDIF
 IFNDEF NES_FULL
		push	bc
 ENDIF
		ld	hl,0x70C0
		ld	bc,0xC6
		call	L_840B
 IFDEF NES_FULL
 call a59d_keep_lives       ; reset the rope introduction, preserving lives
 jp L_8E7E
 ELSE
		pop	bc
 ENDIF
p8e1:
 IFDEF NES_FULL
 call nt_bonus_wrap
 ELSE
 call L_8DD4
 ENDIF
		call	L_8C13
		jp	L_8E7E
p8e2:
		IFNDEF STRICT
		ld a,(0x705F)
		and 0x20
		call z,nes_treasure
		ENDIF
		ld	a,(0x705F)		; сокровищница
		ld	e,a
		or	0x28
		ld	(0x705F),a
		ld	a,e
		and	0x20
		jp	nz,p8e4
		IFDEF NES_FULL
 ld a,178                ; original NES ~14.1 seconds, 705..708 Vector frames
 ELSE
		ld	a,0xF0
 ENDIF
		ld	(0x70AC),a
		call	L_AC06
p8e4:
 IFDEF NES_FULL
 call nt_bonus_wrap
 ELSE
 call L_8DD4
 ENDIF
		jp	L_8E7E
; L_8DE8: после ветки состояния — шаг (7076, 7077) и выход за край комнаты
L_8DE8:
 IFDEF NES_FULL
 ld a,(0x7079)
 cp 8
 ret nc                    ; NES death handlers never run room-boundary checks
 ENDIF
 ld a,(0x7076)
		ld	e,a
		ld	a,(0x7077)
		ld	c,a
		call	L_8D80
 IFDEF NES_FULL
 cp 2
 ELSE
		cp	4
 ENDIF
		jp	c,p8de
 IFDEF NES_FULL
 cp 239
 ELSE
		cp	0xF0
 ENDIF
		jp	nc,p8de
		ld	bc,0			; 8F23: вверх/вниз
		ld	a,(0x7304)
 IFDEF NES_FULL
 cp 44
 ELSE
 cp 8
 ENDIF
		jp nc,p8dd
 IFDEF NES_FULL
 ld a,(0x7079)
 cp 2
 ret z                     ; NES $9CB0: a jump cannot enter the upper room
 cp 6
 ret z                     ; nor can the falling phase of that jump
 call nphys_top_wrap
 ELSE
 ld c,0xA4
 ENDIF
		ld	a,(0x705F)
		and	0x20
		jp	nz,L_8E0C
		ld	hl,0x71A7
		dec	(hl)
		jp	L_8E0C
p8dd:
 IFDEF NES_FULL
 cp 221
 ELSE
 cp 0xAC
 ENDIF
		ret	c
 IFDEF NES_FULL
 ; Enter the playable field below the six-row HUD. 64 wraps the anchor to
 ; y=31, leaving the entire 23-row Joe sprite hidden above scanline 48.
 ld c,80
 ELSE
 ld c,0x5C
 ENDIF
		ld	a,(0x705F)
		and	4
		ld	hl,0x71A7
		jp	z,p8dc
		ld	hl,0x71A8
		inc	(hl)
p8dc:		inc	(hl)
		jp	L_8E0C
p8de:
 IFDEF NES_FULL
 ld hl,0x71A8
 inc (hl)
 ld a,(0x7305)
 cp 2
 jp c,np_edge_left
 ld a,2
 jp np_edge_x
np_edge_left:
 dec (hl)
 dec (hl)
 ld a,238
np_edge_x:
 ld hl,0x7305
 sub (hl)
 ld b,a
 ld c,0
 jp L_8E0C
 ELSE
		ld	hl,0x71A8		; 8DFA: влево / вправо
		inc	(hl)
		ld	a,b
		and	0x80
		ld	bc,0x1600
		jp	z,L_8E0C
		dec	(hl)
		dec	(hl)
		ld	bc,0xEC00
		jp	L_8E0C

 ENDIF

; --- ветка состояния (hs_xxxx — метки оригинала) ------------------------------------------------------------
hero_state:
 ld a,(0x7079)
		or	a
		jp	z,hs_8929		; standing: skip indirect dispatch
		cp	11
		ret	nc
		add	a,a
		ld	hl,hs_tab
		call	add_hl_a
		ld	a,(hl)
		inc	hl
		ld	h,(hl)
		ld	l,a
		jp	(hl)
hs_tab:		dw	hs_8929, hs_8929, hs_8A2F, hs_8C59, hs_8D02, hs_8A83, hs_8A83, hs_8CC5, hs_8B7F, hs_8B8E, hs_8B6E

hs_8929:
 IFDEF NES_FULL
 call nphys_idle_align
 ELSE
 ld a,(0x705B)
		cp	8
		jp	nz,h929b
		ld	a,(0x7058)
		cp	8
		jp	nz,h929b
		ld	bc,0xF800		; на верёвке/цепи (08 под ногами и на уровне)
		ld	a,(0x7057)
		or	a
		jp	z,L_8DD4
		ld	b,8
		jp	L_8DD4
 ENDIF
h929b:
 IFDEF NES_FULL
h929_floor:
 ; A completed jump must not block the next walking catch at a rope cap.
 ; h8b44 reads this counter even after standing has changed into state 6.
  ENDIF
 IFNDEF NES_FULL
		ld	a,(0x7057)
		call	L_913B
		jp	z,hs_8A91
 ENDIF
 IFNDEF NES_FULL
		ld	a,(0x73EE)
		and	0x0F
		call	L_8C44
 ENDIF
		xor	a
		ld	(0x7077),a
		ld	bc,0
		ld	a,(0x73EE)		; вверх у цепи (88 89) — 8B20, C := FC
		and	1
		jp	z,h929c
		IFDEF	STRICT
		ld	a,(0x7058)
		cp	0x88
		jp	nz,h929c
		ld	a,(0x7059)
		cp	0x89
		jp	nz,h929c
		ELSE
		call	ld_up			; с допуском 4 точки по X (у оригинала — окно 8 точек)
		jp	nz,h929c
		ENDIF
		call	L_8B20
 IFDEF NES_FULL
 ld c,255
 ELSE
		ld	c,0xFC
 ENDIF
		jp	hs_8986
h929c:		ld	a,(0x73EE)		; вниз: на конвейере (10 11) — 897C; на лестнице (C4) — 4
		and	4
		jp	z,h929e
 IFDEF NES_FULL
 call ld_lad
 jp z,hs_897C
 call nphys_rope_probe
 cp 0x90
 jp nz,h929e
 call nt_rope_snap
 ld bc,1
 ld a,4
 jp hs_8992
 ELSE
		ld	a,(0x705B)
		cp	0x10
		jp	nz,h929l
		ld	a,(0x705C)
		cp	0x11
		jp	z,hs_897C
h929l:
		IFNDEF	STRICT
		push	af			; (A — тайл для проверки шеста ниже, как у оригинала)
		call	ld_lad			; верх лестницы (10 11) рядом — с допуском
		jp	z,h929k
		pop	af
		ENDIF
h929d:
 IFDEF NES_FULL
 jp h929e
 ELSE
		IFDEF	STRICT
		cp	0xC4
		jp	nz,h929e
		ELSE
		call	ld_down
		jp	nz,h929e
		ENDIF
		call	L_8B27
		ld	a,(0x705F)
		or	0x40
		ld	(0x705F),a
		ld	a,4
		jp	hs_8988
 ENDIF
 ENDIF
h929e:		ld	a,(0x73EE)		; влево / вправо / на месте
		and	8
		jp	z,h929f
		ld	bc,0xFE00
 IFDEF NES_FULL
 jp nj_key
 ELSE
		call	L_90E3
		jp	c,hs_89DC
		jp	hs_89F6
 ENDIF
h929f:		ld	a,(0x73EE)
		and	2
		jp	z,h929g
		ld	bc,0x0200
 IFDEF NES_FULL
nj_key:
		call	L_90E3
		jp	c,nj_jump
		jp	hs_89F6
 ELSE
		call	L_90E3
		jp	c,hs_89DC
		jp	hs_89F6
 ENDIF
h929g:		ld	bc,0
		call	L_90E3
 IFDEF NES_FULL
 jp c,nj_jump
 call nphys_ground_floor
 jp c,nphys_walk_fall
 ELSE
		jp	c,hs_89DC
		call	L_911E
		jp	c,hs_8A01
 ENDIF
		xor	a
 IFNDEF NES_FULL
		ld	bc,0
 ENDIF
		jp	hs_8992
 IFDEF NES_FULL
 ENDIF
hs_897C:	call	L_8B20
 IFDEF NES_FULL
 ld c,1
 ELSE
		ld	c,2
		ld	a,8
		ld	(0x70B2),a
 ENDIF
hs_8986:	ld	a,3
hs_8988:	push	af
		ld	a,b
		or	a
		jp	z,h988
		ld	(0x7078),a
h988:		pop	af
hs_8992:	ld	(0x7079),a
		cp	2
		jp	z,h992
 IFDEF NES_FULL
 call L_8F37
 ELSE
		ld	a,(0x70AB)
		and	1
		call	z,L_8F37
 ENDIF
h992:		ld	a,b
		ld	(0x7076),a
		ld	a,c
		ld	(0x7077),a
		ret
 IFDEF NES_FULL
; NES проверяет опору раньше прыжка: на шаге, где начинается падение с края (третье обновление), прыжок не выполняется.
nj_jump:
 call nphys_ground_floor
 jp c,nphys_walk_fall
 ENDIF
hs_89DC:	ld	a,7			; прыжок
		call	L_AC1A
		ld	a,(0x7300)
		ld	(0x707C),a
 IFDEF NES_FULL
 jp nt_jump_start
 ELSE
		ld	a,0x12
		ld	(0x7072),a
		ld	c,0xFF
		ld	a,2
		jp	hs_8988
 ENDIF
hs_89F6:
 IFDEF NES_FULL
 call nphys_ground_floor
 jp c,nphys_walk_fall
 ELSE
 call L_911E
 jp c,hs_8A01
 ENDIF
		ld	a,1
		jp	hs_8988
hs_8A01:	ld	a,(0x7300)		; падение
		ld	(0x707C),a
		ld	a,6
		jp	hs_8988
hs_8A2F:	ld	d,4			; прыжок: dY по таблице C_93AE
		ld	a,(0x7072)
		or	a
		jp	z,h2f1
		dec	a
		ld	(0x7072),a
 IFDEF NES_FULL
 push af
 ; The whole field is NES geometry: a 15-pixel MSX rise cannot reach
 ; the 16-pixel ledges above free rope caps. Use the original 19-pixel arc.
 ld hl,nt_jump_curve
 call nt_jump_finish
h2f_table:
 pop af
 ELSE
 ld hl,C_93AE
 ENDIF
		call	add_hl_a
		ld	d,(hl)
h2f1:		ld	a,(0x7076)
		or	a
		jp	z,h2f2
		ld	(0x7078),a
h2f2:		ld	b,a
		ld	c,d
 IFDEF NES_FULL
 call nphys_rope_probe
 ELSE
		ld	a,(0x7058)
 ENDIF
		cp	0x90
		jp	z,hs_8B0E
 IFDEF NES_FULL
 ld a,(0x7058)
 ENDIF
		cp	0x95
		jp	nz,h2f3
		ld	a,(0x705B)
		cp	8
		jp	nz,hs_8B5B
h2f3:
 IFNDEF NES_FULL
 ld a,(0x7076)
		and	0x80
		ld	a,(0x7057)
		jp	z,h2f4
		ld	a,(0x7059)
h2f4:		cp	8
		jp	nz,h2f5
		xor	a
		ld	(0x7076),a
h2f5:		ld	a,(0x7077)
 ELSE
h2f5:
 jp hs_8C39                 ; NES never lands during the ascent/zero-height apex
 ENDIF
 IFNDEF NES_FULL
		and	0x80
		jp	nz,hs_8C39
		jp	hs_8A86
 ENDIF
hs_8A83:
 IFDEF NES_FULL
 ld a,(0x7079)
 cp 5
 jp z,nphys_slide
 call nt_fall_speed
 ELSE
 ld bc,4
 ENDIF
hs_8A86:	call	L_911E
		jp	c,hs_8B06
		cp	0xD2
		jp	z,hs_8A91
		ld	c,0			; приземление: Y к 4 или 0C по модулю 16
		ld	a,(0x7300)
h86a:
 IFDEF NES_FULL
 and 7
 cp 3
 jp z,h86b
 ELSE
		and	0x0F
		cp	4
		jp	z,h86b
		cp	0x0C
		jp	z,h86b
 ENDIF
		dec	a
		dec	c
		jp	h86a
h86b:		push	bc
		ld	a,4
		call	L_AC1A
		ld	a,(0x71A8)
		cp	0x0A
		jp	nz,h86c
		ld	a,(0x705F)
		and	4
		jp	z,h86c
		ld	a,(0x705F)
		and	0xFB
		ld	(0x705F),a
 IFDEF NES_STABLE_COLORS
 call nes_landing_save
 ELSE
		call	L_8E7E
 ENDIF
h86c:		pop	bc
		ld	a,(0x707C)		; высота падения
		ld	e,a
		ld	a,(0x7300)
		cp	e
		jp	c,h86d
		sub	e
		cp	0x1C
		jp	c,h86d
		ld	a,(0x7079)
		cp	5
		jp	z,h86d
		ld	a,(0x7300)		; разбился: слои местами по Y
		ld	e,a
		ld	a,(0x7304)
		ld	(0x7300),a
		ld	a,e
		ld	(0x7304),a
		IFDEF NES_FULL
		xor	a
		ld	(jn_fire),a	; обычное падение: кувырок, без огненного эффекта
		ENDIF
		ld	a,9
		jp	hs_8AF0
h86d:
 IFDEF NES_FULL
 xor a
 ld (0x7072),a
 ld b,0
 call L_8DD4
 call L_9156
 jp hs_8929
 ELSE
 ld a,1
 jp hs_8992
 ENDIF
hs_8A91:
		IFDEF NES_FULL
		call	jn_capture_death	; смертельный огонь/лазер минует L_8DA2
		ENDIF
		ld	a,5
		call	L_AC1A
		ld	a,0x0A
hs_8AF0:	push	af
		ld	hl,0x7049
		IFDEF NES_FULL
		call cheat_lose_life
		ELSE
		dec	(hl)
		ENDIF
		ld	a,0x70
		ld	(0x70A9),a
		pop	af
		ld	bc,0
		jp	hs_8988
hs_8B06:
 IFDEF NES_FULL
 call nphys_rope_probe
 ELSE
 ld a,(0x705B)
 ENDIF
		cp	0x90
		jp	nz,hs_8B57
hs_8B0E:
 IFDEF NES_FULL
 call nes_chain_catch
 ELSE
		call	h8b44
 ENDIF
		jp	nc,hs_8C39
		IFDEF NES_FULL
		call nt_rope_snap
		ELSE
		call	L_8B27
		ENDIF
		ld	a,4
		ld	bc,0
		jp	hs_8992
hs_8B57:	cp	0x95
		jp	nz,hs_8C39
hs_8B5B:	call	h8b44
		jp	nc,hs_8C39
		call	L_8B27
 IFDEF NES_FULL
 ld bc,0
 ELSE
		ld	bc,4
 ENDIF
		ld	a,6
		call	L_AC1A
		ld	a,5
		jp	hs_8992
; h8b44: на верёвку можно (dX != 0 и 7072 < 0F)? CF — да
 IFDEF NES_FULL
h8b44 equ nt_jump_can_catch
 ELSE
h8b44:
		ld	a,(0x7076)
		or	a
		ret	z			; CF = 0
		ld	a,(0x7072)
 IFDEF NES_FULL
 and 0x7F                  ; high bit marks post-ascent momentum, not cooldown
 ENDIF
		cp	0x0F
		ret
 ENDIF
hs_8B6E:	ld	hl,0x7300		; гибель от падения
		dec	(hl)
 IFNDEF NES_FULL
		ld	a,0x78
		ld	(0x7302),a
 ENDIF
 IFNDEF NES_FULL
		ld	a,0x0E
		ld	(0x7303),a
		xor	a
		ld	(0x7307),a
 ENDIF
		jp	hs_8B8E
hs_8B7F:
 IFDEF NES_FULL
 jp hs_8B8E                 ; native death poses are selected by joe_select
 ELSE
	ld	a,(0x70A9)		; гибель: кадры
		and	4
		jp	nz,hs_8B8E
		ld	a,(0x70A9)
		and	3
		ld	hl,C_93A6
		call	L_9305
 ENDIF
hs_8B8E:	ld	a,(0x70A9)
		dec	a
		ld	(0x70A9),a
		jp	m,h8b9
		ld	bc,0
		jp	hs_8C39
h8b9:		ld	a,(0x7049)
		or	a
		jp	z,game_over
		ld	a,6			; возрождение
		ld	(0x7303),a
		ld	a,0x0B
		ld	(0x7307),a
		ld	a,(0x707D)
		ld	(0x7077),a
		ld	a,(0x707E)
		ld	(0x7076),a
		ld	a,(0x707F)
		ld	(0x7079),a
		ld	a,(0x7080)
		ld	(0x7078),a
		ld	a,(0x7081)
		ld	(0x7075),a
		ld	hl,0x704B
		ld	de,0x7300
		ld	b,8
h8ba:		ld	a,(hl)
		ld	(de),a
		inc	hl
		inc	de
		dec	b
		jp	nz,h8ba
		call	L_9156
		jp	L_8C13
hs_8C36:	ld	bc,0
hs_8C39:	ld	a,(0x7079)
		jp	hs_8992
 IFDEF NES_FULL
 INCLUDE "nes_climb.asm"
 INCLUDE "nes_hazards.asm"
 INCLUDE "nes_physics_box.asm"
 INCLUDE "nes_idle_align.asm"
 ELSE
hs_8C59:	ld	a,(0x70B2)		; 3: спуск с конвейера
		ld	b,a
		and	0x0F
		jp	z,h8c5
		dec	b
		ld	a,b
		ld	(0x70B2),a
		and	2
		jp	nz,hs_8C36
		ld	a,b
		and	0x80
		ld	bc,0x0002
		jp	z,hs_8C39
		ld	bc,0x00FE
		jp	hs_8C39
h8c5:		ld	a,b
		and	0x80
		ld	bc,0
		jp	nz,hs_8A01
		call	L_8C3F
hs_8C87:	ld	a,(0x705B)
		call	L_9122
		jp	nc,hs_8A01
		ld	a,(0x73EE)
		and	4
		jp	z,hs_8CD1
		ld	bc,1
		jp	hs_8C39
hs_8C9C:
		IFDEF NES_FULL
		call nes_chain_exit
		ENDIF
		ld	a,(0x705F)
		and	0x20
		jp	z,h8c9
		ld	a,(0x73EE)
		and	1
		jp	nz,hs_8C36
		jp	hs_8D55
h8c9:		ld	a,(0x73EE)
		and	1
		jp	z,hs_8CD1
 IFDEF NES_FULL
 ; The head probe leaves a free rope before the feet reach its cap.
 ; Keep climbing that final cell, then hold on the cap without a side snap.
 ld a,(0x705B)
 cp 0x90
 jp nz,hs_8CC5
 ld a,(0x7304)
 and 7
 cp 7
 jp z,hs_8C36
 jp hs_8CD1
 ENDIF
hs_8CC5:	ld	bc,0
		ld	a,(0x7300)
		ld	(0x707C),a
		jp	hs_8A01
hs_8CD1:	ld	a,(0x73EE)
		and	1
		jp	z,h8cd
		ld	bc,0x00FF
		ld	a,(0x7079)
		cp	4
		jp	nz,hs_8C39
		ld	a,(0x70AB)
		and	1
		jp	nz,hs_8C39
		ld	c,0
		jp	hs_8C39
h8cd:		ld	bc,1
		ld	a,(0x73EE)
		and	4
		jp	z,hs_8C36
		call	L_911E
 IFDEF NES_FULL
 ; A horizontal approach may already have attached Joe to the cap.
 ; Down from that hanging pose must take the same ledge entry as walking.
 jp nc,hs_8C39
 cp 0x90
 jp nz,hs_8A01
 call nes_chain_enter
 jp h929_attach
 ELSE
		jp	c,hs_8A01
		jp	hs_8C39
 ENDIF
hs_8D02:	call	L_8C3F			; 4: на лестнице / верёвке
		call	L_90E3
		jp	nc,hs_8D4A
		ld	a,(0x73EE)
		and	8
		ld	bc,0xFE00
		jp	nz,hs_8D14
		ld	a,(0x73EE)
		and	2
		ld	bc,0x0200
		jp	z,hs_8D4A
hs_8D14:	ld	a,(0x705F)
		and	0x20
		jp	z,hs_89DC
		ld	a,(0x70AC)
		cp	1
		jp	nz,hs_89DC
		ld	a,(0x705F)
		or	8
		ld	(0x705F),a
		ld	a,b
		and	0x80
		ld	b,4
		jp	z,hs_89DC
		ld	b,0xFC
		jp	hs_89DC
hs_8D3E:
 IFDEF NES_FULL
 ; NES holds at the lower rope end; Up uses the normal half-speed climb.
 ld a,(0x73EE)
 and 1
 jp z,hs_8C39
 jp hs_8CD1
 ELSE
 ld a,(0x73EE)
 and 1
 jp z,hs_8C39
 ld c,0xFE
 jp hs_8C39
 ENDIF
hs_8D4A:
		IFDEF NES_FULL
		call nes_chain_align
		ENDIF
		ld	bc,0
		ld	a,(0x7058)
		or	a
		jp	z,hs_8C9C
hs_8D55:	ld	a,(0x705B)
		cp	0xD8
		jp	z,hs_8D65
		cp	0x98
		jp	z,hs_8D65
		or	a
		jp	nz,hs_8C87
hs_8D65:	ld	a,(0x705F)
		and	0x20
		jp	nz,hs_8D3E
		ld	bc,0
		IFDEF NES_FULL
		ld a,(0x7300)		; free rope end: count only the actual drop
		ELSE
		ld	a,0xA0
		ENDIF
		ld	(0x707C),a
		ld	a,6
		jp	hs_8988

 ENDIF

; --- L_88D1 (процесс): кадр, такт 70AB, враги, ввод (во вступлении — сам идёт), ветка состояния, шаг ------
L_88D1:
proc_88D1:
 IFNDEF NES_FULL
 call L_92DC
 ENDIF
		ld	a,(0x70AB)
		dec	a
		jp	p,h881
		ld	a,3
h881:		ld	(0x70AB),a
		call	L_A7A1
		call	L_8C1F
		ld	a,(0x705F)
		and	4
		jp	z,h882
 IFDEF NES_FULL
 ld a,0x84                 ; descend the intro rope without horizontal movement
 ELSE
		ld	a,(0x7301)
		cp	0x80
		ld	a,0x86
		jp	c,h883
		ld	a,0x8C
 ENDIF
h883:		ld	(0x73EE),a
h882:		call	L_9156
		call	hero_state
		jp	L_8DE8

; game_over (8B9D): надпись, ждать огня — заново уровень 1 (меню — позже)
game_over:	ld	a,6
		ld	(0x7049),a
		xor	a
		ld	(0x7303),a
		ld	(0x7307),a
 IFDEF NES_FULL
 ld (video_enabled),a
 ld (crit_pend),a
 ENDIF
		call	snd_off
		ld	hl,0
		ld	(0x70BD),hl
		ld	(0x70BE),hl
		IFDEF NES_FULL
		; Shared white slot 1; freeze the underlying scene while the message waits.
		ld hl,game_over_txt
		ld de,0x01EB
		call txt_draw
		ELSE
		ld	bc,0x0109
		ld	hl,C_9409
		ld	de,0x016C
		call	L_AEA7
		ENDIF
go1:		ld	a,1
		ld	(kb_req),a
		call	frame_wait
		ld	a,(kbmat+7)
		and	0x80
		jp	z,go1
		di
		IFDEF NES_FULL
 ld sp,GSTACK
 jp title_resume
 ELSE
		ld	sp,0x0100
		jp	boot
 ENDIF

		IFNDEF	STRICT
; Допуск у лестниц (отступление от оригинала; сборка с -DSTRICT — как у MSX). Тайлы у героя 7057..7059 —
; столбцы c - 1, c, c + 1 (c = (X + 1) / 8), 705A..705C — под ними. Лестница (шест) не в c, а рядом, и герой
; не дальше LD_TOL точек от окна — X сдвигается на 8 в окно (дальше выравнивание оригинала). Z — можно.
 IFDEF NES_FULL
 INCLUDE "nes_ladder_entry.asm"
 ELSE
LD_TOL		equ	7			; допуск: окно оригинала (8 точек) шире на LD_TOL с каждой стороны
h929k:		pop	af
		jp	hs_897C
; ld_lad: вниз по лестнице — у оригинала 705B = 10, 705C = 11 (верх лестницы)
ld_lad:		ld	a,(0x705A)		; 705A = 10, 705B = 11: правее окна
		cp	0x10
		jp	nz,ldl1
		ld	a,(0x705B)
		cp	0x11
		jp	z,ld_r
ldl1:		ld	a,(0x705C)		; 705C = 10: левее
		cp	0x10
		jp	z,ld_l
		or	1
		ret
; ld_up: вверх — у оригинала 7058 = 88, 7059 = 89
ld_up:		ld	a,(0x7058)
		cp	0x88
		jp	nz,ldu1
		ld	a,(0x7059)
		cp	0x89
		ret
ldu1:		cp	0x89			; 7057 = 88, 7058 = 89: правее окна
		jp	nz,ld_ul
		ld	a,(0x7057)
		cp	0x88
		ret	nz
ld_r:		ld	a,(0x7301)		; правее: (X + 1) & 7 < LD_TOL — X -= 8
		inc	a
		and	7
		cp	LD_TOL
		jp	nc,ld_no
		ld	a,0xF8
		jp	ld_mv
ld_l:		ld	a,(0x7301)		; левее: (X + 1) & 7 >= 8 - LD_TOL — X += 8
		inc	a
		and	7
		cp	8-LD_TOL
		jp	c,ld_no
		ld	a,8
ld_mv:		ld	hl,0x7301
		add	a,(hl)
		ld	(hl),a
		ld	(0x7305),a
		xor	a
		ret
ld_no:		or	1
		ret
ld_ul:		ld	a,(0x7059)		; 7059 = 88: левее окна
		cp	0x88
		ret	nz
		jp	ld_l
; ld_down: вниз — у оригинала 705B = C4 (A = 705B)
ld_down:	cp	0xC4
		ret	z
		ld	a,(0x705A)
		cp	0xC4
		jp	z,ld_r
		ld	a,(0x705C)
		cp	0xC4
		ret	nz
		jp	ld_l
 ENDIF
		ENDIF

 IFDEF NES_STABLE_COLORS
nes_landing_y:
 ld hl,0x704B
 add a,(hl)
 ld (hl),a
 ld (0x707C),a
 ld hl,0x704F
 ld a,c
 add a,(hl)
 ld (hl),a
 ld a,0x80                 ; release the scripted Down on the first landing
 ld (0x73EE),a
 xor a
 ld (0x707D),a              ; saved vertical motion
 ld (0x707F),a              ; saved standing state, not the initial free-fall
 ret
 ENDIF

 IFDEF NES_FULL
nphys_slide:
 call L_911E
 jp nc,hs_8A86
 ld bc,2
 jp hs_8C39
nt_fall_speed:
 ld bc,3                    ; NES free fall, $A680: three pixels per step

 ld hl,0x7072
 ld a,(hl)
 or a
 jp m,nt_fall_momentum
 ld a,(0x705F)
 and 0x20
 ret z                      ; walking off an edge has no jump momentum
nt_fall_momentum:
 rrca                       ; бит 0 (0x81) — первый шаг падения после прыжка
 ld a,(0x7076)
 ld b,a
 ret nc
 dec (hl)                   ; NES: первый шаг падения (счётчик 0) сначала сдвигает Джо на 3 точки,
 pop hl                     ; проверка опоры — со следующего шага; иначе на верхней точке прыжка
 jp hs_8B06                 ; ступни внутри плитки ленты и Джо «подтягивается» на неё
 ENDIF
