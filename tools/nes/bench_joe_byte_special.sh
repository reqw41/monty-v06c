#!/bin/sh
# Isolated byte-type experiments. No production ROM or allocation is changed.
set -eu
cd "$(dirname "$0")/../.."
special_root=$(pwd)
before_dir=${B:-build/nes-physics-checked}
special_dir=${SPECIAL:-build/joe-byte-special}
for special_mode in transparent opaque transparent-first opaque-first; do
 python3 tools/nes/joe_byte_special.py --baseline "$before_dir" --output "$special_dir" --mode "$special_mode"
 (
  cd "$special_dir/$special_mode"
  "$special_root/tools/sjasmplus" --nologo --i8080 -DNES_JOE_3COLOR -DNES_JOE_BLEND80 -DNES_JOE_SP_RESTORE -DNES_LADDER_LOW -DNES_STABLE_COLORS -DNES_FULL --sym=monty.sym put.asm
 )
done
B="$before_dir" SPECIAL="$special_dir" node tools/bench/nes-joe-byte-special.js
