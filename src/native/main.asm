; Four fixed processes: preserve the original order, counters and frame barriers.
; A procedure may change its own counter, so reload it after CALL before decrement.
main_loop:
 call joe_step_gate
L_A5D1:
 IFDEF NES_FULL
 call mute_step             ; клавиша M — звук, затем читы
 ENDIF
		call joe_clock
		xor	a
		ld	(0x7207),a
mn_proc0:	ld	a,(0x705F)
		and	8
		call	nz,mn_ready
		ld	a,(0x7073)
		cp	0xFE
		jp	z,mn_proc1
		cp	1
		call	z,proc_91E5
		ld	hl,0x7073
		dec	(hl)
		jp	nz,mn_proc1
		ld	(hl),2
mn_proc1:	ld	a,(0x705F)
		and	8
		call	nz,mn_ready
		ld	a,(0x7012)
		cp	0xFE
		jp	z,mn_proc2
		cp	1
		call	z,proc_8F5F
		ld	hl,0x7012
		dec	(hl)
		jp	nz,mn_proc2
		ld	(hl),4
mn_proc2:	ld	a,(0x705F)
		and	8
		call	nz,mn_ready
		ld	a,(0x7068)
		cp	0xFE
		jp	z,mn_proc3
		cp	1
		call	z,proc_88D1
		ld	hl,0x7068
		dec	(hl)
		jp	nz,mn_proc3
		ld	(hl),1
mn_proc3:	ld	a,(0x705F)
		and	8
		call	nz,mn_ready
		ld	a,(0x7074)
		cp	0xFE
		jp	z,mn_proc4
		cp	1
		call	z,proc_A8D6
		ld	hl,0x7074
		dec	(hl)
		jp	nz,mn_proc4
		ld	(hl),1
mn_proc4:	ld	a,(0x705F)
		and	8
		call	nz,mn_ready		; the original sentinel also waits for 705F bit 3
mn9:		ld	a,(0x7207)
		and	0x80
		jp	nz,main_loop
		call	frame_wait
		jp	mn9

mn_ready:	ld	a,(0x705F)
		and	8
		ret	z
		call	frame_wait
		jp	mn_ready
