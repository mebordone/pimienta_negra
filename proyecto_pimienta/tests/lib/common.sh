#!/usr/bin/env bash
# Variables y helpers compartidos para tests de integración HTTP vía gateway.
# Uso: source este archivo desde scripts en tests/integration/ y llamar pimienta_tests_init.

_PIMIENTA_TESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pimienta_tests_init() {
	PIMIENTA_PROJECT_ROOT="$(cd "$_PIMIENTA_TESTS_LIB_DIR/../.." && pwd)"
	cd "$PIMIENTA_PROJECT_ROOT" || return 1

	if [[ -f .env ]]; then
		set -a
		# shellcheck disable=SC1091
		source .env
		set +a
	fi

	export PIMIENTA_HOST="${PIMIENTA_HOST:-${NODE_DOMAIN:-pimienta.local}}"
	export PIMIENTA_PORT="${GATEWAY_HTTP_PORT:-80}"
	export PIMIENTA_HTTPS_PORT="${GATEWAY_HTTPS_PORT:-443}"
	export PIMIENTA_RESOLVE="${PIMIENTA_HOST}:${PIMIENTA_PORT}:127.0.0.1"
	export PIMIENTA_RESOLVE_HTTPS="${PIMIENTA_HOST}:${PIMIENTA_HTTPS_PORT}:127.0.0.1"
}

# Código HTTP de HEAD (sin seguir redirects).
pimienta_http_head_code() {
	local path="$1"
	curl -sS --connect-timeout 5 -o /dev/null -w "%{http_code}" \
		--resolve "$PIMIENTA_RESOLVE" \
		-I "http://${PIMIENTA_HOST}:${PIMIENTA_PORT}${path}"
}

# Código HTTP de GET (sin seguir redirects).
pimienta_http_get_code() {
	local path="$1"
	curl -sS --connect-timeout 5 -o /dev/null -w "%{http_code}" \
		--resolve "$PIMIENTA_RESOLVE" \
		"http://${PIMIENTA_HOST}:${PIMIENTA_PORT}${path}"
}

pimienta_fail() {
	echo "ERROR: $*" >&2
	exit 1
}
