#!/usr/bin/env python3
"""Образ для разбора build/monty_entry.bin (64К): ОЗУ из снимка входа в 2000h (build/runtime/entry_ram.bin),
8000-BFFF — картридж (orig/msx/monty_msx.rom, смещение 4000). Совпадает с памятью модели tools/msx1.js на старте."""
ram = bytearray(open('build/runtime/entry_ram.bin', 'rb').read())
rom = open('orig/msx/monty_msx.rom', 'rb').read()
assert len(ram) == 0x10000 and len(rom) == 0x8000
ram[0x8000:0xc000] = rom[0x4000:0x8000]
assert ram[0:0x25af] == rom[0xa:0x25b9], 'ОЗУ 0000-25AE должно быть копией ПЗУ 400A-65B8'
open('build/monty_entry.bin', 'wb').write(ram)
print('build/monty_entry.bin', len(ram))
