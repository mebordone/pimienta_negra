#!/usr/bin/env bash
# Iconos de FileBrowser servidos por nginx (evita HEAD→404 del upstream).
set -euo pipefail
# shellcheck source=../lib/common.sh
# shellcheck disable=SC1091
source "$(dirname "$0")/../lib/common.sh"
pimienta_tests_init

path="/archivos/static/img/icons/favicon.svg"
code="$(pimienta_http_head_code "$path")"
[[ "$code" == "200" ]] || pimienta_fail "HEAD ${path} esperaba 200, obtuve ${code}"
code="$(pimienta_http_get_code "$path")"
[[ "$code" == "200" ]] || pimienta_fail "GET ${path} esperaba 200, obtuve ${code}"
echo "OK: HEAD/GET ${path} -> 200"
