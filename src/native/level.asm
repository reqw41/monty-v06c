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
		ld	hl,vregs
		ld	de,reg0
		ld	bc,8
		jp	copy_de_hl
; game_start: стартовая комната уровня 1 с Джо, поверх — надпись выбора уровня (клавиши 1, 2, 3; звук молчит);
; выбран — надпись стирается, комната заново для выбранного уровня (от него зависят предметы и строка
; состояния), дальше игра
MENU_POS	equ	0x01E5			; строка 15, столбец 5 — как у оригинала
game_start:	ld	a,1
		ld	(0x71A6),a
		call	a59d
		call	snd_quiet
		ld	hl,menu_sav		; клетки под надписью
		ld	de,MENU_POS
		ld	c,23
		call	nt_get
		ld	hl,menu_txt
		call	nt_put
gs1:		ld	a,1
		ld	(kb_req),a
		call	frame_wait
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
		ld	hl,menu_sav		; надпись — стереть
		ld	de,MENU_POS
		ld	c,23
		call	nt_put
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

; к этому времени пробел, знаки и часть цифр — уже графика игры, цифры — цветом этажа: пустое — тайл 0,
; уровни — римскими (буквы белые)
menu_txt:	db	"SELECT",0,"LEVEL",0,0,"I",0,"II",0,"III",0
		ASSERT	$ - menu_txt == 23
ram0_pk:	INCBIN	"../../build/native/ram0.pk"
pat0_pk:	INCBIN	"../../build/native/pat0.pk"
reg0:		INCBIN	"../../build/native/vreg0.bin"
