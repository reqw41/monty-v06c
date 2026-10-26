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
		DEFINE	NATIVE
SPR_MAX		equ	6
DL_MAX		equ	127			; список изменённых клеток (dlist, по 2 байта)
dl_n		equ	0x7FA8
dl_ovf		equ	0x7FA9
dl_cnt		equ	0x7FAA
dl_k		equ	0x7FAB
kb_req		equ	0x7FAC
rs_mode		equ	0x7FAD
sp_end		equ	0x7FAE
sp_vp		equ	0x7FB0
sp_ap		equ	0x7FB2
sy_k		equ	0x7FB4
sy_se		equ	0x7FB5
ub_c1		equ	0x7FB7
cu_g		equ	0x7FB8
cu_gj		equ	0x7FB9
gp_a		equ	0x7FBA
lv_nn		equ	0x7FBB
sp_pm		equ	0x7FBC
vi_dv		equ	0x7FC0			; ВИ53: заданные делители счётчиков 0..2 (0 — молчит)
vi_rnd		equ	0x7FC6			; случайное для шума
GSTACK		equ	0x73C0			; стек игры (как у оригинала)
; переменные только нативной сборки — 7FA0-7FFF (за копией цветов; чистятся при загрузке)
a4_n		equ	0x7FA0
en_hl		equ	0x7FA2
en_sp		equ	0x7FA4
en_c		equ	0x7FA6
en_b		equ	0x7FA7

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
		ld	hl,0x7000		; ОЗУ игры
		ld	bc,0x0400
		ld	e,0
		call	memfill
		ld	hl,VNT			; копии VRAM (шаблоны спрайтов VSPR 7400-7BFF — из образа)
		ld	bc,0x0400
		ld	e,0
		call	memfill
		ld	hl,0x8000		; экран и невидимая плоскость
		ld	bc,0x8000
		ld	e,0
		call	memfill
		call	vi_off			; ВИ53 молчит, каналы SN — тоже (TURN_OFF_SOUND оригинала)
		call	snd_off
		call	pats_init		; шаблоны: банк 0 -> E000, различия -> dslot/dstore, спрайты -> VSPR
		call	tc_init
		call	se_init
		call	bd_init
		call	lv_init
		call	cache_flush
		ld	a,0xD0
		ld	(VSAT),a
		ld	a,1
		ld	(kb_req),a
		call	game_init
		ld	sp,GSTACK
		ei
		jp	game_start		; меню и начало уровня (level.asm)

; pats_init: шаблоны из снимка VRAM (gen/pats.asm)
pats_init:
		ld	hl,0xE000		; банк 0 (сжатый)
		ld	de,pat0_pk
		call	unpack
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
		ld	a,(kb_req)		; клавиатура — по запросу (раз в шаг, после чтения игрой)
		or	a
		jp	z,isr1
		xor	a
		ld	(kb_req),a
		call	kb_scan
isr1:		ld	hl,(frames)
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
unit_fw:	push	af			; tools/unit.js: ожидание кадра = обработчик кадра (регистры сохраняются)
		push	bc
		push	de
		push	hl
		call	frame_handler
		pop	hl
		pop	de
		pop	bc
		pop	af
		ret
		INCLUDE	"level.asm"
		INCLUDE	"drawroom.asm"
		INCLUDE	"screen.asm"
		INCLUDE	"sound.asm"
		INCLUDE	"frame.asm"
		INCLUDE	"enemy.asm"
		INCLUDE	"collide.asm"
		INCLUDE	"hero.asm"
		INCLUDE	"main.asm"
		INCLUDE	"display.asm"
		INCLUDE	"sprites.asm"
		INCLUDE	"render.asm"
		INCLUDE	"cell.asm"
		INCLUDE	"../vec/util.asm"
		INCLUDE	"../vec/gen/pal.asm"
		INCLUDE	"gen/cart.asm"
		ALIGN	256
dlist:		ds	256			; список изменённых клеток (адреса в VNT)
tc_tab:		ds	256			; адреса ячеек кэша изображений (младшие, старшие + 80h)
; таблицы спрайтов — в одной странице (адрес — одной командой)
sprt:
gact:		ds	SPR_MAX			; gact, gs, ge, gd — подряд
gs:		ds	SPR_MAX
ge:		ds	SPR_MAX
gd:		ds	SPR_MAX
svr:		ds	4*SPR_MAX
rst:		ds	6*SPR_MAX
pps:		ds	6*SPR_MAX
pps2:		ds	2*SPR_MAX
ppd:		ds	11*SPR_MAX
ubr:		ds	4*SPR_MAX		; рамки спрайтов: прежнее и новое место (ub_build)
sprt_end:
		ASSERT	sprt/256 == (sprt_end-1)/256
tcache2:	ds	24*TC_N			; кэш изображений тайлов
se_tab:		ds	8*24			; адреса входа блоков по числу строк (se_init)
bd_tab:		ds	48			; переходы банков: какие анимированные тайлы меняются (bd_init)
ex_bb:		ds	4			; общая рамка отложенных клеток
lv_tile:	ds	33			; живые клетки: тайл корзины
lv_beg:		ds	34			; начало корзины в live_list (+ всего)
lv_pos:		ds	33			; счётчики/позиции при раскладке
lv_idx		equ	0xF400			; тайл -> корзина (FF — не живой); бывший кэш тайлов в невидимой плоскости
AB_N		equ	24			; запас изображений анимированных тайлов: abank[банк 0..3][номер в anim_set]
abank		equ	0xF500			; ячейка (FF — нет; бит 7 — устарело); бывший кэш тайлов vec-сборки
ab_img		equ	0xF560			; банк нынешнего изображения (tslot) по номеру в anim_set
		INCLUDE	"gen/pats.asm"
		INCLUDE	"../vec/vars.asm"
		INCLUDE	"gen/spat.asm"			; ORG VSPR — шаблоны спрайтов прямо в образе

		IFDEF STRICT
		SAVEBIN	"../../build/native_strict/monty.bin", 0, VSPR+0x0800
		ELSE
		SAVEBIN	"../../build/native/monty.bin", 0, VSPR+0x0800
		ENDIF
