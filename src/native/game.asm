; Montezuma's Revenge для Вектора-06Ц — нативная сборка (docs/NATIVE.md): логика вручную по JS-модели
; (src/model), прямой вывод карты и объектов, без перевода Z80 и слоя OS7.
;   node tools/vsnap.js && python3 -I tools/mknative.py && \
;   (cd src/native && ../../tools/sjasmplus --nologo --i8080 --sym=../../build/native/monty.sym game.asm)
; Память — src/native/mem.asm; ОЗУ игры 7000-73FF — как у оригинала (сверка tools/lockstep.js).
 ; The owner's normal build is the complete NES screen. STRICT remains the
; original MSX geometry/audio reference used by lockstep checks.
 IFNDEF STRICT
 IFNDEF LEGACY_MSX
 IFNDEF NES_STYLE
 DEFINE NES_STYLE
 ENDIF
 IFNDEF NES_FULL
 DEFINE NES_FULL
 ENDIF
 ENDIF
 ENDIF
		DEVICE	NOSLOT64K
		INCLUDE	"mem.asm"
PND		equ	NTS			; клетка ждёт вывода (1) — по адресу клетки в VNT (выровнена так же)
DIRTY_BELT		equ	0x01			; отметки для вывода (display.asm)
DIRTY_COLOR		equ	0x02
DIRTY_ROOM		equ	0x04
DIRTY_FIRE		equ	0x08
DIRTY_SNAKE		equ	0x10			; two NES snake poses, independent of fire
		DEFINE	NATIVE
SPR_MAX		equ	6
DL_MAX		equ	34			; список изменённых клеток (dlist, по 2 байта; в игре максимум 33, хвост — образ колонны)
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
 IFDEF NES_FULL
nes_amulet_ticks equ 0x7FF6		; два свободных байта: защита предмета 09 в кадрах игры
 ENDIF
GSTACK		equ	0x73C0			; стек игры (как у оригинала)
; переменные только нативной сборки — 7FA0-7FFF (за копией цветов; чистятся при загрузке)
a4_n		equ	0x7FA0
en_hl		equ	0x7FA2
en_sp		equ	0x7FA4
en_c		equ	0x7FA6
en_b		equ	0x7FA7

		ORG	0x0000
		di
		ld	sp,0x0038		; boot stack; reused by music after boot
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
 IFDEF NES_FULL
 ld a,0x83                 ; P joystick: PPI2 B input, select both devices
 out (4),a
 ld a,0x9F
 out (5),a
 ENDIF
		ld	hl,pvars		; переменные платформы и таблицы
		ld	bc,tabs_end-pvars
		ld	e,0
		call	memfill
		ld	hl,PS_TOP		; записи и таблицы спрайтов (6600-67FF)
		IFDEF NES_FULL
 ld bc,sprt_end-PS_TOP	; preserve snake helpers after the sprite table
 ELSE
 ld bc,0x0200
 ENDIF
		ld e,0
		call memfill
		ld hl,0x7000		; ОЗУ игры
		ld	bc,0x0400
		ld	e,0
		call	memfill
		ld hl,VNT
		ld bc,0x8000-VNT
		ld	e,0
		call	memfill
		IFDEF STRICT
		ld sp,0
		ELSE
		ld sp,0xE000
		ENDIF
		ld	hl,0			; (прерывания запрещены)
		IFDEF STRICT
		ld b,0
		ELSE
		ld b,0xC0
		ENDIF
