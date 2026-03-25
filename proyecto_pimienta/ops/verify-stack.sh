#!/usr/bin/env bash
# Comprueba que el gateway responde como Pimienta (wiki / chat / archivos).
# Usa pimienta.local + --resolve hacia 127.0.0.1 (no depende de /etc/hosts).
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

PORT="${GATEWAY_HTTP_PORT:-80}"
HTTPS_PORT="${GATEWAY_HTTPS_PORT:-443}"
HOST="pimienta.local"
RESOLVE="${HOST}:${PORT}:127.0.0.1"
RESOLVE_HTTPS="${HOST}:${HTTPS_PORT}:127.0.0.1"
BODY="$(mktemp -t pimienta_verify.XXXXXX)"
trap 'rm -f "$BODY"' EXIT

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

warn_nginx_host() {
  echo "" >&2
  echo "Sugerencia: si ves la página «Welcome to nginx!» del sistema, el puerto ${PORT} no está" >&2
  echo "sirviendo el gateway de Docker. Comprobá quién escucha el puerto:" >&2
  echo "  ss -tlnp | grep ':${PORT} '" >&2
  echo "Si el 80 lo usa nginx del host, detenelo (p. ej. sudo systemctl stop nginx) o usá otro" >&2
  echo "puerto en .env: GATEWAY_HTTP_PORT=8088 y MW_SERVER=http://pimienta.local:8088" >&2
}

echo "=== docker compose ps ==="
docker compose ps -a || fail "docker compose ps falló"

curl_req() {
  local url="$1"
  shift
  curl -sS --connect-timeout 5 "$@" "$url"
}

# Código HTTP y cuerpo (sin seguir redirects) para diagnóstico
code_and_body() {
  local path="$1"
  curl_req "http://${HOST}:${PORT}${path}" \
    --resolve "$RESOLVE" \
    -o "$BODY" \
    -w "%{http_code}"
}

echo ""
echo "=== HTTP vía gateway (http://${HOST}:${PORT}) ==="

# Raíz: MediaWiki suele 301/302; seguimos hasta 200
root_final="$(curl -sS -o "$BODY" -w "%{http_code}" --resolve "$RESOLVE" \
  -L --max-redirs 5 "http://${HOST}:${PORT}/")"
if [[ "$root_final" != "200" ]]; then
  fail "GET / (tras redirects) esperaba 200, obtuve ${root_final}"
fi
if grep -q "Welcome to nginx!" "$BODY" 2>/dev/null; then
  warn_nginx_host
  fail "La respuesta en / parece la página por defecto de nginx del sistema (no el gateway del proyecto)."
fi
if ! grep -qiE 'mediawiki|mw-|Página principal|Main_Page|DOCTYPE' "$BODY"; then
  echo "ADVERTENCIA: el cuerpo de / no coincide claramente con MediaWiki; revisá manualmente." >&2
fi
echo "GET / (tras redirects) -> 200 OK"

code="$(code_and_body "/chat/")"
[[ "$code" == "301" ]] || [[ "$code" == "302" ]] || fail "GET /chat/ (HTTP) esperaba 301/302 a HTTPS, obtuve ${code}"
loc_https_chat="$(curl -sS -o /dev/null -w "%{redirect_url}" --resolve "$RESOLVE" \
  "http://${HOST}:${PORT}/chat/")"
[[ "$loc_https_chat" == https://* ]] || fail "GET /chat/ debería redirigir a HTTPS, Location: ${loc_https_chat}"
echo "GET http://${HOST}:${PORT}/chat/ -> ${code} -> ${loc_https_chat}"

code_https="$(curl -sS -k -o "$BODY" -w "%{http_code}" --resolve "$RESOLVE_HTTPS" \
  "https://${HOST}:${HTTPS_PORT}/chat/")"
[[ "$code_https" == "200" ]] || fail "GET /chat/ (HTTPS) esperaba 200, obtuve ${code_https}"
if ! grep -qiE 'DOCTYPE|converse|html' "$BODY" 2>/dev/null; then
  echo "ADVERTENCIA: el cuerpo de /chat/ (HTTPS) no parece HTML/Converse; revisá manualmente." >&2
fi
echo "GET https://${HOST}:${HTTPS_PORT}/chat/ -> 200 OK"

code="$(code_and_body "/archivos/")"
[[ "$code" == "200" ]] || fail "GET /archivos/ esperaba 200, obtuve ${code}"
echo "GET /archivos/ -> 200"

# Redirects sin barra final
loc_chat="$(curl -sS -o /dev/null -w "%{redirect_url}" --resolve "$RESOLVE" \
  "http://${HOST}:${PORT}/chat")"
code="$(curl -sS -o /dev/null -w "%{http_code}" --resolve "$RESOLVE" \
  "http://${HOST}:${PORT}/chat")"
[[ "$code" =~ ^30[12]$ ]] || fail "GET /chat esperaba 301/302, obtuve ${code}"
[[ "$loc_chat" == *"/chat/"* ]] || [[ "$loc_chat" == https://* ]] || fail "GET /chat Location debería apuntar a /chat/ o HTTPS, fue: ${loc_chat}"
echo "GET /chat -> ${code} -> ${loc_chat}"

loc_arch="$(curl -sS -o /dev/null -w "%{redirect_url}" --resolve "$RESOLVE" \
  "http://${HOST}:${PORT}/archivos")"
code="$(curl -sS -o /dev/null -w "%{http_code}" --resolve "$RESOLVE" \
  "http://${HOST}:${PORT}/archivos")"
[[ "$code" =~ ^30[12]$ ]] || fail "GET /archivos esperaba 301/302, obtuve ${code}"
[[ "$loc_arch" == *"/archivos/"* ]] || fail "GET /archivos Location debería apuntar a /archivos/, fue: ${loc_arch}"
echo "GET /archivos -> ${code} -> /archivos/"

if [[ -n "${MW_SERVER:-}" ]]; then
  echo ""
  echo "MW_SERVER=${MW_SERVER} (debe coincidir con host y puerto que usa el navegador)"
fi

echo ""
echo "OK: verificación del stack completada."
