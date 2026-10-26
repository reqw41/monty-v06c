; Montezuma's Revenge для Вектора-06Ц: сборка игры (docs/PORT_DESIGN.md).
;   python3 -I tools/mkvecdata.py && python3 -I tools/z2i.py && \
;   (cd src/vec && ../../tools/sjasmplus --nologo --i8080 --sym=../../build/vec/monty.sym game.asm)
; Память: 0000 векторы; 0100 код и данные; 7000-73FF ОЗУ игры (как у Coleco); 7400-7FFF виртуальная VRAM
; (VSPR, VNT, VSAT, VCOL); 8000-DFFF экран (3 плоскости); E000-FFFF банки шаблонов тайлов (невидимая плоскость).
		DEVICE	NOSLOT64K
VSPR		equ	0x7400			; шаблоны спрайтов (VDP 3800)
VNT		equ	0x7C00			; таблица имён (VDP 1800)
VSAT		equ	0x7F00			; атрибуты спрайтов (VDP 1B00)
VCOL		equ	0x7F80			; цвета (VDP 2000)
; невидимая плоскость E000-FFFF: банк шаблонов 0, различия банков 1, 2, 5, ячейки спрайтов
dslot		equ	0xE800			; тайл -> номер различия (FF — нет)
dstore		equ	0xE900			; различия: 24 байта на тайл (банки 1, 2, 5 по 8)
DMAX		equ	17			; тайлов с различием банков (E900-EB97)
tslot		equ	0xF300			; кэш изображений тайлов: тайл -> ячейка (FF — нет)
tcache		equ	0xF400			; ячейки по 24 байта (TC_N штук, до F87F)
SPR_SLOTS	equ	0xF900			; ячейки фона спрайтов (6 по 256, до FEFF)
NT		equ	VNT			; для render.asm
coltab		equ	VCOL

		ORG	0x0000
		di
		ld	sp,ISR_STACK
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
		ld	a,(nmi_pend)
		or	a
		jp	z,np9
		ld	a,(vregs+1)
		and	0x20
		jp	z,np9
		ld	a,(in_nmi)
		or	a
		jp	nz,np9
		push	bc
		push	de
		push	hl
		ld	hl,nmi_pend		; один кадр долга — один вызов обработчика
		di
		dec	(hl)
		ei
		call	nmi_run
		ld	a,(nmi_pend)		; долг погашен — вывод; отстаём — пропуск, но не больше 4 подряд
		or	a
		jp	z,np5
		ld	a,(np_skip)
		inc	a
		ld	(np_skip),a
		cp	4
		jp	c,np8
np5:		xor	a
		ld	(np_skip),a
		call	display
np8:		pop	hl
		pop	de
		pop	bc
np9:		pop	af
		ret

; nmi_now: разрешение прерывания VDP при ждущем кадре (WRITE_REGISTER) — обработчик сразу, все регистры целы
nmi_now:
		push	af
		push	bc
		push	de
		push	hl
		ld	a,(in_nmi)
		or	a
		call	z,nmi_run
		pop	hl
		pop	de
		pop	bc
		pop	af
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

; --- переменные платформы ---------------------------------------------------------------------------------
pvars:
frames:		ds	2
isr_sp:		ds	2
in_nmi:		ds	1
nmi_pend:	ds	1
np_waited:	ds	1
np_ontime:	ds	1
np_skip:	ds	1
vstat:		ds	1
fv_val:		ds	1
vm_bank:	ds	1
vb_val:		ds	1
vb_v:		ds	2
vb_t:		ds	1
vs_v:		ds	2
vdirty:		ds	1
nt_age:		ds	1
anim_ok:	ds	1
vregs:		ds	8
pal_load:	ds	1
tile_hi:	ds	1
kbmat:		ds	8
z_t:		ds	1
z_t2:		ds	1
z_ix:		ds	2
z_iy:		ds	2
z_af2:		ds	2
z_bc2:		ds	2
z_de2:		ds	2
z_hl2:		ds	2
ft_map:		ds	2
row_dirty:	ds	24
drew_any:	ds	1
dc_m:		ds	1
spr_last:	ds	4*SPR_MAX
col_shown:	ds	32
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
spr_n:		ds	1
spr_rec:	ds	SREC*SPR_MAX
sv_lo:		ds	1
sv_col:		ds	1
sp_px:		ds	1
sp_py:		ds	1
sp_rows:	ds	1
sp_col:		ds	1
sp_k:		ds	1
sp_cbits:	ds	1
st_rows:	ds	1
st_kind:	ds	1
sv_zc:		ds	1
sm_z0:		ds	1
sm_z1:		ds	1
sm_z2:		ds	1
cl_h:		ds	3
cl_m:		ds	3
cl_n:		ds	1
se_y:		ds	1
se_r0:		ds	1
se_r1:		ds	1
tr_z0:		ds	1
tr_z1:		ds	1
tr_z2:		ds	1
tr_line:	ds	1
tr_first:	ds	1
tr_last:	ds	1
sm_off:		ds	1
spr_trim:	ds	4*64
sp_y:		ds	1
sp_x:		ds	1
sp_name:	ds	1
sp_ci:		ds	1
sp_pat:		ds	2
sp_line:	ds	1
gx_op:		ds	1
gx_tab:		ds	1
gx_dst:		ds	2
gx_t:		ds	1
gx_buf:		ds	8
gx_out:		ds	8
gx_big:		ds	32
sn_latch:	ds	1
sn_chg:		ds	1
sn_per:		ds	8
sn_att:		ds	4
pvars_end:
		ALIGN	256
NTS:		ds	768
pat_flag:	ds	256
anim_flag:	ds	256
col_flag:	ds	256
cmodes:		ds	256
tc_next:	ds	1
dc_sp:		ds	2
dc_hl:		ds	2
LIVE_MAX	equ	120
		ALIGN	256
live_list:	ds	2*LIVE_MAX+2
		ALIGN	256
sm_or:		ds	48
tabs_end:
		ds	128
ISR_STACK:
code_end:
		ASSERT	code_end <= 0x7000

		SAVEBIN	"../../build/vec/monty.bin", 0, 0x7000
