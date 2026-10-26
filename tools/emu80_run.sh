#!/bin/sh
# Запуск Monty в Emu80 (окно): rom/${ROM:-Monty-v06c.r0m} на платформе vector, порт MCP 19788.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP=~/projects/emu80v4/Emu80qt-mcp.app/Contents/MacOS
TMP="${TMPDIR:-/tmp}/monty_emu80"; mkdir -p "$TMP"
pkill -f "Emu80qt-mcp.*monty" 2>/dev/null || true
cp "$ROOT/rom/${ROM:-Monty-v06c.r0m}" "$TMP/monty.r0m"
cd "$APP"
QT_PLUGIN_PATH=/opt/homebrew/share/qt/plugins EMU80_MCP_PORT=19788 nohup ./Emu80qt-mcp --platform vector --run "$TMP/monty.r0m" >"$TMP/emu80.log" 2>&1 &
echo "Emu80 запущен: vector monty.r0m (MCP порт 19788)"
