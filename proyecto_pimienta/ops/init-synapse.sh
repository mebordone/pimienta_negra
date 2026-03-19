#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_PATH="./config/synapse/homeserver.yaml.template"
OUT_PATH="./data/synapse/homeserver.yaml"

SERVER_NAME="${SYNAPSE_SERVER_NAME:-AguaribayPI}"
PUBLIC_BASEURL="${SYNAPSE_PUBLIC_BASEURL:-http://pimienta.local:8008}"

DB_HOST="${SYNAPSE_DB_HOST:-db_matrix}"
DB_USER="${SYNAPSE_DB_USER:-synapse}"
DB_PASSWORD="${SYNAPSE_DB_PASSWORD:-pimienta_rosa}"
DB_NAME="${SYNAPSE_DB_NAME:-synapse_v1}"

REGISTRATION_SHARED_SECRET="${SYNAPSE_REGISTRATION_SHARED_SECRET:-}"
MACAROON_SECRET_KEY="${SYNAPSE_MACAROON_SECRET_KEY:-}"
FORM_SECRET="${SYNAPSE_FORM_SECRET:-}"

usage() {
  cat <<'EOF'
Uso:
  ./ops/init-synapse.sh

Variables de entorno (opcional):
  SYNAPSE_SERVER_NAME
  SYNAPSE_PUBLIC_BASEURL
  SYNAPSE_DB_HOST
  SYNAPSE_DB_USER
  SYNAPSE_DB_PASSWORD
  SYNAPSE_DB_NAME

  SYNAPSE_REGISTRATION_SHARED_SECRET
  SYNAPSE_MACAROON_SECRET_KEY
  SYNAPSE_FORM_SECRET
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

cd "$(dirname "$0")/.." # proyecto_pimienta/

if [[ ! -f "$TEMPLATE_PATH" ]]; then
  echo "No existe la plantilla: $TEMPLATE_PATH" >&2
  exit 1
fi

mkdir -p ./data/synapse ./data/postgres

# Permisividad para evitar errores al generar /data/homeserver.signing.key
chmod -R 777 ./data/synapse >/dev/null 2>&1 || true

gen_secret() {
  # 16 bytes => 32 hex chars
  openssl rand -hex 16 2>/dev/null || date +%s | sha256sum | awk '{print $1}' | head -c 32
}

if [[ -z "$REGISTRATION_SHARED_SECRET" ]]; then
  REGISTRATION_SHARED_SECRET="$(gen_secret)"
fi
if [[ -z "$MACAROON_SECRET_KEY" ]]; then
  MACAROON_SECRET_KEY="$(gen_secret)"
fi
if [[ -z "$FORM_SECRET" ]]; then
  FORM_SECRET="$(gen_secret)"
fi

tmp_out="$(mktemp -t homeserver.yaml.XXXXXX)"
cp "$TEMPLATE_PATH" "$tmp_out"

sed -i \
  -e "s|__SERVER_NAME__|${SERVER_NAME}|g" \
  -e "s|__PUBLIC_BASEURL__|${PUBLIC_BASEURL}|g" \
  -e "s|__REGISTRATION_SHARED_SECRET__|${REGISTRATION_SHARED_SECRET}|g" \
  -e "s|__MACAROON_SECRET_KEY__|${MACAROON_SECRET_KEY}|g" \
  -e "s|__FORM_SECRET__|${FORM_SECRET}|g" \
  -e "s|__DB_HOST__|${DB_HOST}|g" \
  -e "s|__DB_USER__|${DB_USER}|g" \
  -e "s|__DB_PASSWORD__|${DB_PASSWORD}|g" \
  -e "s|__DB_NAME__|${DB_NAME}|g" \
  "$tmp_out"

mkdir -p "$(dirname "$OUT_PATH")"
cp "$tmp_out" "$OUT_PATH"
rm -f "$tmp_out"

chmod 666 "$OUT_PATH" >/dev/null 2>&1 || true

echo "homeserver.yaml generado en: $OUT_PATH"
echo "Tip: luego ejecutá `docker compose up -d` para arrancar synapse."

