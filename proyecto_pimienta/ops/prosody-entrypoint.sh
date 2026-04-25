#!/bin/sh
set -eu

CERT_DIR=/etc/prosody/certs
NODE_DOMAIN="${NODE_DOMAIN:-pimienta.local}"
ACCOUNTS_DOMAIN="accounts.${NODE_DOMAIN}"
CONFERENCE_DOMAIN="conference.${NODE_DOMAIN}"

for d in "$NODE_DOMAIN" "$ACCOUNTS_DOMAIN" "$CONFERENCE_DOMAIN"; do
  if [ ! -f "$CERT_DIR/$d.crt" ] || [ ! -f "$CERT_DIR/$d.key" ]; then
    echo "Prosody: faltan certificados en $CERT_DIR ($d). Ejecutá: ./ops/init-chat.sh" >&2
    exit 1
  fi
done

# Cuenta admin en accounts.${NODE_DOMAIN} (prosody aún no está en marcha)
if [ -n "${PROSODY_ADMIN_PASSWORD:-}" ]; then
  /entrypoint.sh register admin "$ACCOUNTS_DOMAIN" "$PROSODY_ADMIN_PASSWORD" 2>/dev/null || true
fi

exec /entrypoint.sh prosody -F
