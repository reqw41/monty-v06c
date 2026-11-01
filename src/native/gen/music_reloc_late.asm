	ld de,nes_reloc_boot
	ld hl,256
	ld bc,224
	call copy_de_hl
	ld de,nes_reloc_vectors
	ld hl,8
	ld bc,42
	call copy_de_hl
