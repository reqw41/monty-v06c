; Native NES/VI53 output. All public entries except nes_tick are main-thread
; routines. They use snd_busy instead of DI; IRQ can skip a frame during setup.
; MSX effect RAM and its priority/termination routines remain in sound.asm.
nes_m_ptr equ 0xEBE0
nes_m_order equ 0xEBE2
nes_m_start equ 0xEBE4
nes_m_wait equ 0xEBE6
nes_loop equ 0xEBE7
nes_pitch_page equ 0xEBE8
nes_p_ptr equ 0xEBE9
nes_p_wait equ 0xEBEB
nes_n_ptr equ 0xEBEC
nes_n_wait equ 0xEBEE
nes_pole equ 0xEBEF
nes_m1 equ 0xEBF0
nes_m2 equ 0xEBF1
nes_pole_div equ 0xEBF2
nes_noise_div equ 0xEBF4
nes_last_frame equ 0xEBF6

	ORG 0xF600
nes_prepare_core:
	ld hl,nes_m_wait
	ld a,(hl)
	or a
	jp z,nt_fx
	dec (hl)
	jp nz,nt_fx
	ld hl,(nes_m_ptr)
	ex de,hl
nt_record:
	ld a,(de)
	or a
	jp z,nt_phrase
	inc de
	ld b,a
	rrca
	rrca
	rrca
	and 31
	ld (nes_m_wait),a
	ld a,b
	rrca
	ld b,a
	jp nc,nt_1
	ld a,(de)
	inc de
	call nes_out0
nt_1:
	ld a,b
	rrca
	ld b,a
	jp nc,nt_2
	ld a,(de)
	inc de
	ld (nes_m1),a
	ld c,a
	ld a,(nes_p_wait)
	or a
	ld a,c
	call z,nes_out1
nt_2:
	ld a,b
	rrca
	jp nc,nt_save
	ld a,(de)
	inc de
	ld (nes_m2),a
	ld c,a
	ld a,(nes_n_wait)
	or a
	ld a,c
	call z,nes_out2
nt_save:
	ld a,(nes_m_wait)
	or a
	jp z,nt_record		; zero-delay events belong to this same music tick
	ex de,hl
	ld (nes_m_ptr),hl
nt_fx:
	ld a,(nes_pole)
	or a
	jp z,nt_pulse
	ld hl,(nes_pole_div)
	call nes_raw1
	jp nt_noise
nt_pulse:
	ld hl,nes_p_wait
	ld a,(hl)
	or a
	jp z,nt_noise
	dec (hl)
	jp nz,nt_noise
	ld hl,(nes_p_ptr)
	ld a,(hl)
	or a
	jp z,nt_p_end
	ld (nes_p_wait),a
	inc hl
	ld a,(hl)
	inc hl
	ld c,(hl)
	inc hl
	ld (nes_p_ptr),hl
	ld l,a
	ld h,c
	call nes_raw1
	jp nt_noise
nt_p_end:
	ld a,(nes_m1)
	call nes_out1
nt_noise:
	ld hl,nes_n_wait
	ld a,(hl)
	or a
	ret z
	dec (hl)
	jp nz,nt_click
	ld hl,(nes_n_ptr)
	ld a,(hl)
	or a
	jp z,nt_n_end
	ld (nes_n_wait),a
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (nes_n_ptr),hl
	ex de,hl
	ld (nes_noise_div),hl
nt_click:
	ld hl,(nes_noise_div)
	ld a,h
	or l
	ret z
	ld (nes_shadow+8),hl
	ld hl,0xB003
	ld (nes_shadow+10),hl
	ret
nt_n_end:
	ld a,(nes_m2)
	jp nes_out2
nt_phrase:
	ld hl,(nes_m_order)
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (nes_m_order),hl
	ld a,d
	or e
	jp nz,nt_record
	ld a,(nes_loop)
	or a
	jp z,nt_music_end
	ld hl,(nes_m_start)
	ld (nes_m_order),hl
	jp nt_phrase
nt_music_end:
	ld a,64
	ld (nes_m1),a
	ld (nes_m2),a
	call nes_out0
	ld a,64
	call nes_out1
	ld a,64
	call nes_out2
	jp nt_fx

; Look up actual divisors and prepare the timer control/CPU flag words.
; Zero means mode-0 silence. Only the queue consumer writes timer ports.
nes_pitch:
	ld l,a
	ld a,(nes_pitch_page)
	ld h,a
	ld a,(hl)
	inc l
	ld h,(hl)
	ld l,a
	ret
nes_out0:
	call nes_pitch
nes_raw0:
	ld (nes_shadow+0),hl
	ld a,h
	or l
	ld hl,12290
	jp z,ns_store0
	ld hl,13827
ns_store0:
	ld (nes_shadow+2),hl
	ret

nes_out1:
	call nes_pitch
nes_raw1:
	ld (nes_shadow+4),hl
	ld a,h
	or l
	ld hl,28674
	jp z,ns_store1
	ld hl,30211
ns_store1:
	ld (nes_shadow+6),hl
	ret

