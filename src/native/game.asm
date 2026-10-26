; Montezuma's Revenge для Вектора-06Ц — нативная сборка (docs/NATIVE.md): логика вручную по JS-модели
; (src/model), вывод — общий с src/vec (display, sprites, cell, render), без перевода Z80 и слоя OS7.
;   node tools/vsnap.js && python3 -I tools/mknative.py && \
;   (cd src/native && ../../tools/sjasmplus --nologo --i8080 --sym=../../build/native/monty.sym game.asm)
; Память — src/vec/mem.asm; ОЗУ игры 7000-73FF — как у оригинала (сверка tools/lockstep.js).
		DEVICE	NOSLOT64K
		INCLUDE	"../vec/mem.asm"
VD_PAT		equ	0x01			; отметки для вывода (display.asm)
VD_COL		equ	0x02
VD_NT		equ	0x04
VD_REG		equ	0x08
DSKIP		equ	2			; вывод — раз в DSKIP шагов
GSTACK		equ	0x73C0			; стек игры (как у оригинала)
; переменные только нативной сборки — 7FA0-7FFF (за копией цветов; чистятся при загрузке)
a4_n		equ	0x7FA0
a0_sp		equ	0x7FA2

		ORG	0x0000
		di
		ld	sp,0x0100		; загрузка — на стеке под кодом
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
		ld	hl,pvars		; переменные платформы и таблицы
		ld	bc,tabs_end-pvars
		ld	e,0
		call	memfill
		ld	hl,0x7000		; ОЗУ игры и копии VRAM
		ld	bc,0x1000
		ld	e,0
		call	memfill
		ld	hl,0x8000		; экран и невидимая плоскость
		ld	bc,0x8000
		ld	e,0
		call	memfill
		call	pats_init		; шаблоны: банк 0 -> E000, различия -> dslot/dstore, спрайты -> VSPR
		call	cache_flush
		ld	a,0xD0
		ld	(VSAT),a
		call	level_snap		; уровень 1: ОЗУ игры, таблица имён, цвета, регистры — со снимка
		ld	sp,GSTACK		; (после снимка: он перекрывает и область стека игры)
		ei
		jp	main_loop

; pats_init: шаблоны из снимка VRAM (gen/pats.asm)
pats_init:
		ld	hl,0xE000		; банк 0
		ld	de,pat0
		ld	bc,0x0800
		call	copy_de_hl
		ld	hl,dslot		; различия: dslot[t] := номер, dstore — 24 байта на тайл
		ld	bc,256
		ld	e,0xFF
		call	memfill
		ld	hl,anim_set
		ld	b,0
pi1:		ld	a,(hl)
		cp	0xFF
		jp	z,pi2
		push	hl
		ld	l,a
		ld	h,dslot/256
		ld	(hl),b
		pop	hl
		inc	hl
		inc	b
		jp	pi1
pi2:		ld	hl,dstore
		ld	de,pdiff
		ld	bc,24*DMAX
		call	copy_de_hl
		ld	hl,VSPR
		ld	de,spat
		ld	bc,0x0800
		jp	copy_de_hl
; copy_de_hl: (HL) <- (DE), BC байт
copy_de_hl:	ld	a,(de)
		ld	(hl),a
		inc	hl
		inc	de
		dec	bc
		ld	a,b
		or	c
		jp	nz,copy_de_hl
		ret

; --- прерывание кадра: клавиатура (в начале — порт 03 и прокрутка), счётчик, палитра, кадр игры к выдаче ---
isr:
		push	af
		push	hl
		ld	hl,0
		add	hl,sp
		ld	(isr_sp),hl
		ld	sp,ISR_STACK
		push	bc
		push	de
		call	kb_scan
		ld	hl,(frames)
		inc	hl
		ld	(frames),hl
		call	pal_load_isr
		ld	a,1
		ld	(nmi_pend),a
		pop	de
		pop	bc
		ld	hl,(isr_sp)
		ld	sp,hl
		pop	hl
		pop	af
		ei
		ret

; --- frame_wait: ожидание кадра в главном цикле: пока ждём — подготовка вывода (раз в DSKIP шагов); пришёл
; кадр — спрайты (короткая часть), затем обработчик кадра игры (frame_handler). Свой стек (DISP_STACK).
frame_wait:
		push	af
		push	bc
		push	de
		push	hl
		ld	hl,0
		add	hl,sp
		ld	(np_sp),hl
		ld	sp,DISP_STACK
		ld	a,(dp_done)
		or	a
		jp	nz,fw2
		inc	a
		ld	(dp_done),a
		ld	hl,disp_n
		inc	(hl)
		ld	a,(hl)
		cp	DSKIP
		jp	c,fw2
		ld	(hl),0
		call	disp_prep
		ld	a,(crit_pend)		; кадр пришёл во время подготовки — короткая часть со следующим
		or	a
		jp	z,fw2
		di
		xor	a
		ld	(nmi_pend),a
		ei
fw2:		ld	a,(nmi_pend)		; кадра ждать
		or	a
		jp	z,fw2
		di
		xor	a
		ld	(nmi_pend),a
		ei
		ld	(dp_done),a
		ld	a,(crit_pend)
		or	a
		jp	z,fw3
		xor	a
		ld	(crit_pend),a
		call	crit
fw3:		call	frame_handler
		ld	hl,(np_sp)
		ld	sp,hl
		pop	hl
		pop	de
		pop	bc
		pop	af
		ret

; палитра: pal (16) в порты при pal_load > 0
pal_load_isr:
		ld	a,(pal_load)
		or	a
		ret	z
		dec	a
		ld	(pal_load),a
		ld	hl,pal+15
		ld	e,0x0F
pl0:		ld	a,e
		out	(0x02),a
		ld	a,(hl)
		dec	hl
		out	(0x0C),a
		out	(0x0C),a
		out	(0x0C),a
		out	(0x0C),a
		dec	e
		jp	p,pl0
		xor	a
		out	(0x02),a
		ret

; kb_scan: клавиатура Вектора -> kbmat[8] (бит 1 — нажата); только из прерывания
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

		INCLUDE	"vid.asm"
L_9156:		INCLUDE	"tiles.asm"
L_AEA7:		INCLUDE	"block.asm"
unit_trap:	jp	unit_trap		; возврат для tools/unit.js
		INCLUDE	"level.asm"
		INCLUDE	"drawroom.asm"
		INCLUDE	"main.asm"
		INCLUDE	"../vec/display.asm"
		INCLUDE	"../vec/sprites.asm"
		INCLUDE	"../vec/render.asm"
		INCLUDE	"../vec/cell.asm"
		INCLUDE	"../vec/util.asm"
		INCLUDE	"../vec/gen/pal.asm"
		INCLUDE	"gen/cart.asm"
		INCLUDE	"gen/pats.asm"
		INCLUDE	"../vec/vars.asm"

		SAVEBIN	"../../build/native/monty.bin", 0, 0x7000
