; Cold game_init/unpack and the RAM snapshot run once, before any tile cache
; is built. Warm restart deliberately preserves 7200..7328 instead of
; unpacking it again. Store it directly in the startup-only E500 window,
; outside the relocated E000 builder and before the E680 skull installer.
 ORG 0xE500
 INCLUDE "cold_init.asm"
ram0_pk_end:
 ASSERT nes_title_spill_end <= game_init
 ASSERT ram0_pk_end <= nes_skull_source
