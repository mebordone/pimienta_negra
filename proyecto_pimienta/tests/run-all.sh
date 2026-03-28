#!/usr/bin/env bash
# Orquestador de tests: estáticos (compose, shellcheck) e integración HTTP.
# Ejecutar desde cualquier cwd; usa proyecto_pimienta como raíz del stack.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MODE="both"
for arg in "$@"; do
	case "$arg" in
	--static-only) MODE="static" ;;
	--integration-only) MODE="integration" ;;
	-h | --help)
		echo "Uso: $0 [--static-only | --integration-only]"
		echo "  Por defecto: estáticos + integración (requiere Docker arriba para integración)."
		exit 0
		;;
	esac
done

run_dir() {
	local label="$1"
	local dir="$2"
	[[ -d "$dir" ]] || return 0
	local f
	for f in "$dir"/*.sh; do
		[[ -e "$f" ]] || continue
		echo ""
		echo "=== ${label}: $(basename "$f") ==="
		bash "$f"
	done
}

if [[ "$MODE" == "static" || "$MODE" == "both" ]]; then
	run_dir "static" "$ROOT/tests/static"
fi

if [[ "$MODE" == "integration" || "$MODE" == "both" ]]; then
	run_dir "integration" "$ROOT/tests/integration"
fi

echo ""
echo "OK: suite de tests completada (${MODE})."