bclr:
 IFNDEF NES_STYLE
		REPT 64
		push	hl
		ENDR
		dec	b
		jp nz,bclr
 ENDIF
		ld sp,0x0038
		call	vi_off			; ВИ53 молчит, каналы SN — тоже (TURN_OFF_SOUND оригинала)
		call	snd_off
		ld	de,ps_boot_source
		ld	hl,TILE_IMAGES
		ld	bc,ps_boot_source_end-ps_boot_source
		call	copy_de_hl
		call	mask_keys_init
		call	trim_build
		IFNDEF STRICT
		INCLUDE "gen/music_reloc_early.asm"
		ENDIF
		call joe_load
 IFDEF NES_FULL
 ld de,raw_base_source
 ld hl,raw_base
 ld bc,256
 call copy_de_hl
 ENDIF
 IFNDEF NES_FULL
		call	ps_build		; готовые сдвиги кадров врагов
 ENDIF
		IFDEF STRICT
		call lv_init
		ENDIF
		ld	a,1
		ld	(kb_req),a
		call	game_init
 IFDEF NES_FULL
 ; Fire may already be held when the first keyboard IRQ runs.
 ld de,nt_motion_source
 ld hl,nt_jump_curve
 ld bc,nt_motion_source_end-nt_motion_source
 call copy_de_hl
 ENDIF
		ld	sp,GSTACK
		ei
		jp	game_start		; меню и начало уровня (level.asm)

; copy_de_hl: (HL) <- (DE), BC байт
 IFNDEF STRICT
 ASSERT $ <= 0x01E0
 ORG 0x01E0
 ENDIF
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
		IFDEF NES_FULL
		xor a
		out (0x00),a             ; end the footstep pulse at the next frame
		ENDIF
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
 IFDEF NES_FULL
 ld a,l
 and 3
 call z,nt_bonus_tick
 ENDIF
		IFNDEF	STRICT
		call nes_tick
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
		ld	a,(crit_pend)
		or	a
		IFNDEF STRICT
 push af
 call nes_poll
 pop af
 ENDIF
		call z,disp_prep
 ld a,1
 ld (jn_wait),a
fw2:
 IFNDEF STRICT
 call nes_legacy_step
 ENDIF
fw_event:
		ld	a,(nmi_pend)
		or	a
		jp	z,fw2
 IFNDEF STRICT
 ; Refill after a frame event, when IRQ has consumed a slot. The initial
 ; fill and rendering safe points still cover long work outside this wait.
 call nes_poll
 ENDIF
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
 IFDEF NES_FULL
 jp joy_merge
 ELSE
		ret
 ENDIF

		INCLUDE	"map.asm"
L_9156:		INCLUDE	"tiles.asm"
L_AEA7:		INCLUDE	"block.asm"
 IFDEF NES_FULL
unit_trap equ 0x0030         ; tests stop before fetching this unused RST vector
 ELSE
unit_trap: jp unit_trap
 ENDIF
 IFNDEF NES_FULL
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
 ENDIF
		INCLUDE	"level.asm"
 IFDEF NES_FULL
 INCLUDE "drawroom_nes.asm"
 ELSE
		INCLUDE "drawroom.asm"
 ENDIF
		INCLUDE	"screen.asm"
 IFDEF NES_FULL
 INCLUDE "sound_nes.asm"
 ELSE
 INCLUDE "sound.asm"
 ENDIF
		INCLUDE	"frame.asm"
		INCLUDE	"enemy.asm"
		INCLUDE	"collide.asm"
		INCLUDE	"nes_hit.asm"		; столкновения как NES
		INCLUDE	"hero.asm"
		INCLUDE	"main.asm"
		INCLUDE	"display.asm"
		INCLUDE	"sprites.asm"
 IFDEF NES_FULL
 INCLUDE "nes_pacing.asm"
 ENDIF
		INCLUDE "joe.asm"
		INCLUDE	"render.asm"
		INCLUDE	"cell.asm"
		INCLUDE	"../vec/util.asm"
 IFNDEF NES_STYLE
		INCLUDE	"../vec/gen/pal.asm"
 ENDIF
 IFDEF NES_FULL
 INCLUDE "gen/cart_full.asm"
 INCLUDE "nes_physics_data.asm"
 INCLUDE "nes_title_restore.asm"
 INCLUDE "gen/rooms_full.asm"
 ELSE
 INCLUDE "gen/cart.asm"
 ENDIF

