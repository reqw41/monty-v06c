; The 297-room audit uses at most 87 tile images; the next 24 bytes are sound.
	ASSERT TILE_IMAGES+24*TILE_CAP <= 0xE828
	ORG 0xE828
nes_idle_check:
	ld a,(nes_m_wait)
	ld hl,nes_p_wait
	or (hl)
	ld hl,nes_n_wait
	or (hl)
	ret nz
	inc a
	ld (nes_q_idle),a
	ret
nes_q_idle:
	db 0
	ASSERT $ <= 0xE840
