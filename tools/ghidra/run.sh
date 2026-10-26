#!/bin/sh
# Ghidra headless по образу build/monty_entry.bin: tools/ghidra/run.sh [доп. входы hex...]
# Входы: 0000 (RST 0: ld sp,73B9h / jp 006Eh), 0038 (IM1: jp 20C6h), 2000 (вход из 66A8 после копирования ПЗУ);
# остальные — из покрытия (tools/cov_entries.py -> build/cov_entries.txt).
cd "$(dirname "$0")/../.." || exit 1
G=${GHIDRA_HEADLESS:-/opt/homebrew/Cellar/ghidra/12.1.4/libexec/support/analyzeHeadless}
mkdir -p build/ghidra_proj
EXTRA=$(cat build/cov_entries.txt 2>/dev/null)
"$G" build/ghidra_proj monty -deleteProject -import build/monty_entry.bin \
  -loader BinaryLoader -loader-baseAddr 0 -processor "z80:LE:16:default" \
  -scriptPath tools/ghidra \
  -preScript MontyEntries.java 0000 0038 2000 $EXTRA "$@" \
  -postScript MontyExport.java build/ghidra > build/ghidra_log.txt 2>&1
tail -1 build/ghidra_log.txt
