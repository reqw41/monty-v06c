; Музыка заставки после GAME OVER. Копия темы (ZX0), собранная под TITLE_COPY (кэш тайлов в заставке пуст), лежит постоянно;
; разворачивается в кэш тайлов, который сбрасывается (tiles_reset) и достраивается заново при первой комнате.
; Вызов: из title_resume с запрещёнными прерываниями; затем проигрыватель идёт из frame_wait.
nes_title_music:
 call tiles_reset
 ld hl,nes_title_zx0
 ld de,TITLE_COPY
 call title_zx0
 ld hl,nes_m_ptr
 ld bc,22                   ; EBE0..EBF5: указатели, счётчики, делители (nes_last_frame не трогаем)
 ld e,0
 call memfill
 ld a,64
 ld (nes_m1),a
 ld (nes_m2),a
 ld a,TITLE_COPY>>8
 ld (nes_pitch_page),a
 ld hl,TITLE_COPY_ORDER
 ld a,1
 call nes_select
 ld hl,TITLE_COPY_LOOP
 ld (nes_m_start),hl
 ret
 ASSERT $ <= nes_title_music+56
 DS nes_title_music+56-$
nes_title_zx0:
 INCBIN "gen/title_music.zx0"
