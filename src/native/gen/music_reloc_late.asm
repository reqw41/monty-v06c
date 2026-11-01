	ld de,nes_reloc_boot
	ld hl,256
	ld bc,144
	call copy_de_hl
