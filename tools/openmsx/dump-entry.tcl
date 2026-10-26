# Снимки оригинала MSX для разбора: ОЗУ 64К (Main RAM), VRAM, регистры VDP и Z80, порт A8.
#   SDL_AUDIODRIVER=dummy SDL_VIDEODRIVER=dummy openmsx -machine MontyMSX -cart orig/msx/monty_msx.rom \
#     -command "set renderer none" -script tools/openmsx/dump-entry.tcl
# Снимки: entry — вход в 2000h (A8=D7, до переключения в DF); title 2,5 с; game16, game20 — игра.
# Вывод: build/runtime/<имя>_{ram,vram,vdp}.bin, <имя>_regs.txt; журнал записей в A8 (первые появления и счётчики) — a8.log.
# Ввод (как в старом сценарии): 3 с Enter, 6 и 9 с пробел, 12 с «1», 15 с пробел; ряд:маска матрицы.
set root [file normalize [file join [file dirname [info script]] .. ..]]
set out [file join $root build runtime]
file mkdir $out
set throttle off
set mute on
set a8log [open [file join $out a8.log] w]
array set a8seen {}
proc a8w {} {
    # уникальные пары (PC, значение); BIOS RDSLT/WRSLT из F380 не пишем
    set pc [reg pc]
    if {$pc >= 0xF380 && $pc < 0xF400} return
    set k [format "%04x %02x" $pc $::wp_last_value]
    if {[info exists ::a8seen($k)]} { incr ::a8seen($k); return }
    set ::a8seen($k) 1
    puts $::a8log [format "%.4f pc=%04x a8=%02x" [machine_info time] $pc $::wp_last_value]
}
debug set_watchpoint write_io 0xA8 {} a8w
proc wr {name data} {
    set f [open [file join $::out $name] wb]; fconfigure $f -translation binary
    puts -nonewline $f $data; close $f
}
proc snap {name} {
    wr ${name}_ram.bin  [debug read_block "Main RAM" 0 0x10000]
    wr ${name}_vram.bin [debug read_block VRAM 0 0x4000]
    wr ${name}_vdp.bin  [debug read_block "VDP regs" 0 8]
    wr ${name}_cpu.bin  [debug read_block memory 0 0x10000]
    set f [open [file join $::out ${name}_regs.txt] w]
    foreach r {pc sp af bc de hl ix iy af2 bc2 de2 hl2 i r im iff} { puts $f "$r [reg $r]" }
    puts $f "a8 [debug read ioports 0xA8]"
    close $f
}
# вход в игру: jp 2000h после копирования ПЗУ 400A-65B8 в ОЗУ 0000 (66A8)
set hit 0
debug set_bp 0x2000 {[pc_in_slot 3]} { if {!$::hit} { set ::hit 1; snap entry } }
proc press {row mask} { keymatrixdown $row $mask; after time 0.3 "keymatrixup $row $mask" }
foreach {t row mask} {3 7 0x80 6 8 0x01 9 8 0x01 12 0 0x02 15 8 0x01} { after time $t "press $row $mask" }
foreach {t name} {2.5 title 16 game16 20 game20} { after time $t "snap $name" }
after time 20.5 {
    foreach k [lsort [array names ::a8seen]] { puts $::a8log "# $k x$::a8seen($k)" }
    close $::a8log; quit
}
