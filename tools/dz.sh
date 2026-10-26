#!/bin/sh
# Дизассемблер из build/monty.skool: адреса A..B (hex, без $), по строке на метку (*), инструкции через «  »
awk -v a="$1" -v b="$2" '$0 ~ "^[@*cbstuw ]\\$"a" "{p=1} $0 ~ "^[@*cbstuw ]\\$"b" "{p=0} p' "$(dirname "$0")/../build/monty.skool" | grep -v '^;' | grep -v '^@' | sed 's/ *;.*$//' | paste -s -d'|' - | sed 's/|\*/\
*/g; s/|\([cbsw]\)\$/\
\1$/g; s/|/  /g'; echo
