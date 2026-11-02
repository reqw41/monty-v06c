; Плоскость подвижного врага: решается при рисовании и запоминается в байте +14 записи спрайта
; (02h — C000, белый череп; 82h — 8000, паук, а также череп, пока действует амулет: NES красит всех
; врагов одной спрайтовой палитрой). Восстановление фона читает плоскость из записи, поэтому смена
; состояния амулета между рисованием и восстановлением безопасна.
; Код постоянный, живёт в FEC0..FF00 (там при загрузке работал распаковщик заставки; образ игры
; сохраняется только до FEC0), поэтому копируется туда в nes_boot из одноразовой области кэша тайлов.
NES_SKULL_CODE equ 0xFEC0
	ORG 0xE680
 ASSERT nes_title_spill_end <= 0xE680
nes_skull_source:
	DISP NES_SKULL_CODE
; en_mark: HL = запись +14 (spr_put), B сохраняется; DE свободен (enemy_native_put/joe_put задают его сами).
en_mark:
 ld e,l
 ld a,l
 xor 0x0D                   ; +14 -> +3: имя позы
 ld l,a
 ld a,(hl)
 sub 0x2C
 cp 8
 sbc a,a                    ; FF — паук
 ld c,a
 ld a,(nes_amulet_ticks)
 or c
 ld c,a
 ld a,(nes_amulet_ticks+1)
 or c
 ld a,2
 jp z,en_mark_w
 ld a,0x82
en_mark_w:
 ld l,e
 ld (hl),a
 ret
; enemy_ink_plane: HL — любой байт записи; A = старший байт плоскости (C0/80). HL сохраняется.
enemy_ink_plane:
 push hl
 ld a,l
 and 0xF0
 or 14
 ld l,a
 ld a,(hl)
 rrca                       ; 01 / 41
 xor 0xC1                   ; C0 / 80
 pop hl
 ret
	ENT
nes_skull_source_end:
 ASSERT nes_skull_source_end-nes_skull_source <= 0x40
 ASSERT nes_skull_source_end <= 0xE700
