; Full native NES field: 32x24 below six HUD rows.
; L_A4B5: A := ROW_BASE[71A7] + 71A8
L_A4B5:		ld	a,(0x71A7)
		ld	hl,C_A4C5
		call	add_hl_a
		ld	a,(0x71A8)
		add	a,(hl)
		ret
; L_A540: HL += A, A := (HL) (BC сохраняется)
L_A540:		add	a,l
		ld	l,a
		ld	a,h
		adc	a,0
		ld	h,a
		ld	a,(hl)
		ret

; L_A514: объект номер 71A2 (счётчик, +1) взят? бит n & 7 байта 70C0 + 71A1 + n / 8. CY — взят;
; выход: HL -> байт флагов, D = маска (для 92BE)
L_A514:		ld	a,(0x71A2)
		ld	b,a
		inc	a
		ld	(0x71A2),a
		ld	a,b
		rrca
		rrca
		rrca
		and	0x1F
		ld	c,a
		ld	a,(0x71A1)
		add	a,c
		ld	hl,0x70C0
		call	add_hl_a
		ld	a,b
		and	7
		ld	c,a
		ld	a,1
		inc	c
ob1:		dec	c
		jp	z,ob2
		add	a,a
		jp	ob1
ob2:		ld	d,a
		and	(hl)
		ret	z			; CY = 0 (после AND)
		scf
		ret

L_AA96:		ld	a,(0x7000)
		or	4
		ld	(0x7000),a
		call	L_AEA7
		ld	a,(0x7000)
		and	0xFB
		ld	(0x7000),a
		ret


; L_A394: HL := 72C0 + 2 * (71A2), A := (HL)
L_A394:		ld	a,(0x71A2)
		add	a,a
		ld	hl,0x72C0
		jp	L_A540
; L_A3A0: позиция объекта (71B0) — в список 72C0
L_A3A0:		call	L_A394
		ex	de,hl
		ld	hl,(0x71B0)
		ex	de,hl
		ld	(hl),e
		inc	hl
		ld	(hl),d
		ret
; L_A378: предмет 2x2 набора A в клетку DE (DE — сохраняется)
L_A378:		ld	hl,C_9FD2
		call	L_A540
		ld	bc,0x0102
		call	L_AEA7
		inc	hl
		inc	hl
		push	de
		ex	de,hl
		ld	bc,0x20
		add	hl,bc
		ex	de,hl
		ld	bc,0x0102
		call	L_AEA7
		pop	de
		ret

L_AE77:		ld	hl,0x70B3
		inc	(hl)
		jp	video_off
L_AE83:		ld	hl,0x70B3
		dec	(hl)
		ret	nz
		jp	video_on

; Original NES coordinates and persistent native object flags.
L_A067:
 call nf_valid_room
 ret nc
 ld hl,(0x71A7)
 ld (nf_room_row),hl
 call L_AE77
 call snd_off
 ; There is no SAT Y=$D0 terminator in the 240-line field. Unused actors
 ; are hidden by colour; real Joe/enemies may legitimately pass through Y=208.
 ld hl,0x730B
 ld b,4
nf_clear_actors:
 ld (hl),0
 ld a,4
 call add_hl_a
 dec b
 jp nz,nf_clear_actors
 ld hl,0x7086
 ld bc,15
 ld e,255
 call memfill
 ld hl,0x72C0
 ld bc,32
 ld e,0
 call memfill
 dec hl
 ld (hl),0xFE
 dec hl
 ld (hl),0xFE
 xor a
 ld (0x707A),a
 ld (0x71A2),a
 call L_A4B5
 ld (0x7015),a
 ld (0x71A5),a
 add a,a
 ld (0x71A1),a
 ld hl,nf_rooms
 call add_hl_a
 ld e,(hl)
 inc hl
 ld d,(hl)
 ld hl,FIELD_VNT
 call nf_unpack
 ld a,(0x71A5)
 add a,a
 ld hl,nf_object_lists
 call add_hl_a
 ld e,(hl)
 inc hl
 ld d,(hl)
 ld a,0x90
 ld (nf_visibility),a
