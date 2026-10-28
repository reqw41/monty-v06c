; Once-only title/menu, in the tile arena before any room is built.
	ORG 0xE400
nes_menu:
	INCLUDE "gen/music_reloc_late.asm"
	ld hl,nes_m_ptr
	ld bc,32
	ld e,0
	call memfill
	ld a,64
	ld (nes_m1),a
	ld (nes_m2),a
	ld a,0xEC
	ld (nes_pitch_page),a
	ld hl,nes_title_order
	ld a,1
	call nes_select
	ld hl,nes_title_loop_order
	ld (nes_m_start),hl
	; A black title screen needs one visible text colour and its palette.
	ld hl,cmap
	ld bc,16
	ld e,0
	call memfill
	ld a,7
	ld (cmap+15),a
	ld hl,pal
	ld bc,16
	ld e,0
	call memfill
	IFDEF NES_STYLE
	ld de,title_palette
	ld hl,pal
	ld bc,16
	call copy_de_hl
	ENDIF
	ld a,NES_TITLE_CREDITS_INK
	ld (pal+14),a
	ld (pal+15),a
	ld a,1
	ld (pal_load),a
nm_wait:
	call nes_poll
	ld hl,menu_txt
	ld de,MENU_POS
	call txt_draw
	ld a,1
	ld (kb_req),a
	halt
	ld a,(kbmat+2)
	ld b,1
	rrca
	rrca
	jp c,gs2
	inc b
	rrca
	jp c,gs2
	inc b
	rrca
	jp nc,nm_wait
	jp gs2
nes_begin:
	push bc
	ld a,1
	ld (snd_busy),a
	xor a
	ld (nes_m_wait),a
	call vi_off
	IFDEF NES_STYLE
	ld hl,0x8000
	ld bc,0x6000
	ld e,0
	call memfill_f
	ENDIF
	call nes_queue_reset
	ld a,0xE8
	ld (nes_pitch_page),a
	ld de,nes_effect_source
	ld hl,0xEF00
	ld bc,nes_effect_source_end-nes_effect_source
	call copy_de_hl
	call lv_init
	ld a,(frames)
	ld (nes_last_frame),a
	xor a
	ld (snd_busy),a
	pop bc
	ret
nes_boot_end:
	ASSERT $ <= 0xE500
