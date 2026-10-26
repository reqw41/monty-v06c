; создано tools/z2i.py — вспомогательные процедуры для команд Z80 без аналога в i8080

z_ldir:		push	af			; LDIR: флаги S, Z, C и A сохраняются
zl1:		ld	a,(hl)
		ld	(de),a
		inc	hl
		inc	de
		dec	bc
		ld	a,b
		or	c
		jp	nz,zl1
		pop	af
		ret

z_cpir:		push	de			; CPIR: Z = найдено (CY не сохраняется)
		ld	d,a
zc1:		ld	a,(hl)
		inc	hl
		dec	bc
		cp	d
		jp	z,zc2
		ld	a,b
		or	c
		jp	nz,zc1
		ld	a,1
		or	a
		ld	a,d
		pop	de
		ret
zc2:		ld	a,d
		cp	d
		pop	de
		ret

z_exaf:		push	hl			; EX AF,AF': обмен с z_af2
		push	af
		ld	hl,(z_af2)
		ex	(sp),hl
		ld	(z_af2),hl
		pop	af
		pop	hl
		ret

z_exx:		push	hl			; EXX: обмен BC, DE, HL с z_bc2, z_de2, z_hl2 (флаги не меняются)
		ld	hl,(z_hl2)
		ex	(sp),hl
		ld	(z_hl2),hl
		pop	hl
		ex	de,hl
		push	hl
		ld	hl,(z_de2)
		ex	(sp),hl
		ld	(z_de2),hl
		pop	hl
		ex	de,hl
		push	hl
		ld	h,b
		ld	l,c
		push	hl
		ld	hl,(z_bc2)
		ld	b,h
		ld	c,l
		pop	hl
		ld	(z_bc2),hl
		pop	hl
		ret

z_neg:		cpl				; NEG: CY = (A != 0)
		inc	a
		scf
		ret	nz
		ccf
		ret

z_sbc_hl_bc:	ld	(z_t),a			; SBC HL,BC: CY — заём, Z — HL = 0 (S не точен), A сохраняется
		ld	a,l
		sbc	a,c
		ld	l,a
		ld	a,h
		sbc	a,b
		ld	h,a
		jp	c,zsb1
		ld	a,h
		or	l
		ld	a,(z_t)
		ret
zsb1:		ld	a,h
		or	l
		scf
		ld	a,(z_t)
		ret

z_rl_a:					; RL A: S, Z, P по результату, CY — выдвинутый бит
		rla
		jp	c,z_rl_a_c
		or	a
		ret
z_rl_a_c:	or	a
		scf
		ret

z_rl_d:					; RL D: S, Z, P по результату, CY — выдвинутый бит
		ld	(z_t),a
		ld	a,d
		rla
		jp	c,z_rl_d_c
		or	a
		ld	d,a
		ld	a,(z_t)
		ret
z_rl_d_c:	or	a
		scf
		ld	d,a
		ld	a,(z_t)
		ret

z_rrc_a:					; RRC A: S, Z, P по результату, CY — выдвинутый бит
		rrca
		jp	c,z_rrc_a_c
		or	a
		ret
z_rrc_a_c:	or	a
		scf
		ret

z_sla_a:					; SLA A: S, Z, P по результату, CY — выдвинутый бит
		add	a,a
		ret

z_sla_e:					; SLA E: S, Z, P по результату, CY — выдвинутый бит
		ld	(z_t),a
		ld	a,e
		add	a,a
		ld	e,a
		ld	a,(z_t)
		ret

z_sra_a:					; SRA A: S, Z, P по результату, CY — выдвинутый бит
		push	bc
		ld	b,a
		rlca
		ld	a,b
		rra
		pop	bc
		jp	c,z_sra_a_c
		or	a
		ret
z_sra_a_c:	or	a
		scf
		ret

z_srl_a:					; SRL A: S, Z, P по результату, CY — выдвинутый бит
		or	a
		rra
		jp	c,z_srl_a_c
		or	a
		ret
z_srl_a_c:	or	a
		scf
		ret

