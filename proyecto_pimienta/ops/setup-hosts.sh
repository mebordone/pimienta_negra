#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck disable=SC1091
source ./ops/lib/domain-env.sh
pimienta_domain_init .env

HOSTNAME="$NODE_DOMAIN"
HOSTS_FILE="/etc/hosts"

if grep -qE "^\s*[^#].*\b${HOSTNAME}\b" "$HOSTS_FILE" 2>/dev/null; then
  echo "$HOSTNAME ya está configurado en $HOSTS_FILE. No se requieren cambios."
  exit 0
fi

echo ""
echo "Para que los servicios funcionen correctamente, es necesario"
echo "agregar '$HOSTNAME' al archivo $HOSTS_FILE de esta máquina."
echo ""
echo "Se va a agregar la siguiente línea:"
echo "  127.0.0.1  $HOSTNAME"
echo ""

read -rp "¿Continuar? [S/n] " respuesta
respuesta="${respuesta:-S}"

if [[ "$respuesta" =~ ^[Ss]$ ]]; then
  echo "127.0.0.1  $HOSTNAME" | sudo tee -a "$HOSTS_FILE" >/dev/null
  echo "Listo: $HOSTNAME apunta a 127.0.0.1."
else
  echo "No se modificó $HOSTS_FILE. Podés hacerlo manualmente:"
  echo "  echo \"127.0.0.1  $HOSTNAME\" | sudo tee -a $HOSTS_FILE"
fi
