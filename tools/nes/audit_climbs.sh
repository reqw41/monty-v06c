#!/bin/sh
# Full decoded-map audit plus real-frame cap scenarios; reports stay in build/.
set -eu
cd "$(dirname "$0")/../.."
B=${B:-build/nes-blend80-sp-white-ladder}
export B
node tools/bench/nes-climb-audit.js
node tools/bench/nes-chain-landing.js
node tools/bench/nes-climb-caps.js
node tools/bench/nes-climb-live.js
node tools/bench/nes-palette-fixed.js
node tools/bench/nes-tile-palette.js
