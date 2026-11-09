; Клавиши шага игры (fix36/37, как в Bruce Lee): УС — музыка вкл/выкл (эффекты звучат всегда), ВК — пауза,
; в паузе АР2 — выход на титул; дальше — шаг читов. ms_keys (F5xx), ms_edge (6FEF),
; ms_music/ms_prev (установщик черепа, FEC0..) лежат в свободных хвостах фиксированных окон.
mute_step:
 call ms_keys
 ld b,a
 and 0x40                   ; УС
 call nz,ms_music
 ld a,b
 and 4
 jp z,cheat_step
; Пауза: логика стоит, IRQ дорабатывает очередь звука, каналы глушатся каждый кадр.
pz_loop:
 call vi_off
 ld hl,kb_req
 inc (hl)                   ; 0 после опроса -> 1: опросить клавиатуру в следующем IRQ
 halt
 ld a,(kbmat+1)
 and 4                      ; АР2
 jp nz,go_quit
 call ms_keys
 and 4
 jp z,pz_loop
 jp cheat_step