nf_next:
 ld a,(de)
 inc de
 or a
 jp z,nf_done
 cp 255
 jp nz,nf_record
 ld a,(de)
 inc de
 ld (nf_visibility),a
 jp nf_next
nf_record:
 ld b,a
 and 3
 ld h,a
 ld a,(de)
 inc de
 ld l,a
 ld (0x71B0),hl
 ld a,b
 rrca
 rrca
 and 63
 ld hl,nf_type_flags
 call add_hl_a
 ld a,(hl)
 ld (nf_flags),a
 ld a,b
 rrca
 rrca
 and 63
 ld hl,nf_type_kind
 call add_hl_a
 ld a,(hl)
 ld (nf_kind),a
 push de
 ld a,(0x71A6)
 dec a
 ld c,a
 ld a,(nf_visibility)
 and 15
 cp c
 jp z,nf_min_ok
 jp nc,nf_invisible
nf_min_ok:
 ld a,(nf_visibility)
 rrca
 rrca
 rrca
 rrca
 and 15
 cp c
 jp c,nf_invisible
 jp z,nf_invisible
 ld a,(nf_kind)
 cp 0x80
 jp z,nf_decor
 call L_A514
 jp c,nf_taken
 ld a,(nf_kind)
 cp 5
 jp c,nf_actor
 call L_A3A0
 ld hl,(0x71B0)
 ex de,hl
 ld a,(nf_kind)
 cp 0x0E
 jp nc,nf_closed
 call nf_item_set
 call L_A378
 jp nf_next_pop
nf_invisible:
 ld a,(nf_kind)
 cp 0x80
 jp z,nf_next_pop
 ld hl,0x71A2
 inc (hl)
 jp nf_next_pop
nf_taken:
 ld a,(nf_kind)
 cp 0x0E
 jp c,nf_next_pop
 call nf_door_set
 call L_A3F1
 jp nf_next_pop
nf_closed:
 call nf_door_set
 call nf_closed_door
 jp nf_next_pop
nf_decor:
 ld hl,(0x71B0)
 ld de,VNT
 add hl,de
 ld a,(nf_flags)
 ld (hl),a
 jp nf_next_pop
nf_actor:
 cp 1
 jp nz,nf_mobile
 call L_A3A0
 ld hl,(0x71B0)
 ex de,hl
 ld a,(nf_flags)
 and 4
 ld a,0x7C
 jp z,nf_snake_set
 ld a,0x81
nf_snake_set:
 call L_A378
 jp nf_next_pop
nf_mobile:
 ld a,(0x707A)
 cp 4
 jp nc,nf_next_pop
 inc a
 ld (0x707A),a
 ld (nf_enemy),a
 add a,a
 add a,a
 ld c,a
 call L_A394
 ld (hl),c
 inc hl
 ld (hl),255
 ld a,c
 ld hl,0x7304
 call add_hl_a
 push hl
 ld hl,(0x71B0)
 ; packed NES XY cell: X=low five bits, Y=remaining five bits.
 ld a,l
 and 31
 add a,a
 add a,a
 add a,a
 ld b,a
 ld a,l
 and 0xE0
 rrca
 rrca
 ld c,a
 ld a,h
 add a,a
 add a,a
 add a,a
 add a,a
 add a,a
 add a,a
 or c
 dec a
 pop hl
 ld (hl),a
 inc hl
 ld (hl),b
 inc hl
 ld a,(nf_kind)
 cp 2
 ld a,0x0C
 jp nz,nf_skull_shape
 ld a,0x2C
nf_skull_shape:
 ld (hl),a
 inc hl
 ld (hl),15
 ld a,(nf_enemy)
 dec a
 add a,a
 ld hl,0x7086
 call add_hl_a
 ld a,(nf_kind)
 cp 2
 ld c,0x48
 jp z,nf_behavior
 cp 4
 ld c,0x10
 jp z,nf_behavior
 ld c,8
nf_behavior:
 ld a,(nf_enemy)
 inc a
 or c
 ld c,a
 ld a,(nf_flags)
 and 4
 ld a,c
 jp z,nf_direction
 or 0x80
nf_direction:
 ld (hl),a
 inc hl
 ld (hl),0
