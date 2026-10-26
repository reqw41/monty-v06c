; Главный цикл (A5D1, src/model/main.js): таблица процессов A8A1 — (счётчик, процедура, перезагрузка):
; процедура вызывается, когда счётчик = 1; FE — процесс выключен. Ожидания кадра: A5D8 — пока 705F бит 3,
; A5CA — пока 7207 бит 7 = 0 (кадр — frame_wait: вывод и обработчик кадра frame_handler).
L_A59D:						; метка начала игры (для стендов)
main_loop:
L_A5D1:		xor	a
		ld	(0x7207),a
		ld	hl,procs
mn1:		ld	a,(0x705F)		; A5D8: ждать сброса 705F бит 3 (A60B в обработчике кадра)
		and	8
		jp	z,mn2
		call	frame_wait
		jp	mn1
mn2:		ld	e,(hl)			; счётчик
		inc	hl
		ld	d,(hl)
		inc	hl
		ld	a,d
		cp	0xFF
		jp	z,mn9
		ld	a,(de)
		cp	0xFE
		jp	z,mn6			; выключен — без изменений
		cp	1
		jp	nz,mn4
		push	hl
		push	de
		ld	a,(hl)			; процедура
		inc	hl
		ld	h,(hl)
		ld	l,a
		ld	de,mn3
		push	de
		jp	(hl)
mn3:		pop	de
		pop	hl
mn4:		ld	a,(de)			; счётчик - 1; 0 — перезагрузка
		dec	a
		jp	nz,mn5
		inc	hl
		inc	hl
		ld	a,(hl)
		dec	hl
		dec	hl
mn5:		ld	(de),a
mn6:		inc	hl
		inc	hl
		inc	hl
		jp	mn1
mn9:		ld	a,(0x7207)		; A5CA: ждать кадра (обработчик ставит 7207 бит 7)
		and	0x80
		jp	nz,main_loop
		call	frame_wait
		jp	mn9

; процессы: счётчик, процедура, перезагрузка
procs:		dw	0x7073, proc_91E5
		db	2
		dw	0x7012, proc_8F5F
		db	4
		dw	0x7068, proc_88D1
		db	1
		dw	0x7074, proc_A8D6
		db	1
		dw	0xFFFF

; --- заглушки (будут модули) ---
proc_91E5:
proc_8F5F:
proc_88D1:
proc_A8D6:	ret
snd_off:	ret
frame_handler:
		ld	hl,0x7207
		dec	(hl)
		ld	a,8
		jp	sat_copy
