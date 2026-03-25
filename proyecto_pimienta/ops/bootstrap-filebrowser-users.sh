#!/usr/bin/env sh
set -eu

CONFIG="/config/settings.json"
DB="/database/filebrowser.db"

ADMIN_PASS="${FILEBROWSER_ADMIN_PASSWORD:?FILEBROWSER_ADMIN_PASSWORD is required}"
GUEST_USER="${FILEBROWSER_INVITADO_USERNAME:-pimienta}"
INV_PASS="${FILEBROWSER_INVITADO_PASSWORD:?FILEBROWSER_INVITADO_PASSWORD is required}"

if [ "${#ADMIN_PASS}" -lt 8 ] || [ "${#INV_PASS}" -lt 8 ]; then
  echo "FileBrowser: las contraseñas deben tener al menos 8 caracteres." >&2
  exit 1
fi

fb() {
  filebrowser "$@"
}

user_exists() {
  fb users ls -c "$CONFIG" -d "$DB" 2>/dev/null | awk -v u="$1" '$1 ~ /^[0-9]+$/ && $2 == u { f = 1 } END { exit(f ? 0 : 1) }'
}

if [ ! -f "$DB" ]; then
  echo "FileBrowser: inicializando base de datos..."
  fb config init \
    -c "$CONFIG" \
    -d "$DB" \
    --root /srv \
    -p 80 \
    -a "" \
    --log stdout \
    --minimumPasswordLength 8
fi

# Asegurar baseURL /archivos en la DB (puede diferir si el contenedor se inicializó sin settings.json).
echo "FileBrowser: asegurando baseURL /archivos..."
fb config set --baseURL /archivos -c "$CONFIG" -d "$DB" >/dev/null 2>&1 || true

echo "FileBrowser: asegurando usuario admin..."
if user_exists admin; then
  fb users update admin \
    -c "$CONFIG" \
    -d "$DB" \
    -p "$ADMIN_PASS" \
    --perm.admin \
    --perm.execute \
    --perm.create \
    --perm.rename \
    --perm.modify \
    --perm.delete \
    --perm.share \
    --perm.download
else
  fb users add admin "$ADMIN_PASS" \
    -c "$CONFIG" \
    -d "$DB" \
    --perm.admin \
    --perm.execute \
    --perm.create \
    --perm.rename \
    --perm.modify \
    --perm.delete \
    --perm.share \
    --perm.download
fi

echo "FileBrowser: asegurando usuario de acceso limitado (${GUEST_USER})..."
if user_exists "$GUEST_USER"; then
  fb users update "$GUEST_USER" \
    -c "$CONFIG" \
    -d "$DB" \
    -p "$INV_PASS" \
    --perm.admin=false \
    --perm.execute=false \
    --perm.create \
    --perm.rename=false \
    --perm.modify=false \
    --perm.delete=false \
    --perm.share=false \
    --perm.download
else
  fb users add "$GUEST_USER" "$INV_PASS" \
    -c "$CONFIG" \
    -d "$DB" \
    --perm.admin=false \
    --perm.execute=false \
    --perm.create \
    --perm.rename=false \
    --perm.modify=false \
    --perm.delete=false \
    --perm.share=false \
    --perm.download
fi

echo "FileBrowser: usuarios listos (admin + ${GUEST_USER})."
