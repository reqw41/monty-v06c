; Начало уровня. Пока — уровень 1 со снимка модели MSX на первой итерации (tools/vsnap.js): ОЗУ игры,
; таблица имён, цвета, регистры VDP; комната выводится целиком на первом выводе.
level_snap:
		ld	hl,0x7000
		ld	de,snap_ram
		ld	bc,0x0400
		call	copy_de_hl
		ld	hl,VNT
		ld	de,snap_nt
		ld	bc,0x0300
		call	copy_de_hl
		ld	hl,VCOL
		ld	de,snap_col
		ld	bc,32
		call	copy_de_hl
		ld	hl,vregs
		ld	de,snap_reg
		ld	bc,8
		call	copy_de_hl
		ld	a,8
		call	sat_copy
		ld	a,(vdirty)
		or	VD_NT
		ld	(vdirty),a
		ld	a,2
		ld	(nt_age),a
		ret
snap_ram:	INCBIN	"../../build/native/ram.bin"
snap_nt:	INCBIN	"../../build/native/vram.bin",0x1800,0x300
snap_col:	INCBIN	"../../build/native/vram.bin",0x2000,32
snap_reg:	INCBIN	"../../build/native/vreg.bin"
