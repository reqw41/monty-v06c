; Цвета комнаты, палитра и вывод теневой таблицы имён в 3 плоскости (8000 — бит 2 индекса, A000 — бит 1,
; C000 — бит 0; E000 невидима: палитра Вектора парами). Поле MSX 256x192: строка Y -> младший байт 0DFh - Y.


 IFDEF NES_STYLE
pal_build:
 jp style_palette
 INCLUDE "style.asm"
 ELSE
; Original MSX palette allocation.
pal_build:
		ld	hl,used
		ld	bc,64			; used, repl, cmap, pal
		ld	e,0
		call	memfill
		ld	a,1
		ld	(used+1),a
		ld	(used+6),a
		ld	(used+11),a
		call	spr_ecolor		; цвет врагов комнаты — в палитре на индексе 4 (только плоскость 8000)
		ld	(spr_E),a
		ld	hl,used
		call	add_hl_a
		ld	(hl),1
		ld	de,NT			; группы тайлов, что есть в комнате -> tile_changed[0..31] (цвета — по группе)
		ld	h,tile_changed/256
pb1:		ld	a,(de)
		rrca
		rrca
		rrca
		and	0x1F
		ld	l,a
		ld	(hl),1
		inc	de
		ld	a,d
		cp	(NT+768)/256
		jp	nz,pb1
		ld	b,0
pb1b:		ld	l,b			; встретилась — её цвета точек и фона — видимые (tile_changed — снова 0)
		ld	h,tile_changed/256
		ld	a,(hl)
		or	a
		jp	z,pb1c
		ld	(hl),0
		ld	a,b
		add	a,a
		add	a,a
		add	a,a
		call	cell_colors		; D = цвет точек, E = цвет фона (0 -> 1)
		ld	hl,used
		ld	a,d
		call	add_hl_a
		ld	(hl),1
		ld	hl,used
		ld	a,e
		call	add_hl_a
		ld	(hl),1
pb1c:		inc	b
		ld	a,b
		cp	32
		jp	nz,pb1b
		ld	hl,repl			; repl[c] := c
		xor	a
pb2:		ld	(hl),a
		inc	hl
		inc	a
		cp	16
		jp	nz,pb2
pb3:		call	used_count		; пока больше 8 — слить ближайшую пару из видимых
		cp	7			; своих цветов у комнаты 6: 5 и 7 — копии цветов героя
		jp	c,pb6
		ld	hl,merge_pairs
pb4:		ld	a,(hl)
		cp	0xFF
		jp	z,pb6
		ld	d,a			; убираемый
		inc	hl
		ld	e,(hl)			; замена
		inc	hl
		push	hl
		ld	a,d			; цвета героя (6, 11) и врагов (spr_E — индекс 4) не сливать: иначе индекс 4
		cp	6			; никому не достаётся, в палитре там чёрный — враги невидимы
		jp	z,pb5
		cp	11
		jp	z,pb5
		ld	hl,spr_E
		cp	(hl)
		jp	z,pb5
		ld	hl,used
		ld	a,d
		call	add_hl_a
		ld	a,(hl)
		or	a
		jp	z,pb5
		push	hl
		ld	hl,used
		ld	a,e
		call	add_hl_a
		ld	a,(hl)
		pop	hl
		or	a
		jp	z,pb5
		ld	(hl),0			; used[d] := 0, repl[d] := e
		ld	hl,repl
		ld	a,d
		call	add_hl_a
		ld	(hl),e
		pop	hl
		jp	pb3
pb5:		pop	hl
		jp	pb4
pb6:		ld	c,0			; индексы видимым цветам по порядку; палитра парами
		ld	b,1
