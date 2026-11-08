; Начало игры: меню (уровень — клавиши 1, 2, 3), затем начало уровня как у оригинала (A59D). ОЗУ игры, цвета
; и регистры — состояние оригинала на входе в A59D (tools/vsnap.js: ram0, vram0, vreg0; ОЗУ — сжатым,
; tools/pack.py); таблицу имён оригинал перед этим очищает, комнату и строку состояния рисует A067.
; Одноразовые game_init/unpack находятся в загрузочном оверлее sprites.asm.
; game_start: обычная сборка — nes_menu (музыка и выбор 1-3 до построения тайлов);
; STRICT — стартовая комната уровня 1 с Джо, поверх — выбор уровня без музыки;
; выбран — надпись стирается, комната заново для выбранного уровня (от него зависят предметы и строка
; состояния), дальше игра
 IFDEF NES_STYLE
MENU_POS equ 0x0245
 ELSE
MENU_POS equ 0x01E5
 ENDIF
;			; строка 15, столбец 5 — как у оригинала
game_start:
		IFNDEF STRICT
		jp nes_menu
		ELSE
		ld	a,1
		ld	(0x71A6),a
		call	a59d
		call	snd_quiet
gs1:		ld	a,1
		ld	(kb_req),a
		call	frame_wait
		ld	hl,menu_txt		; надпись — прямо на экран (каждый кадр: комната рисуется в первых кадрах)
		ld	de,MENU_POS
		call	txt_draw
		ld	a,(kbmat+2)		; «1» .. «3» — биты 1..3
		ld	b,1
		rrca
		rrca
		jp	c,gs2
		inc	b
		rrca
		jp	c,gs2
		inc	b
		rrca
		jp	nc,gs1
		ENDIF
gs2:
		IFNDEF STRICT
		call nes_begin
		ENDIF
L_A59D:		ld	a,b			; (метка — для стендов: выбор сделан)
		ld	(0x71A6),a
 IFNDEF NES_FULL
		ld	hl,VNT+MENU_POS		; надпись — стереть: её клетки — заново из карты
		ld	b,MENU_LEN
gs3:		call	dl_add
		inc	hl
		dec	b
		jp	nz,gs3
 ENDIF
		xor	a			; состояние героя — как до первого начала (8E7E запоминает его для возрождения)
		ld	(0x7079),a
		call	a59d
		IFNDEF STRICT
		call nes_pyramid
		ENDIF
		jp	mn9			; A5CA: ждать кадра, дальше главный цикл
 IFDEF NES_FULL
; Cold bootstrap sources are reused by room tiles and sprite shifts. After
; GAME OVER reset game state in place, keeping the installed video/audio code.
warm_restart:
 push bc                    ; 7000..71FF уже очищены в title_resume
 ld a,2
 ld (0x7012),a
 ld (0x7068),a
 ld (0x7073),a
 ld (0x7074),a
 ld a,6
 ld (0x7303),a
 ld a,11
 ld (0x7307),a
 pop bc
 ei
 jp L_A59D
 ENDIF
; a59d (A59D): начало уровня
a59d:		ld	a,6
		ld	(0x7049),a
a59d_keep_lives:
		ld	hl,0x705F
		ld	a,(hl)
		or	4
		ld	(hl),a
		call	L_AC06
		ld	a,0xFF
		ld	(0x70A9),a
		ld	a,1
		ld	(0x70AD),a
		ld	hl,1
		ld	(0x72E0),hl
 IFDEF NES_FULL
 xor a
 ld (nes_amulet_ticks),a
 ld (nes_amulet_ticks+1),a
 ld (0x71A7),a
 ld (0x7076),a
 ld (0x7077),a
 ld a,10
 ld (0x71A8),a
 ld a,44
 ld (0x7300),a
 add a,3
 ld (0x7304),a
 ld a,116
 ld (0x7301),a
 ld (0x7305),a
 ELSE
		ld a,8
		ld (0x71A8),a
 ENDIF
		call L_A067
 IFDEF NES_FULL
 call L_9156               ; publish the rope tile before the first Joe frame
 ENDIF
		call	L_8E7E
 IFDEF NES_FULL
 ld a,4                    ; begin attached to the opening rope
 ELSE
		ld	a,5
 ENDIF
		ld	(0x7079),a
		ret

 IFNDEF NES_FULL
