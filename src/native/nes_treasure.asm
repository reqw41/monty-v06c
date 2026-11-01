; NES treasure generator: original $963D/$9766, with $8000 PRNG.
; The normal-room decoder scratch is idle throughout bonus construction.
nt_rng equ nf_distance

nt_jump_dispatch:
 ; Every NES room needs its original jump height, not only bonus room 90.
 ; A rope jump starts without displacement; a ground jump rises immediately.
 ld a,(0x7079)
 cp 4
 jp nz,nt_ground_jump
 ld a,16
 ld (0x7072),a
 ld a,b
 ld (0x7078),a
 ld bc,0                    ; original rope jump: zero-displacement key step
 ld a,2
 jp hs_8992
nt_ground_jump:
 ld a,15                    ; original ground jump already rises on key step
 ld (0x7072),a
 ld c,-3
 ld a,2
 jp hs_8988

; A=layer-2 Y; CY means it is still inside this panel. NES tests Y>=214
; before moving; this platform flight ends at NES Y215 / layer-2 Y222.
; Preserve the manual diagonal velocity and X. A downward NES screen change
; resets its top anchor to37 (layer-2 44), rather than retaining overshoot.
nt_bonus_wrap:
 ld a,(0x705F)
 and 0x20
 jp nz,nt_wrap_y
 ld a,c
 or a
 jp z,L_8DD4
 ld a,120
 ld hl,0x7305
 sub (hl)
 ld b,a
nt_wrap_y:
 ld a,c
 cp 80
 jp nz,L_8DD4
 ld a,44
 ld hl,0x7304
 sub (hl)
 ld c,a
 jp L_8DD4

; NES $9EA5 prefers a rope on the side of approach. The MSX nearest-half
; snap picks the other rope when adjacent random columns are both occupied.
nt_rope_snap:
 ld a,(0x705F)
 and 0x20
 jp z,L_8B27
 ld a,(0x7078)
 and 0x80
 push af
 ld a,(0x7305)
 jp z,nt_snap_right
 sub 4
nt_snap_right:
 and 0xF8
 or 4
 ld (0x7301),a
 ld (0x7305),a
 call L_9156
 ld a,(0x705B)
 cp 0x90
 jp z,nt_snap_done
 pop af
 ld a,8
 jp nz,nt_snap_add
 cpl
 inc a
nt_snap_add:
 ld hl,0x7305
 add a,(hl)
 ld (hl),a
 ld (0x7301),a
 scf
 ret
nt_snap_done:
 pop af
 scf
 ret

L_A60B:
 ld a,(0x705F)
 and 0xF7
 ld (0x705F),a
 call video_off
 ld de,0
 ld bc,NT_CELLS
 xor a
 call nt_fill
 ld (nf_snake_count),a
 ld (0x707A),a
 call nf_hide_actors
 ld a,(0x70AC)
 cp 1
 jp z,nt_bonus_hud
 ld hl,(0x7047)
 ld a,l
 or 1
 ld l,a
 ld (nt_rng),hl
 call nes_treasure_generate
nt_bonus_hud:
 call L_A548
 jp video_on

nes_treasure_generate:
 ld c,0
nt_rope:
 call nt_rand
 and 15
 ld b,a
 call nt_rand
 and 15
 add a,3
 cp b
 jp nc,nt_end_row
 ; The original $95FD/$9605 selects the lower row for both endpoints.
 ld b,a
nt_end_row:
 sub b
 cp 3
 jp nc,nt_length
 add a,3
nt_length:
 ld d,a
 ld a,b
 call nt_random_column
 ld b,d
 ld de,32
nt_rope_cell:
 ld (hl),0x95
 add hl,de
 dec b
 jp nz,nt_rope_cell
 ld a,c
 cp 4
 jp c,nt_rope_next
 call nt_rand
 cp 127
 jp nc,nt_gems
nt_rope_next:
 inc c
 ld a,c
 cp 7
 jp c,nt_rope
nt_gems:
 ld a,(0x71A6)
 cp 3
 jp c,nt_gem_count
 ld a,3
nt_gem_count:
 inc a
 add a,a
 add a,a
 ld b,a
nt_gem:
 call nt_rand
 and 15
 call nt_random_column
 push hl
 ld a,(hl)
 inc hl
 or (hl)
 ld de,31
 add hl,de
 or (hl)
 inc hl
 or (hl)
 pop hl
 jp nz,nt_gem
 ld (hl),0x98
 inc hl
 ld (hl),0xD8
 add hl,de
 ld (hl),0x99
 inc hl
 ld (hl),0xD9
 dec b
 jp nz,nt_gem
 ret

; Row 0..15 maps to the original PPU rows 9..24; column is 2..29.
nt_random_column:
 push bc
 ld b,a
 call nt_rand
nt_mod28:
 sub 28
 jp nc,nt_mod28
nt_column:
 add a,30
 ld c,a
 ld a,b
 add a,9
 call nf_row_addr
 pop bc
 ret

; Exact original NES 16-bit polynomial, eight bit advances per byte.
nt_rand:
 push hl
 push bc
 ld hl,(nt_rng)
 ld b,8
nt_rand_bit:
 add hl,hl
 jp nc,nt_rand_next
 ld a,l
 xor 0x39
 ld l,a
nt_rand_next:
 dec b
 jp nz,nt_rand_bit
 ld (nt_rng),hl
 ld a,l
 pop bc
 pop hl
 ret
; Physical 50 Hz timer, independent of redraws and the game-step cadence.
nt_bonus_tick:
 ld a,(0x705F)
 and 0x20
 ret z
 ld hl,0x70AC
 ld a,(hl)
 cp 1
 ret z
 dec (hl)
 ret
nes_treasure_end:

; The spare sprite-record tail is outside every runtime actor and mask pool.
; Installed once by joe_load; room palette setup calls this code.
 IFDEF NES_STABLE_COLORS
nt_bonus_source_return equ $
 ASSERT ps_boot_source_end-ps_boot_source <= 0x300
 ORG 0xE300
nt_bonus_palette_source:
 DISP 0x6660
NES_TREASURE_GOLD equ 1
TREASURE_BLUE equ 0x80       ; medium pure blue (B=2, G=R=0)
TREASURE_GOLD equ 0x67       ; Joe skin orange, in a separate one-plane slot
nt_bonus_palette:
 ld hl,TREASURE_BLUE*257
 ld (pal),hl
 ld hl,TREASURE_GOLD*257
 ld (pal+8),hl
 ld hl,(pal+4)              ; index 6 aliases Joe red over retained gold ink
 ld (pal+12),hl
 ld a,0x10                 ; jewels: only the 8000 plane
 ld (full_modes+19),a
 ld a,0xC9                 ; enemies are absent: stop their palette animation
 ld (nes_snake_palette),a
 ret
nt_bonus_palette_end:
 ASSERT $ <= 0x6680
 ENT
 ORG nt_bonus_source_return
 ENDIF

 INCLUDE "nes_treasure_motion.asm"