pb7:		ld	hl,used
		ld	a,b
		call	add_hl_a
		ld	a,(hl)
		or	a
		jp	z,pb8
		ld	a,(spr_E)		; цвет врагов — индекс 4 (плоскость 8000); героя: 11 — 1 и 5, 6 — 3 и 7 (бит
		cp	b			; плоскости 8000 цвет героя не меняет: герой пишется плоскостями A000, C000);
		ld	a,4			; остальные — 0, 2, 6 (лишние — в 6)
		jp	z,pb7b
		ld	a,b
		cp	11
		ld	a,1
		jp	z,pb7b
		ld	a,b
		cp	6
		ld	a,3
		jp	z,pb7b
pb7c:		ld	a,c
		cp	8
		jp	c,pb7e
		ld	a,6
		jp	pb7b
pb7e:		cp	1
		jp	z,pb7d
		cp	3
		jp	c,pb7a
		cp	6
		jp	z,pb7a
pb7d:		inc	c
		jp	pb7c
pb7a:		ld	a,c
		inc	c
pb7b:		push	bc
		ld	c,a
		ld	hl,cmap
		ld	a,b
		call	add_hl_a
		ld	(hl),c
		ld	hl,msx2vec
		ld	a,b
		call	add_hl_a
		ld	e,(hl)
		ld	hl,pal
		ld	a,c
		add	a,a
		call	add_hl_a
		ld	(hl),e
		inc	hl
		ld	(hl),e
		pop	bc
pb8:		inc	b
		ld	a,b
		cp	16
		jp	nz,pb7
		ld	b,1			; слитые: cmap[c] := cmap[конец цепочки repl]
pb9:		ld	d,b
pb10:		ld	hl,repl
		ld	a,d
		call	add_hl_a
		ld	a,(hl)
		cp	d
		jp	z,pb11
		ld	d,a
		jp	pb10
pb11:		ld	hl,cmap
		ld	a,d
		call	add_hl_a
		ld	e,(hl)
		ld	hl,cmap
		ld	a,b
		call	add_hl_a
		ld	(hl),e
		inc	b
		ld	a,b
		cp	16
		jp	nz,pb9
		ld	hl,(pal+8)		; индексы 5, 7 — цвет врагов (4): враг (плоскость 8000) над тайлами 1, 3 — поверх;
		ld	(pal+10),hl		; Джо рисуется тремя плоскостями (8000 под ним гасится) — 5, 7 у него не бывает
		ld	(pal+14),hl
 IFDEF NES_JOE_PALETTE
 call joe_palette
 ENDIF
		ld	a,(cmap+1)		; прозрачный 0 — цвет фона (R7 = 1)
		ld	(cmap+0),a
		ret

 ENDIF

; spr_ecolor: A = цвет врагов комнаты — первая видимая запись врага игры с цветом 15, 12 или 14 (14 — как 15; иначе 15)
 IFNDEF NES_STYLE
spr_ecolor:
		ld	hl,0x7300
		ld	b,SPR_MAX
sec1:		ld	a,(hl)
		cp	0xD0
		jp	z,sec9
		inc	hl
		inc	hl
		inc	hl
		ld	a,(hl)
		and	0x0F
		inc	hl
		cp	15
		ret	z
		cp	12
		ret	z
		cp	14			; серый — кадр мигания белого черепа: цвет врагов — белый
		jp	z,sec9
		dec	b
		jp	nz,sec1
sec9:		ld	a,15
		ret

used_count:	ld	hl,used
		ld	b,16
		xor	a
uc1:		add	a,(hl)
		inc	hl
		dec	b
		jp	nz,uc1
		ret

 ENDIF

 IFNDEF NES_STYLE
; cell_colors: A = тайл -> D = цвет точек, E = цвет фона (MSX, 0 -> 1) — только MSX-палитра
cell_colors:
		rrca
		rrca
		rrca
		and	0x1F
		ld	hl,room_colors
		call	add_hl_a
		ld	a,(hl)
		ld	e,a
		rrca
		rrca
		rrca
		rrca
		and	0x0F
		jp	nz,cc1
		inc	a
cc1:		ld	d,a
		ld	a,e
		and	0x0F
		jp	nz,cc2
		inc	a
cc2:		ld	e,a
		ret
 ENDIF

