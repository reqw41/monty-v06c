; Звуки шагов и ступеней лестницы, анимация упора в стену (NES: у стены Джо стоит).
; Постоянный код в свободном участке FB97..FBD0 (бывшая область музыкальных фраз/сдвигов; исключена в to_vi53.py и ps_rg).
 ORG 0xFB97
; Короткий шумовой щелчок на канале 2 (как приземление; бас на 2 кадра уступает). Не прерывает идущий шумовой эффект.
nes_step_sfx:
 ld a,(nes_n_wait)
 or a
 ret nz
 ld hl,nes_step_stream
 ld (nes_n_ptr),hl
 ld a,1
 ld (nes_n_wait),a
 ret
nes_step_stream:
 db 2,0,4,0                  ; 2 кадра, ширина импульса 0400h, конец
; Лестница: щелчок при каждой смене позы (jn_tick = 4 и 8). HL -> jn_tick, сохраняется.
nes_ladder_step:
 ld a,(hl)
 and 3
 ret nz
 push hl
 call nes_step_sfx
 pop hl
 ret
; Упёрся в стену при ходьбе (dX = 0, состояние 1): как в NES — стоит. Границы позы уже пересчитаны в этом шаге,
; поэтому следующий шаг проверяет стену теми же границами (сброс до пересчёта сдвигал Джо на 2 точки в стену).
nphys_box_step_wall:
 call nphys_box_step
 ld a,e
 or a
 ret nz
 ld a,(0x7079)
 cp 1
 ret nz
 xor a
 ld (0x7079),a
 ret
nes_steps_end:
 ASSERT nes_steps_end <= 0xFBD0
