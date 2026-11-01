; Once-only best-fit allocator. Preserve short page tails for shorter masks.
; All state and code live in the tile arena until the first room is drawn.
np_best equ 0xE3F0
np_begin equ 0xE3F2
np_left equ 0xE3F4
	ORG 0xE700
nes_ps_alloc:
	ld c,a
	ld hl,0
	ld (np_best),hl
	ld a,255
	ld (np_left),a
	ld hl,nes_ps_pages
npa_next:
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	push hl
	ld a,(hl)
	sub e
	ld b,a
	inc hl
	ld a,(hl)
	sbc a,d
	jp c,npa_skip
	or a
	jp nz,npa_fit
	ld a,b
	cp c
	jp c,npa_skip
npa_fit:
	ld a,b
	sub c
	ld b,a
	ld a,(np_left)
	cp b
	jp c,npa_skip
	ld a,b
	ld (np_left),a
	pop hl
	push hl
	dec hl
	dec hl
	ld (np_best),hl
	ex de,hl
	ld (np_begin),hl
npa_skip:
	pop hl
	inc hl
	inc hl
	ld a,l
	cp nes_ps_pages_end&255
	jp nz,npa_next
	ld hl,(np_best)
	ld a,h
	or l
	ret z
	ld a,(hl)
	add a,c
	ld (hl),a
	inc hl
	ld a,(hl)
	adc a,0
	ld (hl),a
	ld hl,(np_begin)
	ret
 IFDEF NES_ENEMY_SEEDS
ENEMY_CACHE_FREE equ nes_seed_end
 ELSE
ENEMY_CACHE_FREE equ live_hi+LIVE_N
 ENDIF
nes_ps_pages:
	INCLUDE "gen/music_pages.asm"
nes_ps_pages_end:
	ASSERT nes_ps_pages/256 == nes_ps_pages_end/256
	ASSERT $ <= 0xE828
