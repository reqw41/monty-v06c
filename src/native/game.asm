; Montezuma's Revenge для Вектора-06Ц — нативная сборка (docs/NATIVE.md): логика вручную по JS-модели
; (src/model), вывод — общий с src/vec (display, sprites, cell, render), без перевода Z80 и слоя OS7.
;   node tools/vsnap.js && python3 -I tools/mknative.py && \
;   (cd src/native && ../../tools/sjasmplus --nologo --i8080 --sym=../../build/native/monty.sym game.asm)
; Память — src/vec/mem.asm; ОЗУ игры 7000-73FF — как у оригинала (сверка tools/lockstep.js).
		DEVICE	NOSLOT64K
		INCLUDE	"../vec/mem.asm"
PND		equ	NTS			; клетка ждёт вывода (1) — по адресу клетки в VNT (выровнена так же)
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
snd_busy	equ	0x7FC7			; логика меняет состояние эффекта — прерывание звук не трогает
snd_acc		equ	0x7FC8			; накопитель 60/50
txt_c		equ	0x7FC9			; txt_draw: цвет, строка экрана, столбец
txt_l		equ	0x7FCA
txt_h		equ	0x7FCB
ml		equ	0x7FCC			; crit_plan: отмеченные спрайты (до 6), сколько, i, j
ml_n		equ	0x7FD2
cu_i		equ	0x7FD3
cu_j		equ	0x7FD4
mg		equ	0x7FD5			; crit_plan: спрайт в группе из нескольких (6)
ps_lo		equ	0x7FDB			; готовые сдвиги спрайта k: блок (мл., ст.; ст. 0 — нет), строк (по 6)
ps_hi		equ	0x7FE1
ps_r		equ	0x7FE7
cb_st		equ	0x7FED			; cb_to: шаг столбцов масок
sp_mskp		equ	0x7FEE			; рисование: страница масок
sp_cr		equ	0x7FEF			; исходный цвет спрайта
pat_oth		equ	0x7FF0			; новая графика у тайлов не E0/E8 (pat_put)
col_oth		equ	0x7FF1			; новый цвет у групп не 1C/1D (col_changed)
fl_pg		equ	0x7FF2			; force_live_t: страница флагов, позиция, клеток, режимы, графика, рамка спрайтов
fl_i		equ	0x7FF3
fl_n		equ	0x7FF4
fl_m		equ	0x7FF5
fl_g		equ	0x7FF6
fl_bb		equ	0x7FF8
lv_dirty	equ	0x7FFC			; список живых клеток устарел (в клетку поставлен живой тайл)
da_t		equ	0x7FFE			; draw_all: прошлый тайл
in_isr		equ	0x7FFD			; идёт прерывание (короткая часть в нём): dc_draw не разрешает прерывания
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
		ld	sp,0			; экран и невидимая плоскость (8000-FFFF) — нулями через стек: PUSH по 2 байта
		ld	hl,0			; (прерывания запрещены)
		ld	b,0
bclr:		REPT	64
		push	hl
		ENDR
		dec	b
		jp	nz,bclr
		ld	sp,0x0100
		call	vi_off			; ВИ53 молчит, каналы SN — тоже (TURN_OFF_SOUND оригинала)
		call	snd_off
		call	pats_init		; шаблоны: банк 0 -> E000, различия -> dslot/dstore, спрайты -> VSPR
		call	se_init
		call	rot_init
		call	trim_build
		call	ps_build		; готовые сдвиги кадров врагов
		ld	a,16
		ld	(cb_st),a
		call	bd_init
		call	lv_init
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
		ld	a,(crit_pend)		; вывод подготовлен — спрайты сейчас, пока луч наверху кадра (короткая часть)
		or	a
		jp	z,isr0
		xor	a
		ld	(crit_pend),a
		inc	a
		ld	(in_isr),a
		call	crit
		xor	a
		ld	(in_isr),a
