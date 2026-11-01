; Persistent snake presentation in the short gap after Joe's latch code.
 ORG joe_latch_end

; DE is the object's 2x2 VNT offset. Keep the hazard tile numbers A0..A7.
nes_snake_record_draw:
 push de
 ld a,(nf_snake_count)
 cp 4
 jp nc,nsr_untracked
 add a,a
 ld hl,nf_snake_offsets
 call add_hl_a
 pop de
 push de
 ld (hl),e
 inc hl
 ld (hl),d
 ld hl,nf_snake_count
 inc (hl)
nsr_untracked:
 pop de
 call nes_snake_choice
 jp L_A378

nes_snake_face_all:
 ld a,(nf_snake_count)
 or a
 ret z
 ld b,a
 ld hl,nf_snake_offsets
nsf_next:
 push bc
 ld e,(hl)
 inc hl
 ld d,(hl)
 inc hl
 push hl
 call nes_snake_choice
 ld c,a
 cp 0x7C
 ld a,0xA5
 jp nz,nsf_check
 ld a,0xA0
nsf_check:
 ld hl,VNT
 add hl,de
 cp (hl)
 jp z,nsf_done
 ld a,c
 call L_A378
nsf_done:
 pop hl
 pop bc
 dec b
 jp nz,nsf_next
 ret

SNAKE_POSE_TICKS equ 10
nes_snake_step:
 ld hl,snake_tick
 inc (hl)
 ld a,(hl)
 cp SNAKE_POSE_TICKS     ; redraw the pose half as often; logic still runs each step
 jp c,nss_face
 xor a
 ld (hl),a
 ld hl,snake_frame
 ld a,(hl)
 xor 1
 ld (hl),a
 ld a,(nf_snake_count)
 or a
 jp z,nss_face
 ld a,(video_dirty)
 or DIRTY_SNAKE
 ld (video_dirty),a
nss_face:
 call nes_snake_face_all
 call nes_amulet_step
 jp nes_snake_palette

; Snakes have fixed 2x2 positions. Queue only their two changing tiles through
; the ordinary covered-cell path; turning no longer rebuilds all live buckets.
NES_SNAKE_LOCAL equ 1
nes_snake_render:
 ld a,(video_dirty)
 and DIRTY_SNAKE
 ret z
 ld a,(video_dirty)
 and 0xFF-DIRTY_SNAKE
 ld (video_dirty),a
 ld a,(snake_frame)
 ld (snake_shown),a
 ld a,(nf_snake_count)
 or a
 ret z
 ld b,a
 ld hl,nf_snake_offsets
ns_local_next:
 push bc
 ld e,(hl)
 inc hl
 ld d,(hl)
 inc hl
 push hl
 call ns_local_pair
 pop hl
 pop bc
 dec b
 jp nz,ns_local_next
 ret

ns_local_pair:
 ld hl,VNT
 add hl,de
 ld a,(hl)
 and 1                     ; A0: right (TR/BL); A5: left (TL/BR)
 ld de,33
 jp nz,ns_local_ready
 inc hl
 dec de
 dec de
ns_local_ready:
 call dl_add
 add hl,de
 jp dl_add

; Tile cache builds two snake poses and four fire poses.
nes_snake_tile_kind:
 cp FULL_ANIM_N
 jp nc,nstk_static
 ld a,l
 cp 0xA0
 jp c,nstk_fire
 cp 0xA8
 ld c,2
 ret c
nstk_fire:
 ld c,4
 ret
nstk_static:
 ld c,1
 ret
nes_snake_end:
 ASSERT nes_snake_end <= 0x7000

; The short phase selector fits before the chain-exit helper below VNT.
 ORG VNT-0x44
nes_snake_phase:
 ld a,l
 cp 0xA0
 jp c,nsp_fire
 cp 0xA8
 jp nc,nsp_fire
 ld a,(snake_shown)
 ret
nsp_fire:
 ld a,(fire_shown)
 ret
 ASSERT $ <= VNT-0x30
