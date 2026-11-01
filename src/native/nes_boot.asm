; Once-only title/menu, in the tile arena before any room is built.
	ORG 0xE400
nes_menu:
 xor a
 ld (video_enabled),a       ; title colours cannot be changed by gameplay
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
	ld a,NES_TITLE_TEXT_SLOT
	ld (cmap+15),a
	ld hl,pal
	ld bc,16
	ld e,0
	call memfill
	IFDEF NES_STYLE
	ld de,title_warm_palette
	ld hl,pal
	ld bc,16
	call copy_de_hl
	ENDIF
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
 IFDEF NES_FULL
 call cheat_menu_keys
 jp nc,nm_wait
 ELSE
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
 ENDIF
	jp gs2
nes_begin:
	call title_animate
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
	ld de,nes_platform_source
	ld hl,style_pal
	ld bc,nes_platform_source_end-nes_platform_source
	call copy_de_hl
	ld hl,nes_platform_source
	ld bc,nes_platform_source_end-nes_platform_source
	ld e,0
	call memfill
	; The extra cache ranges overlap discarded title music. Build only after
	; its playback has stopped; warm restarts keep these masks in place.
 IFDEF NES_ENEMY_SEEDS
 ld de,nes_seed_source
 ld hl,nes_seed_masks
 ld bc,nes_seed_end-nes_seed_masks
 call copy_de_hl
 ENDIF
	call ps_build
	call lv_init
	ld a,(frames)
	ld (nes_last_frame),a
	xor a
	ld (snd_busy),a
	pop bc
	ret
nes_boot_end:
	ASSERT $ <= 0xE500
