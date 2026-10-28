#!/bin/sh
# Full NES 256x240 native i8080 build. Original ROMs stay local and untracked.
set -eu
cd "$(dirname "$0")/../.."
for input in orig/nes/monty.nes build/monty.skool build/monty_entry.bin build/native/ram0.pk build/native/vram0.bin; do
  test -f "$input" || { echo "Missing native bootstrap input: $input (see docs/NES_NATIVE.md)" >&2; exit 1; }
done
mkdir -p build/native build/native_strict build/nes_full/vi53
if test ! -f build/nes/data/metasprites.json; then
  python3 tools/nes/extract.py orig/nes/monty.nes build/nes
fi
if test ! -f build/nes/music/music.json; then
  python3 tools/nes/music/extract_music.py orig/nes/monty.nes build/nes/music
fi
python3 tools/mknative.py --nes-full
python3 tools/nes/joe_native.py --height 23
python3 tools/nes/full_native.py
python3 tools/nes/full_video.py
python3 tools/nes/title_native.py
python3 tools/nes/music/to_vi53.py --report build/nes_full/vi53/conversion.json
(
  cd src/native
  ../../tools/sjasmplus --nologo --i8080 -DNES_STYLE -DNES_FULL --sym=../../build/native/monty.sym game.asm
  ../../tools/sjasmplus --nologo --i8080 -DSTRICT --sym=../../build/native_strict/monty.sym game.asm
)
B=${B:-build/nes-native}
mkdir -p "$B"
cp build/native/monty.bin build/native/monty.sym "$B/"
B="$B" node tools/bench/nes-full.js
B="$B" node tools/bench/nes-objects.js
B="$B" node tools/bench/nes-key-persistence.js
B="$B" node tools/bench/nes-msx-sword.js
B="$B" node tools/bench/nes-amulet-snake.js
B="$B" node tools/bench/nes-snake-video.js
B="$B" node tools/bench/nes-chain-exit.js
B="$B" node tools/bench/nes-laser-video.js
B="$B" node tools/bench/nes-death-paths.js
B="$B" node tools/bench/nes-death-video.js
B="$B" node tools/bench/nes-vase.js
B="$B" node tools/bench/nes-hud.js
B="$B" node tools/bench/nes-restart.js
B="$B" node tools/nes/music/test_vi53.js build/nes_full/vi53
cp "$B/monty.bin" rom/Monty-v06c-native.r0m
cp "$B/monty.bin" rom/Monty-v06c-native.c00

cp "$B/monty.bin" rom/Monty-v06c-native-nes2.r0m
if test "${BUILD_NES3:-0}" = 1; then
  (
    cd src/native
    ../../tools/sjasmplus --nologo --i8080 -DNES_JOE_3COLOR --sym=../../build/native/monty.sym game.asm
  )
  B3="$B-3color"
  mkdir -p "$B3"
  cp build/native/monty.bin build/native/monty.sym "$B3/"
  B="$B3" node tools/bench/nes-hud.js
  B="$B3" node tools/bench/nes-key-persistence.js
  B="$B3" node tools/bench/nes-amulet-snake.js
  B="$B3" node tools/bench/nes-snake-video.js
  B="$B3" node tools/bench/nes-chain-exit.js
  B="$B3" node tools/bench/nes-laser-video.js
  B="$B3" node tools/bench/nes-death-paths.js
  B="$B3" node tools/bench/nes-death-video.js
  B="$B3" node tools/bench/nes-vase.js
  B="$B3" node tools/bench/joe-selector.js
  B="$B3" node tools/bench/joe-poses.js
  cp "$B3/monty.bin" rom/Monty-v06c-native-nes3.r0m
  cp "$B/monty.bin" "$B/monty.sym" build/native/
fi