nf_next_pop:
 pop de
 jp nf_next
nf_done:
 call L_A548
 jp L_AE83

; A = NES pickup -> old native four-tile set offset.
nf_item_set:
 ld hl,nf_item_sets-5
 jp L_A540
nf_item_sets: db 0x62,0x58,0x5D,0x0B,0x53,0x4E,0x44,0x49
nf_door_set:
 ld a,(nf_kind)
 sub 0x0E
 ld hl,nf_door_sets
 jp L_A540
nf_door_sets: db 0x77,0x69,0x70
nf_closed_door:
 ld hl,nf_closed_white
 cp 0x77
 jp z,nfc_pick
 ld hl,nf_closed_blue
 cp 0x69
 jp z,nfc_pick
 ld hl,nf_closed_red
nfc_pick:
 ld a,(hl)
 push hl
 ld hl,(0x71B0)
 ex de,hl
 ld b,3
nfc_row:
 push bc
 push af
 ld bc,1
 call nt_fill
 ld hl,32
 add hl,de
 ex de,hl
 pop af
 pop bc
 dec b
 jp nz,nfc_row
 pop hl
 inc hl
 ld a,(hl)
 ld bc,1
 jp nt_fill
nf_closed_white: db 0xC0,0xC7
nf_closed_blue: db 0xB0,0xB7
nf_closed_red: db 0xBB,0x9C

; NES doors open into a 3x4 arch, centred on the closed column.
L_A3F1:
 ld hl,nf_open_white
 cp 0x77
 jp z,nfo_pick
 ld hl,nf_open_blue
 cp 0x69
 jp z,nfo_pick
 ld hl,nf_open_red
nfo_pick:
 push hl
 ld hl,(0x71B0)
 dec hl
 ex de,hl
 pop hl
 ld c,3
 call nt_put
 inc hl
 inc hl
 inc hl
 ld a,(hl)
 ld b,3
nfo_row:
 push bc
 push af
 ld hl,32
 add hl,de
 ex de,hl
 ld bc,3
 call nt_fill
 pop af
 pop bc
 dec b
 jp nz,nfo_row
 ret
nf_open_white: db 0xC1,0xC2,0xC3,0xC5
nf_open_blue: db 0xB1,0xB2,0xB3,0xB4
nf_open_red: db 0xBC,0xBD,0xBE,0xBF

; Bit LZ: fixed five-bit literals, near/far distances, variable run lengths.
nf_unpack:
 ld bc,768
 push hl
 ld h,b
 ld l,c
 ld (nf_left),hl
 pop hl
 xor a
 ld (nf_bitcount),a
nfu_token:
 call nes_service
 call nf_bit1
 jp c,nfu_match
 ld b,5
 call nf_getbits
 push hl
 ld hl,nf_literals
 call add_hl_a
 ld a,(hl)
 pop hl
 ld (hl),a
 inc hl
 call nfu_dec
 ret z
 jp nfu_token
nfu_match:
 call nf_bit1
 jp c,nfu_dist_long
 ld b,5
 call nf_getbits
 ld c,a
 ld b,0
 jp nfu_distance
nfu_dist_long:
 call nf_bit1
 jp c,nfu_dist_far
 ld b,8
 call nf_getbits
 ld c,a
 ld b,0
 jp nfu_distance
nfu_dist_far:
 ld b,2
 call nf_getbits
 ld (nf_dist_hi),a
 ld b,8
 call nf_getbits
 ld c,a
 ld a,(nf_dist_hi)
 ld b,a
nfu_distance:
 inc bc
 push hl
 ld h,b
 ld l,c
 ld (nf_distance),hl
 pop hl
 call nf_bit1
 jp c,nfu_len_long
 ld b,2
 call nf_getbits
 add a,3
 ld c,a
 ld b,0
 jp nfu_length
nfu_len_long:
 call nf_bit1
 jp c,nfu_len_far
 ld b,5
 call nf_getbits
 add a,7
 ld c,a
 ld b,0
 jp nfu_length
nfu_len_far:
 ld b,8
 call nf_getbits
 add a,39
 ld c,a
 ld b,0
 jp nc,nfu_length
 inc b
