; Клавиша M (ряд 5, бит 20h) включает и выключает весь звук (музыку и эффекты) — в шаге игры.
; Выключение: первый байт nes_tick становится RET (IRQ не трогает ВИ53, очередь стоит — музыка на паузе),
; затем каналы глушатся; включение возвращает LD A,(snd_busy). Дальше — шаг читов.
mute_step:
 ld a,(kbmat+5)
 and 0x20
 cp 0
ms_key equ $-1                 ; прошлое состояние клавиши
 ld (ms_key),a
 jp z,cheat_step            ; без изменений
 jp c,cheat_step            ; отпущена
 ld hl,nes_tick
 ld a,(hl)
 xor 0x3A^0xC9              ; LD A,(snd_busy) <-> RET
 ld (hl),a
 call vi_off
 jp cheat_step
