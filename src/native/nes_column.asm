; Колонны (тайлы CC, CD — по ним Джо не лазит): белые 4 точки (C000) и серая полоса 2 точки по правому краю
; (8000+C000 — слот 5). Вызывается из style_image; CY = образ готов. В тёмной комнате — обычный путь (не видна).
; Лежит в хвосте dlist (DL_MAX 34: больше 33 записей не бывает, переполнение — штатная перерисовка строк).
column_image:
 ld a,(rr_t)
 and 0xFE
 cp 0xCC
 jp nz,ci_plain
 ld a,(room_colors+1)		; темнота: группа 1 = 00
 or a
 jp z,ci_plain
 ld hl,(tile_dst)           ; 8000: серая полоса (столбцы 6–7), A000: 0, C000: колонна (столбцы 2–7)
 ld de,8
 ld b,e
ci_row:
 ld (hl),3
 push hl
 add hl,de
 ld (hl),0
 add hl,de
 ld (hl),0x3F
 pop hl
 inc hl
 dec b
 jp nz,ci_row
 scf
 ret
ci_plain:
 or a
 ret

; Вспышка смерти (кадры Джо 20..22, белые в C000) в состояниях смерти 8..10: под белыми точками Джо добавить 8000
; -> слот 5 (серый). Белые точки — байт C готового образа (как joe_put: столбцы подряд, на строку M, C, pad, A).
; Фазы облака вложены (joe_native.py); при смене облака на другой кадр (поза 18 огненной смерти) joe_burst_clean
; перед восстановлением фона снимает 8000 под прежним облаком (его образ — во втором буфере кэша). Дальше —
; перерисовка комнаты после смерти.
joe_burst_grey:                 ; конец joe_put
 ld a,(jn_frame)
 sub 20
 cp 3
 ret nc
 ld a,(jn_put_sp+2)
 ld bc,0xB000                   ; or b; маска точек как есть
 jp jb_go
joe_burst_clean:                ; начало joe_restore (после push bc)
 ld a,(jn_frame)
 sub 20
 cp 3
 ret c                          ; новый кадр — тоже облако
 ld a,(jn_shown)
 sub 20
 cp 3
 ret nc                         ; на экране было не облако
 ld a,(jn_put_sp+2)
 xor JOE_PAGE_XOR               ; образ показанного облака
 ld bc,0xA0FF                   ; and b; маска инвертирована
jb_go:
 ld d,a
 ld e,(JOE_PICTURE&255)+1
 ld a,(0x7079)
 cp 8
 ret c                          ; не смерть
 ld a,b
 ld (jb_op),a
 ld a,c
 ld (jb_xor+1),a
 ld hl,spr_rec+7
 ld a,(spr_rec+8)
 sub (hl)
 inc a
 ld (jn_columns),a
 ld a,(spr_rec+10)
 add a,0xC0
 ld h,a
jbg_col:
 ld a,(spr_rec+11)
 ld c,a                     ; строк
 ld a,(spr_rec+9)
 ld l,a
jbg_row:
 ld a,(de)                  ; белые точки Джо
jb_xor:
 xor 0
 ld b,a
 inc de
 inc de
 inc de
 inc de
 ld a,h
 sub 0x40
 ld h,a
 ld a,(hl)
jb_op:
 or b                       ; or b — добавить, and b — снять
 ld (hl),a
 ld a,h
 add a,0x40
 ld h,a
 dec l
 dec c
 jp nz,jbg_row
 inc h                      ; следующий столбец
 ld a,(jn_columns)
 dec a
 ld (jn_columns),a
 jp nz,jbg_col
 ret

; NES $9F7A: два шага ходьбы над краем до начала падения (перенесено из nes_terrain.asm).
nphys_ground_floor:
 ld hl,0x7072
 call L_911E
 jp nc,npg_floor
 inc (hl)
 ld a,(hl)
 cp 3
 ccf
 ret
npg_floor:
 ld (hl),0
 ret
