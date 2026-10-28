; Нативно: враги A7A1 (по src/model/enemy.js). Список 7086: (флаги, счётчик) на врага, FF — конец; спрайт
; 7300 + 4 * (флаги & 7). Флаги: 7 — направление, 6 — прыгающий, 5 — на конвейере/цепи, 4 — без проверки
; стен, 3 — катящийся. DE держит запись списка, en_sp — адрес спрайта;
; сдвиг остаётся в регистрах C (по Y), B (по X) до применения.

; L_A69F: 7097 += 1; CF := (7097 & 11h) = 0 (HL сохраняется)
L_A69F:		ld	a,(0x7097)
		inc	a
		ld	(0x7097),a
		and	0x11
		ret	nz			; CF = 0 после AND
		scf
		ret
; en_abed (ABED): X спрайта — младшая тетрада := 8, если была >= 8, иначе 0
en_abed:	ld	hl,(en_sp)
		inc	hl
		ld	a,(hl)
		and	0x0F
		cp	8
		ld	c,8
		jp	nc,eab1
		ld	c,0
eab1:		ld	a,(hl)
		and	0xF0
		add	a,c
		ld	(hl),a
		ret
; en_flip: направление записи списка — наоборот
en_flip:	ld	h,d
		ld	l,e
		ld	a,(hl)
		xor	0x80
		ld	(hl),a
		ret

L_A7A1:		ld	hl,0x7086
en_next:	ld	a,(hl)
		cp	0xFF
		ret	z
		push	hl			; preserve record across the tile reader
		and	7			; спрайт
		add	a,a
		add	a,a
		ld	l,a
		ld	h,0x73
		ld	(en_sp),hl
		call	L_9159			; тайлы под врагом -> 7057..705C
		pop	de			; DE = current record; helpers preserve it
		ld	hl,(en_sp)
		ld	a,(hl)			; Y < 15h или >= B8h — направление наоборот
 IFDEF NES_FULL
 cp HUD_ROWS*8+5
 ELSE
 cp 0x15
 ENDIF
		jp	c,en_f1
 IFDEF NES_FULL
 cp SCREEN_HEIGHT-8
 ELSE
 cp 0xB8
 ENDIF
		jp	c,en_f2
en_f1:		call	en_flip
en_f2:		ld	h,d
		ld	l,e
		ld	a,(hl)
		and	0x40
		jp	nz,en_6b3
		ld	hl,(en_sp)		; цвет (не 0): при амулете (704A) — 0E, иначе 0F
		inc	hl
		inc	hl
		inc	hl
		ld	a,(hl)
		or	a
		jp	z,en_c1
		ld	a,(0x704A)
		or	a
		ld	a,0x0F
		jp	z,en_c0
		dec	a
en_c0:		ld	(hl),a
en_c1:		ld	h,d
		ld	l,e
		ld	a,(hl)
		and	8
		jp	z,en_81d
		inc	hl			; катящийся: счётчик + 1; младшая тетрада 4 — кадр
		inc	(hl)
		ld	a,(hl)
		and	0x0F
		cp	4
		jp	nz,en_81d
		ld	a,(hl)
		and	0x80
		ld	(hl),a
		dec	hl
		ld	a,(hl)
		and	0x80
		ld	c,4
		jp	nz,en_r1
		ld	c,0xFC
en_r1:		ld	hl,(en_sp)
		inc	hl
		inc	hl
		ld	a,(hl)
		add	a,c
		cp	0x2C
		jp	nz,en_r2
		ld	a,0x0C
en_r2:		cp	0x08
		jp	nz,en_r3
		ld	a,0x28
en_r3:		ld	(hl),a
		jp	en_81d

en_6b3:		ld	h,d
		ld	l,e		; прыгающий: счётчик - 1 (с 0 — на 5), бит 7 — как был
		inc	hl
		ld	a,(hl)
		and	0x80
		ld	b,a
		ld	a,(hl)
		and	0x7F
		dec	a
		jp	p,en_b1
		ld	a,5
en_b1:		add	a,b
		ld	(hl),a
		and	0x7F
		jp	nz,en_b3
		ld	hl,(en_sp)		; кадр: цвет (не 0) — 0E / 0C, имя ^= 1Ch
		inc	hl
		inc	hl
		inc	hl
		ld	a,(hl)
		or	a
		jp	z,en_b2
		ld	a,(0x704A)
		or	a
		ld	a,0x0C
		jp	z,en_b2a
		ld	a,0x0E
en_b2a:		ld	(hl),a
en_b2:		dec	hl
		ld	a,(hl)
		xor	0x1C
		ld	(hl),a
