#!/usr/bin/env bash
# Favicon global del gateway: HEAD y GET deben responder 200.
set -euo pipefail
# shellcheck source=../lib/common.sh
# shellcheck disable=SC1091
source "$(dirname "$0")/../lib/common.sh"
pimienta_tests_init

for path in /favicon.ico /favicon.png; do
	code="$(pimienta_http_head_code "$path")"
	[[ "$code" == "200" ]] || pimienta_fail "HEAD ${path} esperaba 200, obtuve ${code}"
	code="$(pimienta_http_get_code "$path")"
	[[ "$code" == "200" ]] || pimienta_fail "GET ${path} esperaba 200, obtuve ${code}"
	echo "OK: HEAD/GET ${path} -> 200"
done
