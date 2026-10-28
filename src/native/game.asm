; Montezuma's Revenge для Вектора-06Ц — нативная сборка (docs/NATIVE.md): логика вручную по JS-модели
; (src/model), прямой вывод карты и объектов, без перевода Z80 и слоя OS7.
;   node tools/vsnap.js && python3 -I tools/mknative.py && \
;   (cd src/native && ../../tools/sjasmplus --nologo --i8080 --sym=../../build/native/monty.sym game.asm)
; Память — src/native/mem.asm; ОЗУ игры 7000-73FF — как у оригинала (сверка tools/lockstep.js).
		DEVICE	NOSLOT64K
		INCLUDE	"mem.asm"
PND		equ	NTS			; клетка ждёт вывода (1) — по адресу клетки в VNT (выровнена так же)
DIRTY_BELT		equ	0x01			; отметки для вывода (display.asm)
DIRTY_COLOR		equ	0x02
DIRTY_ROOM		equ	0x04
DIRTY_FIRE		equ	0x08
		DEFINE	NATIVE
SPR_MAX		equ	6
DL_MAX		equ	127			; список изменённых клеток (dlist, по 2 байта)
dl_n		equ	0x7FA8
dl_ovf		equ	0x7FA9
dl_cnt		equ	0x7FAA
dl_k		equ	0x7FAB
cover_moves	equ	0x7FAE
kb_req		equ	0x7FAC
rs_mode		equ	0x7FAD
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
other_colors		equ	0x7FF1			; новый цвет у групп не 1C/1D (room_color_changes)
fl_pg		equ	0x7FF2			; force_live_t: страница флагов, плоскости, клеток, огонь по очереди
fl_pm		equ	0x7FF3
fl_n		equ	0x7FF4
fl_end		equ	0x7FF5
dc_pt		equ	0x7FF9			; только изменяющиеся плоскости живых тайлов (force_live_t;
						; прерывание тогда клетки не рисует — подготовка идёт только без crit_pend)
band_pairs	equ	0x66E0			; 28 bytes after spr_new, before sprt
lv_dirty	equ	0x7FFC			; список живых клеток устарел (в клетку поставлен живой тайл)
fl_ph		equ	0x7FBD			; огонь: очередь клеток, маска (0 — все)
fl_skm		equ	0x7FBE
fl_c		equ	0x7FBF
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
		ld	sp,0x0038		; boot stack 0008..0037; 0040..00FF holds logic classes
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
		ld	hl,PS_TOP		; записи и таблицы спрайтов (6600-67FF)
		ld	bc,0x0200
		ld	e,0
		call	memfill
		ld	hl,0x7000		; ОЗУ игры
		ld	bc,0x0400
		ld	e,0
		call	memfill
		ld	hl,VNT			; карта и переменные (исходные спрайты 7400-7BFF — из образа)
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
		ld	sp,0x0038
		call	vi_off			; ВИ53 молчит, каналы SN — тоже (TURN_OFF_SOUND оригинала)
		call	snd_off
		ld	de,ps_boot_source
		ld	hl,TILE_IMAGES
		ld	bc,ps_boot_source_end-ps_boot_source
		call	copy_de_hl
		call	mask_keys_init
		call	trim_build
		call joe_load
		call	ps_build		; готовые сдвиги кадров врагов
		call	lv_init
		ld	a,1
		ld	(kb_req),a
		call	game_init
		ld	sp,GSTACK
		ei
		jp	game_start		; меню и начало уровня (level.asm)

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
		ld	a,(kb_req)		; сначала то, что только в начале кадра: клавиатура (порт 03 — он же прокрутка),
		or	a			; палитра; потом спрайты (короткая часть), пока луч наверху
		jp	z,isr1
		xor	a
		ld	(kb_req),a
		call	kb_scan
isr1:		call	pal_load_isr
 call joe_latch_y
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
isr0:		ld	hl,(frames)
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
		ld	hl,nmi_pend
		ld	a,(hl)
		cp	8
		jp	nc,isr_event_done
		inc	(hl)
isr_event_done:	pop	de
		pop	bc
		ld	hl,(isr_sp)
		ld	sp,hl
		pop	hl
		pop	af
		ei
		ret

