#!/usr/bin/env bash
# Ejecuta shellcheck en ops/ y tests/ si el binario existe.
set -euo pipefail
if ! command -v shellcheck >/dev/null 2>&1; then
	echo "SKIP: shellcheck no instalado (opcional: apt install shellcheck)"
	exit 0
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# Solo `tests/`: los scripts en `ops/` tienen historia larga; ampliar a ops/ cuando convenga.
mapfile -t files < <(find tests -type f -name '*.sh' 2>/dev/null | sort)
[[ ${#files[@]} -gt 0 ]] || exit 0

echo "shellcheck en ${#files[@]} script(s) bajo tests/…"
shellcheck "${files[@]}"
echo "OK: shellcheck"
