#!/bin/sh
# Полная сверка: три уровня со случайной игрой + обход комнат; вывод — по строке на прогон
S=$(cd "$(dirname "$0")" && pwd)
cd "$S/../.."
for lv in 1 2 3; do (VB=build/native_strict LV=$lv CHEAT=1 SYNC=0xA5D1 node tools/lockstep.js 3000 120 "$(node $S/rplan.js $lv 3000)" 2>&1 | grep -v "^ " | tail -2 | tr '\n' ' ' | sed "s/^/L$lv: /"; echo) & done
(VB=build/native_strict LV=1 CHEAT=1 SYNC=0xA5D1 node tools/lockstep.js 6500 120 "$(node $S/rplan.js 9 6500 tp)" 2>&1 | grep -v "^ " | tail -2 | tr '\n' ' ' | sed "s/^/tour: /"; echo) &
wait
