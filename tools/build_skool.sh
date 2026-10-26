#!/bin/sh
# src/monty.ctl -> build/monty.skool, build/monty_skool.asm, build/html/; проверка побайтной пересборки
cd "$(dirname "$0")/.." || exit 1
V=tools/.venv/bin
$V/sna2skool.py -H -o 0 -c src/monty.ctl build/monty_entry.bin > build/monty.skool 2>/dev/null || exit 1
$V/skool2bin.py -i build/monty.skool build/skool.bin >/dev/null 2>&1 || exit 1
cmp -s build/skool.bin build/monty_entry.bin && echo "skool: пересборка IDENTICAL" || { echo "skool: РАСХОЖДЕНИЕ"; exit 1; }
$V/skool2asm.py -H build/monty.skool > build/monty_skool.asm 2>/dev/null
$V/skool2html.py -q -d build/html build/monty.skool >/dev/null 2>&1 && echo "html: build/html/monty/index.html"