nes_out2:
	call nes_pitch
nes_raw2:
	ld (nes_shadow+8),hl
	ld a,h
	or l
	ld hl,45058
	jp z,ns_store2
	ld hl,46595
ns_store2:
	ld (nes_shadow+10),hl
	ret

; HL = phrase order; A = 1 for title loop, 0 for a one-shot cue.
nes_select:
	ld (nes_loop),a
	ld a,1
	ld (snd_busy),a
	ld (nes_m_start),hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (nes_m_order),hl
	ex de,hl
	ld (nes_m_ptr),hl
	ld (nes_m_wait),a
	call nes_queue_reset
	call nes_poll
	xor a
	ld (snd_busy),a
	ret
nes_pyramid:
	push hl
	ld hl,nes_pyramid_order
	jp nes_cue
nes_treasure:
	push hl
	ld hl,nes_treasure_order
nes_cue:
	push af
	push bc
	push de
	ld a,1		; vm fix: in-game themes loop too
	call nes_select
	pop de
	pop bc
	pop af
	pop hl
	ret

; B = accepted MSX effect. L_AC1A already saves all caller registers.
nes_event_ready:
	ld a,b
	cp 6
	jp z,nes_pole_start
	cp 1
	ret z
	cp 9
	ret z
	ld hl,nes_effect_map
	add a,a
	call add_hl_a
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld a,b
	cp 5
	jp z,ne_noise
	cp 4
	jp z,ne_noise
	xor a
	ld (nes_pole),a
	ex de,hl
	ld (nes_p_ptr),hl
	ld a,1
	ld (nes_p_wait),a
	ret
ne_noise:
	ld a,(nes_pole)
	or a
	call nz,nes_pole_stop
	ex de,hl
	ld (nes_n_ptr),hl
	ld a,1
	ld (nes_n_wait),a
	ret
nes_effect_map:
	dw nes_sfx_life,0,nes_sfx_pickup,nes_sfx_sword,nes_sfx_land
	dw nes_sfx_death,nes_sfx_landing,nes_sfx_jump,nes_sfx_door

; Preserve the MSX state machine outside the DI portion of the IRQ. Elapsed
; physical frames, rather than game steps, retain its existing 6/5 cadence.
nes_legacy_step:
	ld a,(frames)
	ld hl,nes_last_frame
	cp (hl)
	ret z
	inc (hl)
	ld a,(snd_acc)
	add a,6
nl_next:
	cp 5
	jp c,nl_done
	sub 5
	push af
	call L_AC6D
	pop af
	jp nl_next
nl_done:
	ld (snd_acc),a
	call nes_update_pole
	jp nes_legacy_step
nes_pole_start:
	ld a,1
	ld (nes_pole),a
	dec a
	dec a
	ld (nes_p_wait),a
	jp nes_calc_pole
nes_update_pole:
	ld a,(nes_pole)
	or a
	ret z
	ld a,(0x7079)
	cp 5
	jp z,nes_calc_pole
	cp 7
	jp nz,nes_pole_stop
nes_calc_pole:
	ld a,(0x7300)
	ld e,a
	ld d,1
	inc de
	ld h,d
	ld l,e
	add hl,hl
	add hl,de
	add hl,hl
	add hl,hl
	add hl,de
	ld a,d
	or a
	rra
	ld d,a
	ld a,e
	rra
	ld e,a
	add hl,de
	ld a,(0x7300)
	inc a
	; Clamp the offscreen Y=255 endpoint; gameplay Y is below 224.
	jp nz,np_y
	dec a
np_y:
	rrca
	rrca
	rrca
	rrca
	and 15
	ld e,a
	or a
	rra
	add a,e
	add a,24
	ld e,a
	ld a,l
	sub e
	ld l,a
	ld a,h
	sbc a,0
	ld h,a
	ld (nes_pole_div),hl
	ret
nes_poll:
	ld a,(nes_q_idle)
	or a
	ret nz
	ld a,(nes_q_count)
	cp 4
	ret nc
	ld a,0x42
	ld (nes_shadow+2),a
	ld (nes_shadow+6),a
	ld (nes_shadow+10),a
	call nes_prepare_core
	ld de,nes_shadow
	ld hl,(nes_q_write)
	ld b,6
np_copy:
	REPT 2
	ld a,(de)
	ld (hl),a
	inc de
	inc hl
	ENDR
	dec b
	jp nz,np_copy
	ld a,l
	cp nes_queue_end&255
	jp nz,nq_published
	ld hl,nes_queue
nq_published:
	ld (nes_q_write),hl
	ld hl,nes_q_count
	inc (hl)
	call nes_idle_check
	jp nes_poll

nes_queue_reset:
	ld hl,nes_queue
	ld (nes_q_read),hl
	ld (nes_q_write),hl
	xor a
	ld (nes_q_count),a
	ld (nes_q_idle),a
	ld hl,nes_shadow
	ld b,12
nqr_clear:
	ld (hl),a
	inc hl
	dec b
	jp nz,nqr_clear
	ret

nes_player_end:
