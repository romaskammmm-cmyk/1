#!/usr/bin/env bash
# Сборка Windows EXE «Недостающее звено» [build-09]
# Требует: godot 4.4.1 + экспорт-шаблоны 4.4.1.stable в ~/.local/share/godot/export_templates/
set -euo pipefail

GODOT="${GODOT:-/opt/godot/godot}"
PROJ="$(cd "$(dirname "$0")/../project/missing_link" && pwd)"
OUT="${1:-$PROJ/builds/Nedostayushchee_Zveno.exe}"
BUILD="${ZVENO_BUILD:-$(date +%Y%m%d)}"

cd "$PROJ"
mkdir -p builds
"$GODOT" --headless --import --path . >/dev/null
ZVENO_BUILD="$BUILD" "$GODOT" --headless --path . --export-release "Windows Desktop" "$OUT"

echo "──"
ls -lh "$OUT"
echo "OK: $OUT"
