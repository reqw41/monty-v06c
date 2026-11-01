; Нативно: блок клеток таблицы имён AEA7 (по src/model/vram.js). HL — источник/приёмник, DE — клетка, B строк по
; C тайлов; 7000: бит 4 — чтение, бит 2 — шаг строки 32 (иначе C), бит 3 — «лесенка» (запись: источник +1,
; клетка - 2 на строку). Запись — в VNT с отметкой строк (row_dirty), чтение — из VNT; клетки вне таблицы —
; общим путём (nt_put / nt_get). Выход: BC, DE, HL — как на входе, A = (7000).
; Входная метка L_AEA7 — от транслятора.
 IFDEF NES_FULL
; NES callers only copy one two-cell item row (L_A378). The old MSX room
; decoder's multi-row/read/staircase modes are absent in this build.
 call nt_put
 ld a,(0x7000)
 ret
 ELSE
		push	bc
		push	hl
		push	de
		ld	hl,0x70AF		; вложенность вывода (A8B7)
		inc	(hl)
		ld	a,(0x705F)
		or	2
		ld	(0x705F),a
		pop	de
		pop	hl
		push	hl
		push	de
		ld	a,c
		ld	(bk_c),a
bk_row:
		IFNDEF STRICT
		call nes_service
		ENDIF
		push	bc
		push	hl
		push	de
		ld	a,(bk_c)		; 0 тайлов — ничего (как PUT/GET с числом 0)
		or	a
		jp	z,bk_next
		ld	a,d			; клетки строки внутри таблицы (DE + C <= 300h)?
		cp	2
		jp	c,bk_in
		jp	nz,bk_out
		ld	a,(bk_c)
		add	a,e
		jp	c,bk_out
bk_in:		ex	de,hl			; HL = VNT + клетка, DE = источник/приёмник
		ld	bc,VNT
		add	hl,bc
		ld	a,(bk_c)
		ld	b,a
		ld	a,(0x7000)
		and	0x10
		jp	nz,bk_get
		push	hl			; запись: строки таблицы имён к перерисовке
		push	bc
		call	bk_mark
		pop	bc
		pop	hl
bk_w1:		ld	a,(de)
		ld	(hl),a
		inc	hl
		inc	de
		dec	b
		jp	nz,bk_w1
		jp	bk_next
bk_get:		ld	a,(hl)
		ld	(de),a
		inc	hl
		inc	de
		dec	b
		jp	nz,bk_get
		pop	de			; чтение: приёмник продвигается (как GET_VRAM)
		pop	hl
		ld	a,(bk_c)
		call	add_hl_a
		push	hl
		push	de
		jp	bk_next
bk_out:		ld	a,(0x7000)		; у края — общим путём
		and	0x10
		ld	a,(bk_c)
		ld	c,a
		ld	b,0
		jp	nz,bk_og
		call	nt_put
		jp	bk_next
bk_og:		call	nt_get
		pop	de
		pop	hl
		ld	a,(bk_c)
		call	add_hl_a
		push	hl
		push	de
bk_next:	pop	de
		pop	hl
		ld	a,(0x7000)		; шаг строки: 32 (бит 2) или C
		and	4
		ld	a,0x20
		jp	nz,bk_s1
		ld	a,(bk_c)
bk_s1:		call	de_add_a
		ld	a,(0x7000)		; запись с «лесенкой» (бит 3 без бита 4): источник +1, клетка - 2
		and	0x18
		cp	8
		jp	nz,bk_s2
		inc	hl
		dec	de
		dec	de
bk_s2:		pop	bc
		dec	b
		jp	nz,bk_row
		pop	de
		pop	hl
		pop	bc
		push	hl
		ld	hl,0x70AF		; A8C3
		dec	(hl)
		jp	nz,bk_x
		ld	a,(0x705F)
		and	0xFD
		ld	(0x705F),a
bk_x:		pop	hl
		ld	a,(0x7000)
		ret
; de_add_a: DE += A (A портится)
de_add_a:	add	a,e
		ld	e,a
		ld	a,d
		adc	a,0
		ld	d,a
		ret
; bk_mark: HL = VNT + клетка, B = тайлов — строки клеток HL .. HL + B - 1 к перерисовке
		IFDEF	NATIVE
bk_mark:	ld	a,(video_dirty)		; нативная сборка: клетки — в список изменённых; комната будет нарисована
		and	DIRTY_ROOM			; целиком — не нужно
		ret	nz
		push	hl
bkn1:		call	mark_row
		inc	hl
		dec	b
		jp	nz,bkn1
		pop	hl
		ret
		ELSE
bk_mark:	push	de
		call	vnt_row
		ld	e,a
		ld	a,b
		dec	a
		call	add_hl_a
		call	vnt_row
		ld	d,a
		ld	hl,row_dirty
		ld	a,e
		call	add_hl_a
bkm1:		ld	(hl),1
		inc	hl
		ld	a,e
		cp	d
		jp	z,bkm2
		inc	e
		jp	bkm1
bkm2:		pop	de
		ret
		ENDIF
 ENDIF
