#!/bin/sh
set -eu

CERT_DIR=/etc/prosody/certs
for d in pimienta.local accounts.pimienta.local conference.pimienta.local; do
  if [ ! -f "$CERT_DIR/$d.crt" ] || [ ! -f "$CERT_DIR/$d.key" ]; then
    echo "Prosody: faltan certificados en $CERT_DIR ($d). Ejecutá: ./ops/init-chat.sh" >&2
    exit 1
  fi
done

# Cuenta admin en accounts.pimienta.local (prosody aún no está en marcha)
if [ -n "${PROSODY_ADMIN_PASSWORD:-}" ]; then
  /entrypoint.sh register admin accounts.pimienta.local "$PROSODY_ADMIN_PASSWORD" 2>/dev/null || true
fi

exec /entrypoint.sh prosody -F