menu_txt: db "SELECT LEVEL   1, 2, 3.",0
 ENDIF
MENU_LEN	equ	23

; txt_draw: HL = текст (0 — конец), DE = клетка (32 * строка + столбец) — прямо в плоскости экрана шрифтом
; font_tab, цветом MSX 15 (cmap) на чёрном; неизвестные знаки и пробел — пусто
txt_draw:	ld	a,(cmap+15)
		rrca				; цвет: бит 2 -> 8000, 1 -> A000, 0 -> C000 (биты 7..5 после сдвига)
		rrca
		rrca
		ld	(txt_c),a
		ld	a,e			; экран: L = 0DFh - 8 * строка, H = 80h + столбец
		and	0xE0
		rlca
		rlca
		rlca
		ld	b,a
		ld	a,d
		add	a,a
		add	a,a
		add	a,a
		or	b
		add	a,a
		add	a,a
		add	a,a
		cpl
		add a,(SCREEN_TOP+1)&255
		ld	(txt_l),a
		ld	a,e
		and	0x1F
		add	a,0x80
		ld	(txt_h),a
td0:		ld	a,(hl)
		or	a
		ret	z
		inc	hl
		push	hl
		ld	hl,font_tab		; глиф -> DE (нет — пусто)
td1:		ld	b,(hl)
		inc	hl
		cp	b
		jp	z,td2
		IFDEF NES_FULL
		inc b
		jp z,td_extra
		dec b
		ELSE
		inc	b
		dec	b
		ENDIF
		jp	z,td2			; конец таблицы — пустой глиф (font_end)
		ld	de,8
		add	hl,de
		jp	td1
		IFDEF NES_FULL
td_extra:
		ld hl,font_extra
		jp td1
		ENDIF
td2:		ex	de,hl
		ld	hl,(txt_l)
		ld	a,(txt_c)
		ld	c,a
		ld	b,3
td3:		ld	a,c			; плоскость: точки или пусто
		rlca
		ld	c,a
		push	de
		push	hl
		IFDEF NES_FULL
; GAME OVER is cold. DCR preserves the plane-selection carry, including
; the zero plane after XOR A; keep the outer plane counter and ink in BC.
		push bc
		ld b,8
td_row:
		ld a,(de)
		jp c,$+4
		xor a
		ld (hl),a
		inc de
		dec l
		dec b
		jp nz,td_row
		pop bc
		ELSE
		REPT	8
		ld	a,(de)
		jp	c,$+4
		xor	a
		ld	(hl),a
		inc	de
		dec	l
		ENDR
		ENDIF
		pop	hl
		pop	de
		ld	a,h
		add	a,0x20
		ld	h,a
		dec	b
		jp	nz,td3
		ld	hl,txt_h
		inc	(hl)
		pop	hl
		jp	td0
 IFDEF NES_STYLE
 INCLUDE "gen/font_nes.asm"
 ELSE
; шрифт оригинала (LOAD_ASCII OS7, снят с экрана меню MSX): знак, 8 строк
font_tab:	db	"S",0x70,0x88,0x80,0x70,0x08,0x88,0x70,0x00
		db	"E",0xF8,0x80,0x80,0xF0,0x80,0x80,0xF8,0x00
		db	"L",0x80,0x80,0x80,0x80,0x80,0x80,0xF8,0x00
		db	"C",0x70,0x88,0x80,0x80,0x80,0x88,0x70,0x00
		db	"T",0xF8,0x20,0x20,0x20,0x20,0x20,0x20,0x00
		db	"V",0x88,0x88,0x88,0x88,0x88,0x50,0x20,0x00
		db	"1",0x20,0x60,0x20,0x20,0x20,0x20,0x70,0x00
		db	"2",0x70,0x88,0x08,0x30,0x40,0x80,0xF8,0x00
		db	"3",0xF8,0x08,0x10,0x30,0x08,0x88,0x70,0x00
		db	",",0x00,0x00,0x00,0x00,0x20,0x20,0x40,0x00
		db	".",0x00,0x00,0x00,0x00,0x00,0x00,0x20,0x00
		db	0,0,0,0,0,0,0,0,0	; конец: пустой глиф
 ENDIF
