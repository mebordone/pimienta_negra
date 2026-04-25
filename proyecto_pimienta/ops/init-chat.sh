#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck disable=SC1091
source ./ops/lib/domain-env.sh
pimienta_domain_init .env

./ops/render-domain-config.sh

CERT_DIR="./data/prosody-certs"
mkdir -p "$CERT_DIR" ./data/prosody
STATE_FILE="./data/.node_domain"

pimienta_enforce_domain_state "$STATE_FILE" ./data/prosody ./data/prosody-certs

gen_cert() {
  local cn="$1"
  local key="$CERT_DIR/$cn.key"
  local crt="$CERT_DIR/$cn.crt"
  if [[ -f "$crt" && -f "$key" ]]; then
    return 0
  fi
  echo "Generando certificado autofirmado para $cn..."
  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$key" -out "$crt" -days 3650 \
    -subj "/CN=$cn" 2>/dev/null
  if [[ ! -f "$crt" || ! -f "$key" ]]; then
    echo "Error: no se pudo generar el certificado para $cn." >&2
    echo "  Verificá que openssl esté instalado y que el directorio $CERT_DIR sea escribible." >&2
    exit 1
  fi
  chmod 640 "$key" 2>/dev/null || true
}

for d in "$NODE_DOMAIN" "$XMPP_ACCOUNTS_DOMAIN" "$XMPP_CONFERENCE_DOMAIN"; do
  gen_cert "$d"
done

# UID/GID del usuario prosody en la imagen prosodyim/prosody (evita usermod UID 0 si data/prosody es root)
PROSODY_UID=100
PROSODY_GID=102
if docker info >/dev/null 2>&1; then
  docker run --rm \
    -v "$(pwd)/data/prosody:/d" \
    -v "$(pwd)/data/prosody-certs:/c" \
    alpine sh -c "chown -R ${PROSODY_UID}:${PROSODY_GID} /d /c && chmod 640 /c/*.key 2>/dev/null; chmod 644 /c/*.crt 2>/dev/null; true"
else
  echo "Aviso: Docker no disponible; asegurate de que data/prosody y data/prosody-certs pertenezcan al UID ${PROSODY_UID}." >&2
fi

pimienta_write_domain_state "$STATE_FILE"

echo "Listo. Certificados en $CERT_DIR"
echo "Levantá el stack con: docker compose up -d"