en_b3:		ld	a,(0x705A)		; на конвейере (10, 11 под ним)?
		cp	0x10
		jp	nz,en_762
		ld	a,(0x705B)
		cp	0x11
		jp	nz,en_762
		ld	h,d
		ld	l,e
		ld	a,(hl)
		and	0x20
		jp	nz,en_71a
		call	L_A69F
		jp	c,en_762
		ld	a,(0x70AB)
		cp	2
		jp	nz,en_762
		call	en_abed
		ld	hl,(en_sp)
		ld	a,(hl)
		add	a,2
		ld	(hl),a
		ld	h,d
		ld	l,e
		ld	a,(hl)
		or	0xA0
		ld	(hl),a
		jp	en_88f
en_71a:		ld	a,(hl)			; HL = запись
		and	0x80
		jp	nz,en_73a
		ld	a,(hl)
		and	0xDF
		ld	(hl),a
		call	L_A69F
		ld	a,8
		jp	c,en_72d
		call	en_flip
		ld	a,0xFE
en_72d:		ld	hl,(en_sp)		; X += A, Y -= 7
		inc	hl
		add	a,(hl)
		ld	(hl),a
		dec	hl
		ld	a,(hl)
		add	a,0xF9
		ld	(hl),a
		jp	en_88f
en_73a:		ld	c,0xFF
		ld	a,(0x705B)
		cp	0xE8
		jp	z,en_73b
		cp	0x08
		jp	nz,en_73c
en_73b:		call	L_A69F
		ld	h,d
		ld	l,e
		jp	c,en_73d
		ld	a,(hl)
		or	0x80
		ld	(hl),a
		ld	a,0xFE
		jp	en_73e
en_73d:		ld	a,(hl)
		and	0x7F
		ld	(hl),a
		ld	a,8
en_73e:		ld	b,a
		ld	c,0
		ld	a,(hl)
		and	0xDF
		ld	(hl),a
		jp	en_87f
en_73c:		ld	b,0
		jp	en_87f
en_762:		ld	a,(0x7057)		; на цепи (88, 89 под ним)?
		cp	0x88
		jp	nz,en_796
		ld	a,(0x7058)
		cp	0x89
		jp	nz,en_796
		ld	a,(0x70AB)
		cp	2
		jp	nz,en_796
		ld	h,d
		ld	l,e
		ld	a,(hl)
		and	0x20
		jp	nz,en_78e
		call	L_A69F
		jp	c,en_796
		call	en_abed
		ld	h,d
		ld	l,e
		ld	a,(hl)
		and	0x7F
		or	0x20
		ld	(hl),a
		xor	a
		jp	en_72d
en_78e:		ld	h,d
		ld	l,e
		ld	a,(hl)
		and	0x80
		jp	nz,en_73a
		ld	bc,1
		jp	en_87f
en_796:		ld	h,d
		ld	l,e
		ld	a,(hl)
		and	0x20
		jp	nz,en_78e
		jp	en_82f
en_81d:		ld	h,d
		ld	l,e
		ld	a,(hl)
		and	0x10
		jp	z,en_82f
		ld	a,(0x7085)		; без проверки стен: у краёв — назад
		cp	8
		jp	c,en_846
		cp	0xF5
		jp	nc,en_846
		jp	en_84a
en_82f:		ld	a,(0x705B)
		or	a
		jp	z,en_846
		ld	h,d
		ld	l,e
		ld	a,(hl)
		and	0x80
		ld	a,(0x7057)
		jp	nz,en_82a
		ld	a,(0x7059)
en_82a:		call	L_A894
		jp	nz,en_84a
en_846:		call	en_flip
en_84a:		ld	c,0
		ld	h,d
		ld	l,e
		ld	a,(hl)
		and	8
		jp	nz,en_84b
		inc	hl			; не катящийся: счётчик - 1 (с 0 — на 39h), сдвиг по Y — C_ABB3[счётчик]
		ld	a,(hl)
		and	0x7F
		dec	a
		jp	p,en_84c
		ld	a,0x39
en_84c:		ld	(hl),a
		ld	hl,C_ABB3
		call	add_hl_a
		ld	c,(hl)
en_84b:		ld	h,d
		ld	l,e
		ld	a,(hl)
		and	0x80
		ld	b,1
		jp	z,en_84d
		ld	b,0xFF
en_84d:		inc	hl
		ld	a,(hl)
		and	0x80
		jp	z,en_84e
		ld	a,b
		add	a,b
		ld	b,a
en_84e:
en_87f:		ld	hl,(en_sp)		; Y -= C, X += B; X < 8 — направление наоборот
		ld	a,(hl)
		sub	c
		ld	(hl),a
		inc	hl
		ld	a,b
		add	a,(hl)
		ld	(hl),a
		cp	8
		call	c,en_flip
en_88f:		ld	h,d
		ld	l,e
		inc	hl
		inc	hl
		jp	en_next
