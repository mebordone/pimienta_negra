#!/usr/bin/env bash
# GET /config.json: JSON mínimo con node_name (landing).
set -euo pipefail
# shellcheck source=../lib/common.sh
# shellcheck disable=SC1091
source "$(dirname "$0")/../lib/common.sh"
pimienta_tests_init

BODY="$(mktemp -t pimienta_landing_cfg.XXXXXX)"
trap 'rm -f "$BODY"' EXIT

code="$(curl -sS --connect-timeout 5 --resolve "$PIMIENTA_RESOLVE" \
	-o "$BODY" -w "%{http_code}" \
	"http://${PIMIENTA_HOST}:${PIMIENTA_PORT}/config.json")"
[[ "$code" == "200" ]] || pimienta_fail "GET /config.json esperaba 200, obtuve ${code}"

if command -v python3 >/dev/null 2>&1; then
	python3 - "$BODY" <<'PY' || pimienta_fail "config.json no es JSON válido o falta node_name"
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    d = json.load(f)
if not isinstance(d.get("node_name"), str) or not d["node_name"].strip():
    sys.exit("node_name debe ser string no vacío")
PY
else
	grep -q '"node_name"' "$BODY" || pimienta_fail "config.json sin clave node_name"
fi

echo "OK: GET /config.json (node_name presente)"
