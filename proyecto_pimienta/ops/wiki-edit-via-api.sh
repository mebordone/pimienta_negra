#!/usr/bin/env bash
# Edita una página de la wiki usando la Action API de MediaWiki (action=edit).
#
# Requisitos:
#   - Stack levantado (docker compose).
#   - Credenciales del usuario administrador de la wiki (por defecto «Admin»).
#
# URL de la API:
#   Por defecto: http://127.0.0.1:8080 (mapeo wiki 8080:80 del compose).
#   Podés forzar con WIKI_API_BASE, p. ej. http://<NODE_DOMAIN> si el gateway
#   enruta /api.php a MediaWiki (según tu nginx).
#
# Variables de entorno:
#   MEDIAWIKI_ADMIN_PASSWORD  (obligatoria) contraseña del usuario wiki
#   MEDIAWIKI_ADMIN_USER      (opcional, default: Admin)
#   WIKI_API_BASE             (opcional, default: http://127.0.0.1:8080)
#
# Uso:
#   MEDIAWIKI_ADMIN_PASSWORD='tu_clave' ./ops/wiki-edit-via-api.sh "Página principal" contenido.wiki
#   echo '== Título ==' | MEDIAWIKI_ADMIN_PASSWORD='tu_clave' ./ops/wiki-edit-via-api.sh "Página principal" -
#
# Resumen de edición (opcional):
#   WIKI_EDIT_SUMMARY='Actualizo sección X' MEDIAWIKI_ADMIN_PASSWORD='…' ./ops/wiki-edit-via-api.sh …

set -euo pipefail

cd "$(dirname "$0")/.."

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Edita una página vía Action API de MediaWiki (action=edit).

Variables:
  MEDIAWIKI_ADMIN_PASSWORD  obligatoria
  MEDIAWIKI_ADMIN_USER      opcional (default: Admin)
  WIKI_API_BASE             opcional (default: http://127.0.0.1:8080)
  WIKI_EDIT_SUMMARY         opcional (resumen del cambio)

Uso:
  MEDIAWIKI_ADMIN_PASSWORD='clave' ./ops/wiki-edit-via-api.sh "Página principal" archivo.wiki
  echo '== X ==' | MEDIAWIKI_ADMIN_PASSWORD='clave' ./ops/wiki-edit-via-api.sh "Página principal" -
EOF
  exit 0
fi

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

user="${MEDIAWIKI_ADMIN_USER:-Admin}"
pass="${MEDIAWIKI_ADMIN_PASSWORD:?Definí MEDIAWIKI_ADMIN_PASSWORD (contraseña del usuario wiki, p. ej. Admin).}"
base="${WIKI_API_BASE:-http://127.0.0.1:8080}"
summary="${WIKI_EDIT_SUMMARY:-Edición vía Action API (ops/wiki-edit-via-api.sh)}"

if [[ $# -lt 2 ]]; then
  echo "Uso: MEDIAWIKI_ADMIN_PASSWORD=… $0 <título_página> <archivo.wiki|->" >&2
  echo "     $0 --help" >&2
  exit 2
fi

title="$1"
src="$2"

if [[ "$src" == "-" ]]; then
  text="$(cat)"
else
  text="$(cat -- "$src")"
fi

cj="$(mktemp)"
tmpf="$(mktemp)"
trap 'rm -f "$cj" "$tmpf"' EXIT
printf '%s' "$text" >"$tmpf"

logintoken="$(curl -sS -G "${base}/api.php" \
  --data-urlencode 'action=query' \
  --data-urlencode 'meta=tokens' \
  --data-urlencode 'type=login' \
  --data-urlencode 'format=json' |
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d['query']['tokens']['logintoken'])")"

login_json="$(curl -sS -c "$cj" -b "$cj" -X POST "${base}/api.php" \
  --data-urlencode 'action=login' \
  --data-urlencode 'format=json' \
  --data-urlencode "lgname=${user}" \
  --data-urlencode "lgpassword=${pass}" \
  --data-urlencode "lgtoken=${logintoken}")"

python3 -c "import json,sys; d=json.loads(sys.argv[1]); r=d.get('login',{}).get('result'); sys.exit(0 if r=='Success' else 1)" "$login_json" || {
  echo "Fallo login en la API (revisá usuario, contraseña y WIKI_API_BASE=${base}):" >&2
  echo "$login_json" >&2
  exit 1
}

csrftoken="$(curl -sS -b "$cj" -G "${base}/api.php" \
  --data-urlencode 'action=query' \
  --data-urlencode 'meta=tokens' \
  --data-urlencode 'format=json' |
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d['query']['tokens']['csrftoken'])")"

resp="$(curl -sS -b "$cj" -X POST "${base}/api.php" \
  -F "action=edit" \
  -F "format=json" \
  -F "title=${title}" \
  -F "token=${csrftoken}" \
  -F "summary=${summary}" \
  -F "text=<${tmpf}")"

python3 -c "import json,sys; d=json.loads(sys.argv[1])
if 'error' in d:
  raise SystemExit('error: ' + json.dumps(d['error'], ensure_ascii=False))
ed = d.get('edit')
if not ed or ed.get('result') != 'Success':
  raise SystemExit('respuesta inesperada: ' + json.dumps(d, ensure_ascii=False))
" "$resp" || {
  echo "$resp" >&2
  exit 1
}

echo "OK: página «${title}» actualizada vía API (${base})."
