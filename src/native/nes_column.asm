; Колонны (тайлы CC, CD — по ним Джо не лазит): белые 4 точки (C000) и серая полоса 2 точки по правому краю
; (8000+C000 — слот 5). Вызывается из style_image; CY = образ готов. В тёмной комнате — обычный путь (не видна).
; Лежит в хвосте dlist (DL_MAX 64: больше 33 записей не бывает, переполнение — штатная перерисовка строк).
column_image:
 ld a,(rr_t)
 and 0xFE
 cp 0xCC
 jp nz,ci_plain
 ld a,(room_colors+1)
 cp 0x11
 jp z,ci_plain
 ld de,column_tile
 ld hl,(tile_dst)
 ld bc,24
 call copy_de_hl
 scf
 ret
ci_plain:
 or a
 ret
column_tile:
 db 3,3,3,3,3,3,3,3                       ; 8000: серая полоса (столбцы 6–7)
 db 0,0,0,0,0,0,0,0                       ; A000
 db 0x3F,0x3F,0x3F,0x3F,0x3F,0x3F,0x3F,0x3F ; C000: колонна, столбцы 2–7
