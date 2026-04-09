#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Primer arranque de Pimienta Negra. Hace todo en un solo comando:
#   1. Carga .env
#   2. Genera certificados Prosody y ajusta permisos (init-chat)
#   3. Levanta el stack (docker compose up -d)
#   4. Espera MariaDB
#   5. Restaura la wiki (import SQL; con BD vacía MediaWiki responde 500 hasta este paso)
#   6. Espera HTTP 200 en el contenedor wiki (tras restore)
#   7. (Si LAN_MDNS=1 en .env) Instala/reinicia servicio systemd pimienta-mdns para que
#      pimienta*.local resuelva en la Wi‑Fi (mDNS); el runner re-detecta la IP periódicamente.
#
# Uso:
#   ./ops/bootstrap-with-restore.sh [opciones de restore-wiki.sh]
#
# Variables clave (.env):
#   MW_SERVER             Opcional. Vacío = wiki usa el host de la petición (IP o .local).
#   GATEWAY_HTTP_PORT     Puerto del nginx en host   (default: 80)
#   FILEBROWSER_ADMIN_PASSWORD / FILEBROWSER_INVITADO_USERNAME / FILEBROWSER_INVITADO_PASSWORD
#   PROSODY_ADMIN_PASSWORD
#   LAN_MDNS=1            Instalar servicio Avahi para acceso desde otros equipos LAN
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

cd "$(dirname "$0")/.."

# ── Cargar .env ───────────────────────────────────────────────────────────────
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
else
  echo "Aviso: no existe .env. Copiá .env.example a .env y editá las contraseñas." >&2
  echo "  cp .env.example .env && nano .env" >&2
  echo ""
fi

# ── 1. Certificados Prosody ───────────────────────────────────────────────────
echo "=== [1/5] Certificados Prosody (init-chat) ==="
./ops/init-chat.sh

# ── 1b. Bind mounts FileBrowser: crear dirs y asignar UID 1000 antes de montar ─
echo ""
echo "=== [1b] Preparando directorios de bind mounts (FileBrowser UID 1000) ==="
mkdir -p data/filebrowser archivos
sudo chown -R 1000:1000 data/filebrowser archivos

# ── 2. Levantar stack ────────────────────────────────────────────────────────
echo ""
echo "=== [2/5] docker compose up -d ==="
docker compose up -d

# ── 3. Esperar MariaDB ───────────────────────────────────────────────────────
echo ""
echo "=== [3/5] Esperando MariaDB ==="
for i in $(seq 1 90); do
  if docker compose exec -T db mysqladmin ping -h localhost -uroot -p"${MYSQL_ROOT_PASS:-pimienta_rosa}" --silent 2>/dev/null; then
    echo "MariaDB lista."
    break
  fi
  if [[ "$i" -eq 90 ]]; then
    echo "Timeout esperando MariaDB." >&2; exit 1
  fi
  printf "."; sleep 1
done

# ── 4. Restaurar wiki (antes del check HTTP: BD vacía → 500 en /) ────────────
echo ""
echo "=== [4/5] restore-wiki ==="
./ops/restore-wiki.sh "$@"

echo ""
echo "=== Esperando wiki (HTTP interno, tras restore) ==="
for i in $(seq 1 60); do
  if docker compose exec -T wiki sh -c 'curl -sf http://127.0.0.1/ >/dev/null 2>&1'; then
    echo "Wiki lista."
    break
  fi
  if [[ "$i" -eq 60 ]]; then
    echo "Timeout esperando el contenedor wiki tras restore." >&2; exit 1
  fi
  printf "."; sleep 2
done

# ── 5. Acceso LAN (Avahi) ────────────────────────────────────────────────────
echo ""
echo "=== [5/5] Acceso desde la LAN ==="
if [[ "${LAN_MDNS:-0}" == "1" ]]; then
  echo "LAN_MDNS=1 → instalando servicio systemd para pimienta*.local en la Wi‑Fi..."
  if ./ops/setup-lan-mdns.sh --install-service; then
    echo "Acceso LAN configurado y persistente."
  else
    echo "Aviso: no se pudo instalar el servicio Avahi. Ejecutá a mano:" >&2
    echo "  sudo apt install avahi-daemon avahi-utils" >&2
    echo "  ./ops/setup-lan-mdns.sh --install-service" >&2
  fi
else
  echo "pimienta.local solo resuelve en esta máquina."
  echo "Para acceso desde celulares u otras PCs en la misma Wi‑Fi:"
  echo "  1) Agregá LAN_MDNS=1 en .env y volvé a correr este script, o bien:"
  echo "  2) ./ops/setup-lan-mdns.sh --install-service  (instala servicio persistente)"
  echo "  Más opciones: ./ops/setup-lan-mdns.sh --help"
fi

# ── Verificación final ───────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo " Listo. Verificá con:  ./ops/verify-stack.sh"
if [[ -n "${MW_SERVER:-}" ]]; then
  MW_BASE="$MW_SERVER"
else
  MW_BASE="http://pimienta.local (o http://<IP-LAN> — mismo host en barra si MW_SERVER vacío)"
fi
CHAT_HINT="https://pimienta.local/chat/ (o https://<IP-LAN>/chat/ — mismo host que el gateway)"
echo " Landing:  ${MW_BASE}/"
echo " Wiki:     ${MW_BASE}/wiki/"
echo " Chat:     ${CHAT_HINT}   (HTTPS — requerido en muchos navegadores/celulares)"
echo " Archivos: mismo host + /archivos/"
echo "═══════════════════════════════════════════════════════"
