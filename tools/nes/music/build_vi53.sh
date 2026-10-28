#!/bin/sh
# Existing native bootstrap inputs (ram0.pk) and music.json are prerequisites.
set -eu
cd "$(dirname "$0")/../../.."
mkdir -p build/native build/native_strict build/nes/music/vi53
test -f build/native/ram0.pk || { echo 'First create build/native/ram0.pk using the native build instructions.' >&2; exit 1; }
python3 tools/nes/music/to_vi53.py "${1:-build/nes/music/music.json}"
(
  cd src/native
  ../../tools/sjasmplus --nologo --i8080 --sym=../../build/native/monty.sym game.asm
  ../../tools/sjasmplus --nologo --i8080 -DSTRICT --sym=../../build/native_strict/monty.sym game.asm
)
node tools/nes/music/test_vi53.js
node tools/nes/music/render_vi53.js build/nes/music/vi53
cp build/native/monty.bin rom/Monty-v06c-native.r0m
cp build/native/monty.bin rom/Monty-v06c-native.c00