; frame_wait: подготовка -> событие кадра -> обработчик логики.
; Задержку картинки ограничивает joe_step_gate на границе всего шага, а не внутри процесса.
frame_wait:
		push	af
		push	bc
		push	de
		push	hl
		ld	hl,0
		add	hl,sp
		ld	(np_sp),hl
		ld	sp,DISP_STACK
		call joe_finish_old
		ld	a,(crit_pend)
		or	a
		call	z,disp_prep
 ld a,1
 ld (jn_wait),a
fw2:
fw_event:
		ld	a,(nmi_pend)
		or	a
		jp	z,fw2
		ld	hl,nmi_pend
		dec	(hl)		; one instruction: IRQ increment cannot interleave
		xor a
 ld (jn_wait),a
 call	frame_handler
fw_return:	ld	hl,(np_sp)
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

		INCLUDE	"map.asm"
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
		INCLUDE "joe.asm"
		INCLUDE	"render.asm"
		INCLUDE	"cell.asm"
		INCLUDE	"../vec/util.asm"
		INCLUDE	"../vec/gen/pal.asm"
		INCLUDE	"gen/cart.asm"

ex_bb:		ds	4			; общая рамка отложенных клеток
lv_tile:	ds	33			; живые клетки: тайл корзины
lv_beg:		ds	34			; начало корзины в live_list (+ всего)
lv_pos:		ds	33			; счётчики/позиции при раскладке
lv_idx		equ	0xF400			; тайл -> корзина (FF — не живой); бывший кэш тайлов в невидимой плоскости
		INCLUDE	"gen/video.asm"
		INCLUDE	"vars.asm"
ps_idx		equ	0x7F00			; 64 байта; выше остаются 64 байта стека IRQ
ps_tab:		ds	2*8*PS_N
ps_rr:		ds	PS_N
ps_rp equ 0xFF00
ps_p equ 0xFF02
ps_end equ 0xFF04
ps_nm equ 0xFF06
ps_f equ 0xFF07
ps_r0 equ 0xFF08
ps_s equ 0xFF09
ps_dst equ 0xFF0A
ps_c0 equ 0xFF0C
ps_c1 equ 0xFF0D
ps_c2 equ 0xFF0E
ps_m equ 0xFF0F
mb_d equ repl		; цепочки pal_build больше не нужны после построения cmap
ps_heap:					; дальше до PS_TOP — место готовых сдвигов
		ASSERT	ps_heap <= PS_TOP
; выровненные таблицы — на постоянных адресах под 7000 (рост кода не сдвигает их на страницу)
PS_TOP		equ	0x6600
		ORG	PS_TOP
spr_rec:	ds	0x80			; записи спрайтов (SREC x SPR_MAX)
spr_new:	ds	SREC*SPR_MAX		; новые атрибуты (spr_rec + 80h)
		ORG	0x6700
; таблицы спрайтов — в одной странице (адрес — одной командой)
sprt:
ubr:		ds	4*SPR_MAX		; рамки спрайтов: прежнее и новое место (ub_build)
mk_key:		ds	4*SPR_MAX		; маска в ячейке: шаблон, сдвиг, начало, строк (spr_masks)
grp:		ds	SPR_MAX			; crit_plan: группы
sprt_end:
		ASSERT	sprt/256 == (sprt_end-1)/256
		ORG	0x6800
dlist:		ds	256			; список изменённых клеток (адреса в VNT)
PS_MORE		equ	video_raw_end		; после исходных полос — готовые сдвиги
		ASSERT	PS_MORE < 0x7000
		INCLUDE	"gen/spat_nes.asm"			; ORG VSPR — шаблоны спрайтов прямо в образе

		INCLUDE "gen/joe_nes.asm"
		INCLUDE "gen/joe_mirror.asm"
sprite_sources_end:
		INCLUDE "joe_attrs.asm"
		ASSERT $ <= 0x7B00
 INCLUDE "gen/joe_nibble.asm"
		INCLUDE "joe_bands.asm"
 INCLUDE "joe_latch.asm"

		INCLUDE "gen/logic.asm"

		IFDEF STRICT
		SAVEBIN	"../../build/native_strict/monty.bin", 0, VSPR+0x0800
		ELSE
		SAVEBIN	"../../build/native/monty.bin", 0, VSPR+0x0800
		ENDIF
