; Montezuma's Revenge для Вектора-06Ц: сборка игры (docs/PORT_DESIGN.md).
;   python3 -I tools/mkvecdata.py && python3 -I tools/z2i.py && \
;   (cd src/vec && ../../tools/sjasmplus --nologo --i8080 --sym=../../build/vec/monty.sym game.asm)
; Память: 0000 векторы; 0100 код и данные; 7000-73FF ОЗУ игры (как у Coleco); 7400-7FFF виртуальная VRAM
; (VSPR, VNT, VSAT, VCOL); 8000-DFFF экран (3 плоскости); E000-FFFF банки шаблонов тайлов (невидимая плоскость).
		DEVICE	NOSLOT64K
PACE		equ	1			; кадров на шаг игры не меньше (1 — без ограничения)
DSKIP		equ	2			; вывод — раз в DSKIP шагов (ровно, без пачек)
		INCLUDE	"mem.asm"

		ORG	0x0000
		di
		ld	sp,0x0100		; загрузка — на стеке под кодом (8000-FFFF и 7000-7FFF чистятся)
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
		ld	hl,0x7000		; ОЗУ игры и виртуальная VRAM
		ld	bc,0x1000
		ld	e,0
		call	memfill
		ld	hl,0x8000		; экран и банки шаблонов
		ld	bc,0x8000
		ld	e,0
		call	memfill
		ld	a,0xE0
		ld	(tile_hi),a
		call	d_init			; различия банков — постоянный набор тайлов
		call	cache_flush
		ld	a,0xD0			; список спрайтов пуст
		ld	(VSAT),a
		jp	L_8025			; старт картриджа

; --- прерывание кадра Вектора: свой стек, «NMI» VDP (A9B3) при разрешённом прерывании VDP, вывод -------
isr:
		push	af			; флаги — первыми: ADD HL,SP ниже меняет CY прерванной программы
		push	hl
		ld	hl,0
		add	hl,sp
		ld	(isr_sp),hl
		ld	sp,ISR_STACK
		push	bc
		push	de
		call	kb_scan			; клавиатура — сразу, до 40-й строки (порт 03 — и прокрутка)
		ld	hl,(frames)
		inc	hl
		ld	(frames),hl
		call	pal_load_isr
		ld	a,(vstat)		; флаг кадра VDP
		or	0x80
		ld	(vstat),a
		ld	a,(nmi_pend)		; долг кадров для обработчика игры (запуск — в ожидании главного цикла), до 4
		cp	4
		jp	nc,isr_x
		inc	a
		ld	(nmi_pend),a
isr_x:		pop	de
		pop	bc
		ld	hl,(isr_sp)
		ld	sp,hl
		pop	hl
		pop	af
		ei
		ret

; nmi_run: обработчик кадра игры (A9B3); z_t/z_t2 — сохранить (вставки BIT в прерванном коде)
nmi_run:
		ld	a,1
		ld	(in_nmi),a
		ld	a,(z_t)
		push	af
		ld	hl,(z_ix)
		push	hl
		ld	hl,(z_iy)
		push	hl
		xor	a			; NMI снимает флаг кадра чтением статуса в обработчике; здесь — уже «доставлен»
		call	L_A9B3
		pop	hl
		ld	(z_iy),hl
		pop	hl
		ld	(z_ix),hl
		pop	af
		ld	(z_t),a
		xor	a
		ld	(in_nmi),a
		ret

; Ожидание кадра главным циклом: обработчик игры — только если цикл действительно ждёт (условие не выполнено)
; и был кадр Вектора. Не зависит от скорости: тот же порядок, что у модели MSX в режиме coop.
nmi_wait_a5d8:					; A5D8: процессы ждут сброса 705F бит 3 (A60B в обработчике)
		push	af
		ld	a,(0x705F)
		and	0x08
		jp	z,np9
		pop	af
		jp	nmi_poll
nmi_wait_a5ca:					; A5CA: ждёт 7207 бит 7
		push	af
		ld	a,(0x7207)
		and	0x80
		jp	nz,np9
		pop	af
		jp	nmi_poll
nmi_wait_8c19:					; 8C19: ждёт сброса 70B1 бит 3
		push	af
		ld	a,(0x70B1)
		and	0x08
		jp	z,np9
		pop	af
nmi_poll:
		push	af
		ld	a,(vregs+1)
		and	0x20
		jp	z,np9
		ld	a,(in_nmi)
		or	a
		jp	nz,np9
		push	bc
		push	de
		push	hl
		ld	hl,0			; свой стек: вывод и обработчик кадра не растят стек игры (он над 7300)
		add	hl,sp
		ld	(np_sp),hl
		ld	sp,DISP_STACK
		ld	a,(dp_done)		; пока ждём кадр — подготовить вывод (один раз за шаг, раз в DSKIP шагов)
		or	a
		jp	nz,np2
		inc	a
		ld	(dp_done),a
		ld	hl,disp_n
		inc	(hl)
		ld	a,(hl)
		cp	DSKIP
		jp	c,np2
		ld	(hl),0
		call	disp_prep
		ld	a,(crit_pend)		; кадр пришёл во время подготовки — короткая часть со следующим
		or	a
		jp	z,np2
		ld	a,(nmi_pend)
		or	a
		jp	z,np2
		di
		xor	a
		ld	(nmi_pend),a
		ei
np2:		ld	a,(nmi_pend)
		or	a
		jp	z,np8
		di
		xor	a
		ld	(nmi_pend),a		; кадр пришёл: долг не копится — шаги не сыплются пачкой
		ei
		ld	a,(step_f)		; ровный ритм: шаг не чаще, чем раз в PACE кадров
		ld	b,a
		ld	a,(frames)
		sub	b
		cp	PACE
		jp	c,np8
		ld	a,(frames)
		ld	(step_f),a
		xor	a
		ld	(dp_done),a
		ld	a,(crit_pend)		; сразу после прерывания — спрайты (короткая часть)
		or	a
		jp	z,np3
		xor	a
		ld	(crit_pend),a
		call	crit
np3:		call	nmi_run			; затем обработчик кадра игры
np8:		ld	hl,(np_sp)
		ld	sp,hl
		pop	hl
		pop	de
		pop	bc
np9:		pop	af
		ret

; палитра: pal (16) в порты при pal_load > 0 (несколько кадров — на случай промаха мимо обратного хода)
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

		INCLUDE	"os7.asm"
		INCLUDE	"adapter.asm"
		INCLUDE	"display.asm"
		INCLUDE	"sprites.asm"
		INCLUDE	"render.asm"
		INCLUDE	"cell.asm"
		INCLUDE	"util.asm"
		INCLUDE	"gen/zhelp.asm"
		INCLUDE	"gen/game.asm"
		INCLUDE	"gen/pal.asm"
		INCLUDE	"gen/os7font.asm"

		INCLUDE	"vars.asm"

		SAVEBIN	"../../build/vec/monty.bin", 0, 0x7000
