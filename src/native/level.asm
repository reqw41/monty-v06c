; Начало игры: меню (уровень — клавиши 1, 2, 3), затем начало уровня как у оригинала (A59D). ОЗУ игры, цвета
; и регистры — состояние оригинала на входе в A59D (tools/vsnap.js: ram0, vram0, vreg0; ОЗУ — сжатым,
; tools/pack.py); таблицу имён оригинал перед этим очищает, комнату и строку состояния рисует A067.
; game_init: ОЗУ игры, цвета, регистры (до установки стека игры: ОЗУ включает его область)
game_init:	ld	hl,0x7000
		ld	de,ram0_pk
		call	unpack
		ld	hl,VCOL
		ld	de,col0
		ld	bc,32
		call	copy_de_hl
		ld	a,1
		ld	(video_enabled),a
		ret
; game_start: стартовая комната уровня 1 с Джо, поверх — надпись выбора уровня (клавиши 1, 2, 3; звук молчит);
; выбран — надпись стирается, комната заново для выбранного уровня (от него зависят предметы и строка
; состояния), дальше игра
MENU_POS	equ	0x01E5			; строка 15, столбец 5 — как у оригинала
game_start:	ld	a,1
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
gs2:
L_A59D:		ld	a,b			; (метка — для стендов: выбор сделан)
		ld	(0x71A6),a
		ld	hl,VNT+MENU_POS		; надпись — стереть: её клетки — заново из карты
		ld	b,MENU_LEN
gs3:		call	dl_add
		inc	hl
		dec	b
		jp	nz,gs3
		xor	a			; состояние героя — как до первого начала (8E7E запоминает его для возрождения)
		ld	(0x7079),a
		call	a59d
		jp	mn9			; A5CA: ждать кадра, дальше главный цикл
; a59d (A59D): начало уровня
a59d:		ld	a,6
		ld	(0x7049),a
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
		ld	a,8
		ld	(0x71A8),a
		call	L_A067
		call	L_8E7E
		ld	a,5
		ld	(0x7079),a
		ret

; unpack: DE = сжатое (tools/pack.py), HL = куда. B портится
unpack:		ld	a,(de)
		inc	de
		cp	0xFF
		ret	z
		cp	0x80
		jp	nc,upk_r
		inc	a
		ld	b,a
upk_l:		ld	a,(de)
		ld	(hl),a
		inc	de
		inc	hl
		dec	b
		jp	nz,upk_l
		jp	unpack
upk_r:		and	0x7F
		add	a,2
		ld	b,a
		ld	a,(de)
		inc	de
upk_s:		ld	(hl),a
		inc	hl
		dec	b
		jp	nz,upk_s
		jp	unpack

menu_txt:	db	"SELECT LEVEL   1, 2, 3.",0	; текст оригинала (8293)
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
		add	a,0xE0
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
		inc	b
		dec	b
		jp	z,td2			; конец таблицы — пустой глиф (font_end)
		ld	de,8
		add	hl,de
		jp	td1
td2:		ex	de,hl
		ld	a,(txt_l)
		ld	l,a
		ld	a,(txt_h)
		ld	h,a
		ld	a,(txt_c)
		ld	c,a
		ld	b,3
td3:		ld	a,c			; плоскость: точки или пусто
		rlca
		ld	c,a
		push	de
		push	hl
		REPT	8
		ld	a,(de)
		jp	c,$+4
		xor	a
		ld	(hl),a
		inc	de
		dec	l
		ENDR
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
ram0_pk:	INCBIN	"../../build/native/ram0.pk"
