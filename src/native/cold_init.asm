; One-time initialization; warm restart never calls these routines.
game_init:	ld	hl,0x7000
		ld	de,ram0_pk
		call	unpack
		ld	hl,room_colors
		ld	de,col0
		ld	bc,32
		call	copy_de_hl
		ld	a,1
		ld	(video_enabled),a
		ret
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

ram0_pk:	INCBIN	"../../build/native/ram0.pk"