isr0:
		ld	a,(kb_req)		; клавиатура — по запросу (раз в шаг, после чтения игрой)
		or	a
		jp	z,isr1
		xor	a
		ld	(kb_req),a
		call	kb_scan
isr1:		ld	hl,(frames)
		inc	hl
		ld	(frames),hl
		IFNDEF	STRICT
		ld	a,(snd_busy)		; звук — по прерыванию: эффекты 60 шагов/с (6 на 5 кадров Вектора), ВИ53
		or	a
		jp	nz,isr2
		ld	a,(snd_acc)
		add	a,6
is_s:		cp	5
		jp	c,is_s2
		sub	5
		push	af
		call	L_AC6D
		pop	af
		jp	is_s
is_s2:		ld	(snd_acc),a
		call	snd_vi53
isr2:
		ENDIF
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
		ld	a,(crit_pend)		; прошлый вывод ещё не дорисован прерыванием — новую подготовку не начинать
		or	a
		jp	nz,fw2
		ld	hl,disp_n
		inc	(hl)
		ld	a,(nmi_pend)		; кадр ещё не пришёл — время есть (иначе ждали бы): готовим вывод
		or	a
		jp	z,fwp
		ld	a,(hl)			; уже пришёл (отстаём) — вывод не реже раза в DSKIP шагов
		cp	DSKIP
		jp	c,fw2
fwp:		ld	(hl),0
		call	disp_prep		; crit_pend = 1 — спрайты нарисует следующее прерывание (isr), не ждём
fw2:		ld	a,(nmi_pend)		; кадра ждать
		or	a
		jp	z,fw2
		di
		xor	a
		ld	(nmi_pend),a
		ei
		ld	(dp_done),a
		call	frame_handler
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
rot_tab:	ds	7*256			; повороты байта на 1..7 (rot_init) — маски спрайтов
dlist:		ds	256			; список изменённых клеток (адреса в VNT)
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
mk_key:		ds	4*SPR_MAX		; маска в ячейке: шаблон, сдвиг, начало, строк (spr_masks)
sprt_end:
		ASSERT	sprt/256 == (sprt_end-1)/256
se_tab:		ds	8*24			; адреса входа блоков по числу строк (se_init)
bd_tab:		ds	48			; переходы банков: какие анимированные тайлы меняются (bd_init)
ex_bb:		ds	4			; общая рамка отложенных клеток
lv_tile:	ds	33			; живые клетки: тайл корзины
lv_beg:		ds	34			; начало корзины в live_list (+ всего)
lv_pos:		ds	33			; счётчики/позиции при раскладке
lv_idx		equ	0xF400			; тайл -> корзина (FF — не живой); бывший кэш тайлов в невидимой плоскости
		INCLUDE	"gen/pats.asm"
		INCLUDE	"../vec/vars.asm"
ps_idx:		ds	64			; готовые сдвиги: имя / 4 -> номер (sprites.asm, ps_build)
ps_tab:		ds	2*8*PS_N
ps_rr:		ds	PS_N
ps_rp:		ds	2
ps_p:		ds	2
ps_end:		ds	2
ps_nm:		ds	1
ps_f:		ds	1
ps_r0:		ds	1
ps_s:		ds	1
ps_dst:		ds	2
ps_c0:		ds	1
ps_c1:		ds	1
ps_c2:		ds	1
ps_m:		ds	1
mb_d:		ds	16			; modes_build: вклад индекса как точек / как фона
mb_e:		ds	16
da_buf:		ds	24			; draw_all: образ клетки (плоскости 8000, A000, C000 по 8 байт)
ps_heap:					; дальше до 7000 — место готовых сдвигов
		ASSERT	ps_heap < 0x7000 - 0x400
		INCLUDE	"gen/spat.asm"			; ORG VSPR — шаблоны спрайтов прямо в образе

		IFDEF STRICT
		SAVEBIN	"../../build/native_strict/monty.bin", 0, VSPR+0x0800
		ELSE
		SAVEBIN	"../../build/native/monty.bin", 0, VSPR+0x0800
		ENDIF