ex_bb:		ds	4			; общая рамка отложенных клеток
lv_tile:	ds	LV_N			; живые клетки: тайл корзины
lv_beg:		ds	LV_N+1			; начало корзины в live_list (+ всего)
lv_pos:		ds	LV_N			; счётчики/позиции при раскладке
lv_idx		equ	0xF400			; тайл -> корзина (FF — не живой); бывший кэш тайлов в невидимой плоскости
 IFDEF NES_FULL
 INCLUDE "gen/video_full.asm"
 ELSE
 INCLUDE "gen/video.asm"
 ENDIF
		INCLUDE	"vars.asm"
ps_idx		equ	0x7F00			; 64 байта; выше остаются 64 байта стека IRQ
ps_tab:		ds	2*PS_SHIFTS*PS_N
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
 IFDEF NES_FULL
joe_high_free_end equ VNT-0x65 ; permanent treasure motion and chain catch helpers
sprite_table_free_end equ 0x6780
 ELSE
joe_high_free_end equ 0x7B00
sprite_table_free_end equ 0x6800
 ENDIF
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
dlist:		ds	2*DL_MAX		; список изменённых клеток (адреса в VNT)
		INCLUDE	"nes_column.asm"
		ASSERT	$ <= 0x6900
 IFDEF STRICT
PS_MORE equ video_raw_end
 ELSE
 IFDEF NES_FULL
PS_MORE equ nes_style_tail_end
 ELSE
PS_MORE equ joe_latch_end
 ENDIF
 ENDIF
;		; после исходных полос — готовые сдвиги
		ASSERT	PS_MORE < 0x7000
		INCLUDE	"gen/spat_nes.asm"			; ORG VSPR — шаблоны спрайтов прямо в образе

		INCLUDE "gen/joe_nes.asm"
		INCLUDE "gen/joe_mirror.asm"
 IFDEF NES_FULL
 INCLUDE "nes_terrain.asm"
 ENDIF
sprite_sources_end:
		INCLUDE "joe_attrs.asm"
 IFDEF NES_FULL
 ASSERT joe_attr_end <= joe_high_free_end
 ENDIF
		ASSERT $ <= 0x7B00
 INCLUDE "gen/joe_nibble.asm"
		INCLUDE "joe_bands.asm"
 INCLUDE "joe_latch.asm"
		IFDEF NES_FULL
		INCLUDE "nes_chain_exit.asm"
		INCLUDE "nes_snake_aux.asm"
		INCLUDE "nes_snake.asm"
		ENDIF

		INCLUDE "gen/logic.asm"

		IFDEF STRICT
		SAVEBIN	"../../build/native_strict/monty.bin", 0, VSPR+0x0800
		ELSE
		INCLUDE "gen/music.asm"
		IFDEF NES_FULL
		INCLUDE "nes_platform.asm"
		ENDIF
		INCLUDE "nes_sound.asm"
		INCLUDE "nes_boot.asm"
		INCLUDE "nes_alloc.asm"
 IFDEF NES_ENEMY_SEEDS
 INCLUDE "nes_enemy_seeds.asm"
 ENDIF
		INCLUDE "nes_idle.asm"
		IFDEF NES_FULL
		INCLUDE "nes_chain_descent.asm"
		ENDIF
		ASSERT copy_de_hl >= 0x01E0
 IFDEF NES_STYLE
 INCLUDE "gen/title.asm"
 IFDEF NES_FULL
 INCLUDE "gen/font_nes_extra.asm"
 INCLUDE "nes_footstep.asm"
 INCLUDE "nes_colors.asm"
 IFDEF NES_STABLE_COLORS
 INCLUDE "nes_object_colors.asm"
 INCLUDE "nes_score.asm"
 INCLUDE "nes_landing_save.asm"
 INCLUDE "nes_steps.asm"
 INCLUDE "joe_cache.asm"
 ENDIF
 ENDIF
 ENDIF
		IFDEF NES_FULL
		SAVEBIN "../../build/native/monty.bin", 0, 0xFEC0
		ELSE
		SAVEBIN "../../build/native/monty.bin", 0, 0xF950
		ENDIF
		ENDIF
