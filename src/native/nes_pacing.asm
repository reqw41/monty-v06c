; Area-weighted sprite work and physical-frame cosmetic cadence.
NES_FRAME_PACING equ 1
NES_ANIM_CLOCK equ 1
PACE_BUDGET equ 96
PACE_ENEMY_PERIOD equ 3
PACE_ENEMY_DEADLINE equ 4
PACE_BG_PERIOD equ 6
PACE_PHASE_PERIOD equ 6
 ASSERT SPR_MAX == 6
 ASSERT pace_enemy_stamp/256 == (pace_enemy_stamp+3)/256
 ASSERT pace_fire_stamp+1 == pace_belt_stamp
pace_charge:
 ; Area-weighted estimate in ~256-cycle units, including matching restore,
 ; cover bookkeeping and draw. Five physical actors fit below 256 units.
 push bc
 ld a,b
 cp 2
 jp c,ck_geometry
 call pace_age
 ld a,(frames)
 ld (hl),a
ck_geometry:
 ld a,b
 call rec_ptr
 ld a,l
 add a,7
 ld l,a
 ld e,(hl)
 inc l
 ld a,(hl)
 sub e
 inc a
 ld c,a
 inc l
 inc l
 inc l
 ld h,(hl)
 xor a
ck_area:
 add a,h
 dec c
 jp nz,ck_area
 ld c,a
 ld a,b
 or a
 ld a,c
 jp nz,ck_enemy_cost
 IFDEF NES_JOE_BLEND80
 add a,a
 add a,12
 ELSE
 ld a,128                 ; full-plane Joe owns the remainder of this IRQ
 pop bc
 ret
 ENDIF
ck_enemy_cost:
 add a,20
 rra
 pop bc
 ret

pace_belt_tick:
 ; Fire and belt phases share a physical clock. Logical 7085/73F9/7096
 ; and platform hazard timers remain native, independently of render load.
 ld a,(frames)
 ld c,a
 ld hl,bg_turn
 sub (hl)
 cp PACE_PHASE_PERIOD
 ret c
 ld (hl),c
 ld hl,belt_frame
 ld a,(hl)
 dec a
 and 3
 ld (hl),a
 dec hl                    ; fire_frame immediately precedes belt_frame
 ld a,(hl)
 inc a
 and 3
 ld (hl),a
 ld a,(video_dirty)
 or DIRTY_FIRE+DIRTY_BELT
 ld (video_dirty),a
 ret

; Stable priority key: Joe keeps his raster deadline; overdue actors precede
; fresh actors, which keep their original Y order.
; BC/DE are the sorter's state and must survive this lookup.
pace_priority:
 cp 2
 ret c                     ; Joe=0; unused metadata layer=1
pace_actor:
 push af
 call pace_age
 cp PACE_ENEMY_DEADLINE
 jp nc,pace_overdue
 pop af
 jp ub_r0
pace_overdue:
 pop af
 ld a,1
 ret

; A = physical actor 2..5. Return age and HL -> its completed-paint stamp.
pace_age:
 sub 2
 add a,pace_enemy_stamp&255
 ld l,a
 ld h,pace_enemy_stamp/256
 ld a,(frames)
 sub (hl)
 ret
