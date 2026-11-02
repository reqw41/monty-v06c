; Звуки шагов и ступеней лестницы, анимация упора в стену (NES: у стены Джо стоит).
; Постоянный код в свободном участке FB97..FBD0 (бывшая область музыкальных фраз/сдвигов; исключена в to_vi53.py и ps_rg).
 ORG 0xFB97
; Шаг — короткий тональный «тук» на канале 1 (меандр, как у эффектов прыжка/подбора): шумовой путь канала 2 (режим 0)
; давал лишь по перепаду на кадр — почти неслышно. Не прерывает идущий эффект канала 1 и шест (nes_p_wait ≠ 0).
nes_step_sfx:
 ld a,(nes_p_wait)
 or a
 ret nz
 ld hl,nes_step_stream
 ld (nes_p_ptr),hl
 ld a,1
 ld (nes_p_wait),a
 xor a
 ld (nes_q_idle),a           ; в уровне без музыки очередь простаивает — разбудить (как nes_event)
 ret
nes_step_stream:
 db 1,0x04,0x09              ; 1 кадр ≈ 650 Гц (1,5 МГц / 0904h)
 db 1,0xD6,0x0F              ; 1 кадр ≈ 370 Гц
 db 0
; Лестница: «тук» при каждой смене позы (jn_tick = 4 и 8). HL -> jn_tick, сохраняется.
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
