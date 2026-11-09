#!/bin/sh
# Русская версия: титры на титуле и «КОНЕЦ ИГРЫ». Генерирует титул с RUS=1, собирает с -DRUS,
# затем возвращает обычные сгенерированные файлы. Использование: sh tools/nes/build_rus.sh build/rus rom/<имя>.r0m
set -eu
cd "$(dirname "$0")/../.."
out=${1:-build/rus}
rom=${2:-}
trap 'python3 tools/nes/title_native.py >/dev/null' EXIT
RUS=1 python3 tools/nes/title_native.py >/dev/null
DEFS=-DRUS sh tools/nes/quick_build.sh "$out"
if [ -n "$rom" ]; then python3 tools/nes/build_splash.py --build "$out" --output "$rom" --quick | tail -1 | cut -c1-60; fi