nfu_length:
 push de
 push hl
 ld hl,(nf_distance)
 ex de,hl
 pop hl
 ld a,l
 sub e
 ld e,a
 ld a,h
 sbc a,d
 ld d,a
nfu_copy:
 ld a,(de)
 ld (hl),a
 inc de
 inc hl
 call nfu_dec
 dec bc
 ld a,b
 or c
 jp nz,nfu_copy
 pop de
 push hl
 ld hl,(nf_left)
 ld a,h
 or l
 pop hl
 ret z
 jp nfu_token
nfu_dec:
 push hl
 ld hl,(nf_left)
 dec hl
 ld (nf_left),hl
 ld a,h
 or l
 pop hl
 ret
; B bits -> A, MSB first. DE is the compressed cursor; HL output survives.
nf_getbits:
 ld c,0
nf_getloop:
 call nf_bit1
 ld a,c
 rla
 ld c,a
 dec b
 jp nz,nf_getloop
 ret
nf_bit1:
 ld a,(nf_bitcount)
 or a
 jp nz,nf_bit_have
 ld a,(de)
 inc de
 ld (nf_bitbyte),a
 ld a,8
 ld (nf_bitcount),a
nf_bit_have:
 ld a,(nf_bitbyte)
 add a,a
 ld (nf_bitbyte),a
 push af
 ld a,(nf_bitcount)
 dec a
 ld (nf_bitcount),a
 pop af
 ret

; Native HUD mirrors the six-row NES arrangement, with original two-colour hats.
L_A548:
 call map_edit_begin
 call nf_hud_rebuild
 jp map_edit_end
nf_hud_rebuild:
 ld de,nf_hud_rle
 ld hl,VNT
nfh_unpack:
 ld a,(de)
 inc de
 or a
 jp z,nfh_ready
 ld b,a
 ld a,(de)
 inc de
nfh_run:
 ld (hl),a
 inc hl
 dec b
 jp nz,nfh_run
 jp nfh_unpack
nfh_ready:
 ld a,1
 ld (hud_dirty),a
 call L_AEFE
 ld hl,0x71B2
 ld de,0x41
nfh_items:
 ld a,(hl)
 cp 255
 jp z,L_AABB
 push hl
 push de
 call L_A378
 pop de
 inc de
 inc de
 pop hl
 inc hl
 jp nfh_items
L_AEFE:
 push af
 push bc
 push de
 push hl
 ld hl,0x7017
 ld de,0x52
 ld b,3
nfh_score:
 push bc
 ld a,(hl)
 push hl
 push af
 rrca
 rrca
 rrca
 rrca
 and 15
 call nf_digit
 inc de
 inc de
 pop af
 and 15
 call nf_digit
 inc de
 inc de
 pop hl
 inc hl
 pop bc
 dec b
 jp nz,nfh_score
 ld a,(0x71A6)
 ld de,0x4E
 call nf_digit
 pop hl
 pop de
 pop bc
 pop af
 ret
; A digit 0..9, DE upper-left cell. Full NES 16x16, four characters.
nf_digit:
 push bc
 push de
 add a,a
 add a,a
 add a,0x18
 cp 0x38
 jp nz,nfd_tiles
 ld a,0xDA
nfd_tiles:
 ld bc,1
 call nt_fill
 inc de
 inc a
 call nt_fill
 ld hl,31
 add hl,de
 ex de,hl
 inc a
 call nt_fill
 inc de
 inc a
 call nt_fill
 pop de
 pop bc
 ret
L_AABB:
 push af
 push bc
 push de
 ld de,0xBA
 ld a,0x6F
 ld bc,1
 call nt_fill
 inc de
 ld a,0x6E
 call nt_fill
 inc de
 ld a,0x4A
 call nt_fill
 inc de
 ld a,(0x7049)
 dec a
 cp 10
 jp c,nfh_lives_one
 ; Retain the exact life count even above nine, without truncating icons.
 ld c,0
nfh_tens:
 sub 10
 inc c
 cp 10
 jp nc,nfh_tens
 push af
 ld a,c
 add a,0x40
 ld bc,1
 call nt_fill
 inc de
 pop af
