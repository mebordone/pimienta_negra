#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CERT_DIR="./data/prosody-certs"
mkdir -p "$CERT_DIR" ./data/prosody

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
  chmod 640 "$key" 2>/dev/null || true
}

for d in pimienta.local accounts.pimienta.local conference.pimienta.local; do
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

echo "Listo. Certificados en $CERT_DIR"
echo "Levantá el stack con: docker compose up -d"
