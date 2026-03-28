#!/usr/bin/env bash
# Espera a que MediaWiki responda 200 en /wiki/ vía gateway (útil en CI tras docker compose up).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
	set -a
	# shellcheck disable=SC1091
	source .env
	set +a
fi

PORT="${GATEWAY_HTTP_PORT:-80}"
HOST="pimienta.local"
RESOLVE="${HOST}:${PORT}:127.0.0.1"
MAX_SEC="${PIMIENTA_WAIT_MAX_SEC:-180}"
INTERVAL="${PIMIENTA_WAIT_INTERVAL:-3}"

echo "Esperando GET http://${HOST}:${PORT}/wiki/ (máx ${MAX_SEC}s, cada ${INTERVAL}s)…"
elapsed=0
while [[ "$elapsed" -lt "$MAX_SEC" ]]; do
	code="$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 5 \
		--resolve "$RESOLVE" \
		-L --max-redirs 10 \
		"http://${HOST}:${PORT}/wiki/" || true)"
	if [[ "$code" == "200" ]]; then
		echo "OK: wiki respondió 200 en /wiki/ (gateway listo para MediaWiki)"
		exit 0
	fi
	echo "  intento: código ${code}, esperando… (${elapsed}s)"
	sleep "$INTERVAL"
	elapsed=$((elapsed + INTERVAL))
done

echo "ERROR: timeout esperando 200 en http://${HOST}:${PORT}/wiki/" >&2
exit 1
