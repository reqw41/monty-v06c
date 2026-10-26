; Этап 1: просмотр комнат на Векторе. Стенд (tools/vroom.js) пишет req_lv, req_row, req_room и ждёт done.
;   python3 tools/mkvecdata.py && (cd src/vec && ../../tools/sjasmplus --nologo --i8080 --sym=../../build/vec/viewer.sym viewer.asm)
; Раскладка: 0000 загрузчик и RST 38h; 0100 код и данные; 7000 теневая таблица имён; 7600 переменные; стек до 8000.
		DEVICE	NOSLOT64K
NT		equ	0x7000
NT_SIZE		equ	0x0500
STACK_TOP	equ	0x8000

		ORG	0x0000
		di
		ld	sp,STACK_TOP
		jp	boot
		ORG	0x0038
		jp	isr

		ORG	0x0100
boot:
		ld	a,0x88
		out	(0x00),a
		xor	a
		out	(0x02),a
		ld	a,0xFF
		out	(0x03),a
		ld	a,0xFF			; запрос стенда до очистки экрана — иначе ранний запрос затирается
		ld	(req_room),a
		xor	a
		ld	(pal_load),a
		call	clear_screen
		ei
main_loop:
		ld	a,(req_room)
		cp	0xFF
		jp	z,main_loop
		call	show_room
		ld	a,0xFF
		ld	(req_room),a
		ld	a,1
		ld	(done),a
		jp	main_loop

; show_room: комната req_room уровня req_lv, ряд req_row (для палитры этажа)
show_room:
		ld	a,(req_lv)
		ld	(lv_cur),a
		ld	a,(req_row)
		ld	(row_cur),a
		ld	a,6
		ld	(hud_lives),a
		ld	a,(req_room)
		call	room_draw
		call	hud_after
		call	col_build
		call	pal_build
		call	render_all
		ld	a,3
		ld	(pal_load),a
		ret

; --- прерывание: палитра (pal, 16 элементов) несколько кадров после смены -----------------------------
isr:
		push	af
		push	bc
		push	de
		push	hl
		ld	a,(pal_load)
		or	a
		jp	z,isr1
		dec	a
		ld	(pal_load),a
		ld	hl,pal+15
		ld	e,0x0F
isr0:		ld	a,e
		out	(0x02),a
		ld	a,(hl)
		dec	hl
		out	(0x0C),a
		out	(0x0C),a
		out	(0x0C),a
		out	(0x0C),a
		dec	e
		jp	p,isr0
		xor	a
		out	(0x02),a
isr1:		ld	hl,(frames)
		inc	hl
		ld	(frames),hl
		pop	hl
		pop	de
		pop	bc
		pop	af
		ei
		ret

		INCLUDE	"room.asm"
		INCLUDE	"render.asm"
		INCLUDE	"gen/data.asm"
code_end:
		ASSERT	code_end <= NT

		ORG	0x7600
req_room:	ds	1
req_lv:		ds	1
req_row:	ds	1
done:		ds	1
frames:		ds	2
pal_load:	ds	1
lv_cur:		ds	1
row_cur:	ds	1
hud_lives:	ds	1
rd_p:		ds	2
rd_end:		ds	2
rd_pos:		ds	2
rd_t:		ds	2
rd_k:		ds	1
rd_kk:		ds	1
rd_p1:		ds	1
rd_p2:		ds	1
rd_p3:		ds	1
rd_depth:	ds	1
rd_mir:		ds	1
rd_tall:	ds	1
rd_sh:		ds	1
rd_w:		ds	1
coltab:		ds	32
used:		ds	16
repl:		ds	16
cmap:		ds	16
pal:		ds	16
rr_r:		ds	1
rr_c:		ds	1
rr_nt:		ds	2
rr_t:		ds	1
rr_m:		ds	6
rr_p:		ds	1
rr_np:		ds	1
rr_y:		ds	1
vars_end:
		ASSERT	vars_end < STACK_TOP - 0x200

		SAVEBIN	"../../build/vec/viewer.bin", 0, 0x7600
