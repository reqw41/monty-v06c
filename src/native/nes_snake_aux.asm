; Persistent snake helpers in the unused tail of the sprite table page.
 ORG sprt_end

; Original NES $AF8E: compare Joe's X with the snake's X on each step.
; DE = two-cell VNT offset; A = native 2x2 tile set.
nes_snake_choice:
 ld a,e
 and 31
 add a,a
 add a,a
 add a,a
 dec a
 ld b,a
 ld a,(0x7301)
 cp b
 ld a,0x7C		; right-facing A0..A3
 ret nc
 ld a,0x81		; left-facing A5,A4,A7,A6
 ret

; Shared snake/spider slot 4 stays green normally and cycles
; blue, pink, black, green while item 09 protects Joe.
nes_snake_palette:
 ld a,(video_enabled)
 or a
 ret z                    ; preserve the separate title/game-over palette
 ld a,(nes_amulet_ticks)
 ld b,a
 ld a,(nes_amulet_ticks+1)
 or b
 ld a,32		; original NES $19 green in Vector palette
 jp z,nsp_color
 ld a,(frames)
 rrca
 rrca
 and 3
 ld hl,nes_snake_cycle
 call add_hl_a
 ld a,(hl)
nsp_color:
 ld hl,pal+8
 cp (hl)
 ret z
 ld (hl),a
 inc hl
 ld (hl),a
 ld a,(pal_load)
 or a
 ret nz
 inc a
 ld (pal_load),a
 ret
nes_snake_cycle: db 234,159,0,114
nes_snake_aux_end:
 ASSERT nes_snake_aux_end <= sprite_table_free_end
