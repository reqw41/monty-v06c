; Кэш двух образов Джо (LRU): JOE_PICTURE (F900) и JOE_PICTURE2 (страница в бывшем загрузочном источнике, mem.asm).
; При ходьбе образ перерисовывается каждые 4 точки: сдвиг x&7 чередуется (0/4 или 2/6), кадр держится 2–3 перерисовки,
; поэтому каждая третья-четвёртая подготовка совпадает с предпоследней — её образ берётся готовым.
; jn_key — ключ текущего образа (страница — в jn_dest_read+2 и jn_put_sp+2), jn_key2 — ключ другого.
; Страницы F9..FF — ещё и буферы спрайтов (слот k: страница F9+k, фон 00..2F, маски D0..FF), поэтому код — только в
; FCC0..FCCF и FD95..FDCF; переменные — за вторым образом (окно вырезано из пула сдвигов вместе с ним).
jn_key2 equ JOE_PICTURE2+12*joe_nes_rows
jn_old equ jn_key2+5
 ASSERT jn_old+5 <= JOE_CACHE_END
JOE_PAGE_XOR equ (JOE_PICTURE>>8)^(JOE_PICTURE2>>8)
 ORG 0xFCC0
; Вместо «ld hl,jn_key» в joe_prepare: запомнить ключ текущего образа до сравнения.
jn_pre:
 ld hl,jn_key
 ld de,jn_old
 ld b,5
 call jn_cp
 ld hl,jn_key
 ret
 ASSERT $ <= 0xFCD0
 ORG 0xFD95
; Вместо «ld a,c / or a / ret z»: C = число отличий нового ключа (уже в jn_key) от текущего образа.
; Z — готовить не нужно (тот же образ или попадание во второй); NZ — готовить в освобождённую страницу.
jn_cache:
 ld a,c
 or a
 ret z
 ld hl,jn_key
 ld de,jn_key2
 ld b,5
jc_cmp:
 ld a,(de)
 cp (hl)
 jp nz,jc_diff
 inc hl
 inc de
 dec b
 jp nz,jc_cmp
jc_diff:
 push bc                    ; B = 0 — попадание
 ld hl,jn_old               ; прежний текущий становится вторым
 ld de,jn_key2
 ld b,5
 call jn_cp
 ld a,(jn_put_sp+2)         ; обмен страниц
 xor JOE_PAGE_XOR
 ld (jn_put_sp+2),a
 ld (jn_dest_read+2),a
 pop bc
 ld a,b
 or a
 ret
jn_cp:
 ld a,(hl)
 ld (de),a
 inc hl
 inc de
 dec b
 jp nz,jn_cp
 ret
 ASSERT $ <= 0xFDD0
 ASSERT (JOE_PICTURE2&255) == (JOE_PICTURE&255)
 ASSERT JOE_PICTURE2 >= ps_boot_source+LIVE_CODE_BYTES
 ASSERT JOE_CACHE_END <= ps_boot_source_end   ; окно внутри загрузочного источника при любой длине цепочки
