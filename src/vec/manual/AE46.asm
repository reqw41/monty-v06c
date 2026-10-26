; AE46-AE4E: H,L := 0,(IX+1); D,E := 0,(IX+0) — IX в ячейке z_ix (флаги не меняются)
		ld	hl,(z_ix)
		ld	e,(hl)
		inc	hl
		ld	l,(hl)
		ld	h,0
		ld	d,h
