; Колонна вместо витой верёвки (тайлы 90 — верх с перекладиной, 95 — тело): 4 точки белого (C000) и серая полоса 2 точки
; справа (8000+C000 — слот 5). Вызывается из style_image; CY = образ готов. В тёмной комнате — обычный путь (не видна).
; Лежит в хвосте dlist (DL_MAX 64: больше 33 записей не бывает, переполнение — штатная перерисовка строк).
rope_image:
 ld a,(rr_t)
 ld de,rope_body
 cp 0x95
 jp z,ri_go
 ld de,rope_top
 cp 0x90
 jp nz,ri_plain
ri_go:
 ld a,(room_colors+1)
 cp 0x11
 jp z,ri_plain
 ld hl,(tile_dst)
 ld bc,24
 call copy_de_hl
 scf
 ret
ri_plain:
 or a
 ret
rope_body:
 db 6,6,6,6,6,6,6,6                       ; 8000: серая полоса
 db 0,0,0,0,0,0,0,0                       ; A000
 db 0x7E,0x7E,0x7E,0x7E,0x7E,0x7E,0x7E,0x7E ; C000: колонна 6 точек
rope_top:
 db 0,0,6,6,6,6,6,6
 db 0,0,0,0,0,0,0,0
 db 0xFF,0xFF,0x7E,0x7E,0x7E,0x7E,0x7E,0x7E ; перекладина 2 строки
