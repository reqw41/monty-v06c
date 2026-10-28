nes_event:
	xor a
	ld (nes_q_idle),a
	jp nes_event_ready
; Four prepared 50 Hz frames. The producer runs with interrupts enabled;
; publishing/consuming a slot uses one atomic INR/DCR, never DI. Timer output
; alone runs in the IRQ. The queue bridges long rendering work in the main loop.
; Reuse the retired SN-output scratch bytes in the normal build.
nes_q_read equ vi_dv
nes_q_write equ vi_dv+2
nes_q_count equ vi_dv+4
nes_q_sp equ vi_dv+5
nes_shadow: ds 12
nes_queue: ds 48
nes_queue_end:
	ASSERT nes_queue_end-nes_queue < 256


nes_tick:
	ld a,(snd_busy)
	or a
	ret nz
	ld a,(nes_q_count)
	or a
nq_empty:
	ret z
	ld hl,0
	add hl,sp
	ld (nes_q_sp),hl
	ld hl,(nes_q_read)
	ld sp,hl
	pop hl
	pop af
	jp z,nq_voice_0
	out (0x08),a
	jp nc,nq_voice_0
	ld a,l
	out (11),a
	ld a,h
	out (11),a
nq_voice_0:
	pop hl
	pop af
	jp z,nq_voice_1
	out (0x08),a
	jp nc,nq_voice_1
	ld a,l
	out (10),a
	ld a,h
	out (10),a
nq_voice_1:
	pop hl
	pop af
	jp z,nq_voice_2
	out (0x08),a
	jp nc,nq_voice_2
	ld a,l
	out (9),a
	ld a,h
	out (9),a
nq_voice_2:
	ld hl,0
	add hl,sp
	ld a,l
	cp nes_queue_end&255
	jp nz,nq_consumed
	ld hl,nes_queue
nq_consumed:
	ld (nes_q_read),hl
	ld hl,(nes_q_sp)
	ld sp,hl
	ld hl,nes_q_count
	dec (hl)
	ret

; AF is scratch at these rendering safe points; preserve BC/DE/HL.
nes_service:
	ld a,(nes_q_idle)
	or a
	ret nz
	ld a,(nes_q_count)
	cp 4
	ret nc
	push bc
	push de
	push hl
	call nes_poll
	pop hl
	pop de
	pop bc
	ret

nes_pole_stop:
	xor a
	ld (nes_pole),a
	ld hl,nes_sfx_landing
	ld (nes_p_ptr),hl
	inc a
	ld (nes_p_wait),a
	ret