nfh_lives_one:
 add a,0x40
 ld bc,1
 call nt_fill
 pop de
 pop bc
 pop af
 ret

 ; CY: candidate normal room belongs to the 99-room pyramid. BC is the
; pending coordinate wrap and must survive. Floor 9 uses the bonus handler.
nf_valid_room:
 ld a,(0x71A7)
 cp 9
 jp nc,nfv_no
 ld d,a
 ld a,8
 sub d
 ld e,a
 ld a,(0x71A8)
 cp e
 jp c,nfv_no
 ld a,11
 add a,d
 ld e,a
 ld a,(0x71A8)
 cp e
 ret
nfv_no:
 or a
 ret
; Reject an outer edge without ever indexing past nf_rooms. The movement
; already happened; restore the resident room and clamp its logical anchor.
nf_room_edge:
 ld hl,(nf_room_row)
 ld (0x71A7),hl
 ld bc,0
 ld a,(0x7304)
 cp HUD_ROWS*8-17
 jp c,nfe_top
 cp SCREEN_HEIGHT-17
 jp c,nfe_x
 ld c,SCREEN_HEIGHT-18
 jp nfe_y
nfe_top:
 ld c,HUD_ROWS*8-17
nfe_y:
 ld hl,0x7304
 ld a,c
 sub (hl)
 ld c,a
nfe_x:
 ld a,(0x7301)
 cp 4
 jp c,nfe_left
 cp 240
 jp c,nfe_done
 ld b,239
 jp nfe_dx
nfe_left:
 ld b,4
nfe_dx:
 ld hl,0x7301
 ld a,b
 sub (hl)
 ld b,a
nfe_done:
 jp L_8DD4

; Convert decorative-only variants to the established collision vocabulary.
; Collision readers see only the field. Score digits and life hats in the
; six HUD rows must never become walls, keys, or hazards at a room boundary.
nf_read_tile:
 ld a,h
 cp FIELD_VNT/256
 jp nc,nfr_field
 xor a
 ret
nfr_field:
 ld a,(hl)
 jp nf_semantic
nf_semantic:
 cp 0x0B
 ret c
 jp z,nfs_wall
 cp 0x95
 jp z,nfs_chain
 cp 0xB1
 ret c
 cp 0xC8
 jp nc,nfs_variant
 cp 0xB5
 jp c,nfs_empty
 cp 0xBC
 ret c
 cp 0xC0
 jp c,nfs_empty
 cp 0xC1
 ret c
 cp 0xC6
 ret nc
nfs_empty: xor a
 ret
nfs_wall: ld a,8
 ret
nfs_chain: ld a,0x90
 ret
nfs_variant:
 cp 0xD8
 ret nc
 push hl
 sub 0xC8
 ld hl,nfs_variants
 call add_hl_a
 ld a,(hl)
 pop hl
 ret
nfs_variants:
 db 0x88,0x89,8,8,0x95,0x95,0xCE,0xCF
 db 0xD0,0xD1,0xD2,0xD3,0xD4,0xD5,8,8

; A physical tile row and C column -> VNT pointer; BC/DE preserved.
nf_row_addr:
 ; VNT = $7B00 + two rows; row+2 fits five bits for all 30 rows.
 add a,2
 rrca
 rrca
 rrca
 ld l,a
 and 3
 add a,0x7B
 ld h,a
 ld a,l
 and 0xE0
 or c
 ld l,a
 ret

nf_draw_hud:
 xor a
 ld (hud_dirty),a
 ld de,VNT
 ld hl,0x80FF
 ld c,HUD_ROWS
nfh_draw_row:
 ld b,32
nfh_draw_cell:
 ld a,(de)
 push de
 push hl
 push bc
 ld (rr_t),a
 call tile_ready
 ld (tile_src),hl
 pop bc
 pop hl
 call da_blit
 pop de
 inc de
 inc h
 dec b
 jp nz,nfh_draw_cell
 call nes_service
 ld h,0x80
 ld a,l
 sub 8
 ld l,a
 dec c
 jp nz,nfh_draw_row
 ret
