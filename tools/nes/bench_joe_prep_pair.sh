#!/bin/sh
# Compare the complete two-row preparation against a frozen working release.
# The isolated E000 blob is never published as a ROM or run as the game.
set -eu
cd "$(dirname "$0")/../.."
pair_root=$(pwd)
before_dir=${B:-build/nes-physics-checked}
pair_dir=${PAIR:-build/joe-prep-pair}
python3 tools/nes/joe_prepare_pair.py --baseline "$before_dir" --output "$pair_dir"
(
 cd "$pair_dir"
 "$pair_root/tools/sjasmplus" --nologo --i8080 -DNES_JOE_3COLOR -DNES_JOE_BLEND80 -DNES_JOE_SP_RESTORE -DNES_LADDER_LOW -DNES_STABLE_COLORS -DNES_FULL --sym=monty.sym prep2.asm
)
B="$before_dir" PAIR="$pair_dir" node tools/bench/nes-joe-prep-pair.js
