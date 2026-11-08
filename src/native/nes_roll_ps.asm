; Катящийся череп по схеме ZX: X чётный, поза — функция X, у каждой позы один сдвиг.
; Виртуальные кадры 3 и 4 (ps_vtab): позы на сдвигах 0, 2, 4, 6 (0 — нет: 0C берётся из кадра прыгающего).
; Одноразовый код ps_build (один раз за включение, после заставки): свободное место образа за nes_skull_source.
	ORG nes_skull_source_end
ps_vbuild:	ld	hl,ps_rr+3
		ld	(hl),14
		inc	hl
		ld	(hl),14
		ld	a,1			; общее окно строк 1..14 (trim_build)
		ld	(ps_f),a
		ld	a,14
		ld	(ps_r0),a
		ld	de,ps_vtab
pvl:		ld	a,(de)
		or	a
		jp	z,pvn
		ld	(ps_nm),a
		push	de
		rrca
		rrca
		and	0x3F
		ld	hl,ps_idx
		call	add_hl_a
		ld	a,e
		sub	ps_vtab&0xFF
		ld	b,a
		and	3
		add	a,a
		ld	(ps_s),a
		ld	a,b
		rrca
		rrca
		and	1
		add	a,3
		ld	c,a
		ld	(hl),a			; ps_idx[поза / 4] := виртуальный кадр
		push	bc
		call	ps_one
		pop	bc
		call	ps_store
		pop	de
pvn:		inc	de
		ld	a,e
		cp	(ps_vtab+8)&0xFF
		jp	nz,pvl
		ret
ps_vtab:	db	0x28,0x24,0x20,0x1C	; X & 8 = 0: позы на сдвигах 0, 2, 4, 6 (поза = 28h - ((2X) & 1Ch))
		db	0x18,0x14,0x10,0	; X & 8 = 8
nes_roll_ps_end:
	ASSERT nes_roll_ps_end <= 0xE700
	ASSERT PS_N == 5
