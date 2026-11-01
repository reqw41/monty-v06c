#!/bin/sh
# Дифференциальные проверки физики против исходного кода NES. Использование: B=build/quick sh tools/nes/diff_audits.sh [walk]
set -eu
cd "$(dirname "$0")/../.."
B=${B:-build/quick}
for g in physics_ledge_reference physics_wall_reference physics_wall2_reference physics_ropejump_reference physics_belt_reference physics_wall3_reference physics_walljump_reference; do python3 tools/nes/$g.py >/dev/null; done
for n in ledge wall wall2 ropejump; do
  IGNORE_DEATH=1 B=$B VERIFY=1 REF=build/nes-physics-audit/$n-reference.json OUT=build/nes-physics-audit/$n-native.json node tools/bench/nes-physics-audit.js | tail -1 | cut -c1-90
done
# тонкие плитки/потолки и прыжки в стены реальных комнат: известные расхождения только у лент (см. docs/BUGS.md)
for n in wall3 walljump; do
  IGNORE_DEATH=1 B=$B REF=build/nes-physics-audit/$n-reference.json OUT=build/nes-physics-audit/$n-native.json node tools/bench/nes-physics-audit.js | tail -1 | cut -c1-90
done
# ленты: известное расхождение — остановка у стены на 1 точку дальше (см. docs/BUGS.md)
IGNORE_DEATH=1 B=$B REF=build/nes-physics-audit/belt-reference.json OUT=build/nes-physics-audit/belt-native.json node tools/bench/nes-physics-audit.js | tail -1 | cut -c1-90
if [ "${1:-}" = walk ]; then
  python3 tools/nes/physics_walk_reference.py 8 | tail -1
  IGNORE_DEATH=1 B=$B REF=build/nes-physics-audit/walk-reference.json OUT=build/nes-physics-audit/walk-native.json node tools/bench/nes-physics-audit.js | tail -1 | cut -c1-90
fi
