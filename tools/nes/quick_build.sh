#!/bin/sh
# Быстрая сборка рабочего образа (как build_joe_blend.sh с LADDER_LOW=1) без длинных проверок.
# Использование: sh tools/nes/quick_build.sh [каталог результата, по умолчанию build/quick]
set -eu
cd "$(dirname "$0")/../.."
out=${1:-build/quick}
mkdir -p "$out" build/native
python3 tools/nes/object_colors.py >/dev/null
(cd src/native && ../../tools/sjasmplus --nologo --i8080 -DNES_JOE_3COLOR -DNES_JOE_BLEND80 -DNES_JOE_SP_RESTORE -DNES_LADDER_LOW -DNES_STABLE_COLORS ${DEFS:-} --sym=../../build/native/monty.sym game.asm | tail -1)
cp build/native/monty.bin build/native/monty.sym "$out/"
