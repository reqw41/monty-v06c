# Local NES asset extraction

Run from the repository root with Python 3.10+ and Pillow:

```sh
python3 tools/nes/extract.py orig/nes/monty.nes build/nes/
python3 tools/nes/verify.py orig/nes/monty.nes build/nes/
```

The extractor accepts the local 40,976-byte NES 2.0 NROM image, executes its original
room/palette subroutines without timing, and reads animation/metasprite tables.
It never edits the ROM or `src/native`. Main extraction needs only the NES ROM and
Pillow. `build/res/{sprites,tiles,colors}.bin`, `rooms_L1.json`, and
`build/monty_entry.bin`, when present, add MSX comparison sheets and mockups with
actual MSX geometry. Without these, `data/manifest.json` explicitly records the
fallback to a compressed NES layout. The report describes the full local run.

Independent MAME verification (no window):

```sh
python3 tools/nes/capture.py orig/nes/monty.nes build/nes/reference
python3 tools/nes/verify.py orig/nes/monty.nes build/nes/ --reference build/nes/reference
```

MAME runs the starting room normally, then a small **emulated-memory-only** main-loop
harness calls the original ROM subroutines for all 99 rooms with rendering/NMI
disabled. The cartridge file stays unchanged. The capture fails unless its
completion marker is written. Verification compares every field cell and every
relevant attribute/palette entry; only known animated tile phase differences are
normalised for the one normally running starting-room snapshot. The overlapping
HUD attribute quadrants are masked because the isolated draw excludes the HUD.
`reference/timing.tsv` records normal gameplay frame timings before the harness.

`disasm.py ROM [START_HEX [END_HEX]]` disassembles documented 6502 instructions;
linear output may include data and is not a control-flow analysis. `cpu.py` is an
untimed subroutine executor, not a complete NES emulator.

All dumped game graphics, room data, reference captures, and PNGs belong under the
ignored local `build/nes`. Do not publish the ROM or those assets. Source scripts
contain no extracted CHR/metasprite graphics. The RGB lookup is the frozen FCEUX
default palette (source URL in `assets.py` and generated `data/rom.json`).
