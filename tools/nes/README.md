# Local NES asset extraction

Music, all nine SFX, standalone JS player, NSF and WAV extraction:
[`music/README.md`](music/README.md), detailed addresses in
[`docs/NES_MUSIC.md`](../../docs/NES_MUSIC.md).

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

Controller-only live verification (TASK_NES_ASSETS_2):

```sh
python3 tools/nes/live_capture.py orig/nes/monty.nes build/nes/live
python3 tools/nes/verify_live.py orig/nes/monty.nes build/nes build/nes/live
python3 tools/nes/verify_bat.py orig/nes/monty.nes build/nes/data/bat_verification.json
```

`live_capture.py` accepts optional profile names to replay a subset. Its Lua script
uses normal controller buttons only; all memory taps are observers. The long
`neighbours` route collects a key and visits rooms 1, 5, 4, 10, 11, 12; controller
guards wait for the laser to switch off, jump for the sword, and jump to the pole.
The guard conditions and actual buttons are saved in `plan.json` and `trace.tsv`.
No ROM, game RAM, pose or OAM injection occurs. `fire_burst` branches into the fire
in room 5; `rope_route` returns from room 6 to grab the rope facing left.

The capture retains the preceding DMA for the displayed bitmap and samples PPU
memory at the NMI return (`$C597`), after palette updates. Sampling the latest DMA
at `frame_done` would compare a screen with the following frame's actor positions;
sampling the palette at DMA would miss subsequent colour-cycle writes. Tap
handles are retained for the complete run. `.ram` is CPU RAM at that DMA, `.oam`
is the actual DMA payload, `.ppu` is PPU memory after its NMI updates, `.png` is
MAME's screen snapshot, `.pixels.z` is zlib-compressed native little-endian ARGB32
from `screen:pixels()`. `.shadow` is the following CPU-side OAM staging buffer,
kept for diagnosing the pipeline. `palette.json` is read from MAME's PPU palette
device, independently of the extracted sprites. The [MAME Lua device reference](https://docs.mamedev.org/luascript/ref-devices.html)
describes the bitmap, palette and snapshot APIs.

`verify_live.py` checks JSON parts against actual OAM, native sprite PNGs against
CHR pixels placed by that OAM, and the complete actor rectangles (including
transparent areas, background and other sprites) against visible screen pixels.
It models hardware sprite priority, the eight-sprites-per-scanline limit, flips,
clipping and PPU palette indices. It does not fit coordinates or infer colours
from expected sprites. `$58+s` is the *next* animation index after `$C3BB`; the
visible phase is identified by the actual `$34/$2E+s` metasprite pointer. `$1C+s`
may be FF while a frozen/current frame remains visible; both values are retained.

Results: `data/live_verification.json`, `data/live_coverage.md`, and
`live/joe_verified.png`. Missing frame references, screen/OAM mismatches or PNG
mismatches cause a nonzero exit. The report distinguishes observed directions
from the opposite views checked only by the older isolated ROM-writer test.
The fire effect forces direction 0 (the mirrored view); an unobserved right-facing
version must not be described as a live gameplay observation.
