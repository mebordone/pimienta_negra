#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# reset.sh — Limpia todo el estado de ejecución para volver a cero.
#
# Útil durante desarrollo: baja el stack, borra datos y bind mounts,
# dejando el proyecto listo para un bootstrap limpio.
#
# Preserva: .env, config/, backups/
# Borra:    contenedores, volúmenes Docker, data/, archivos/
#
# Uso:
#   ./ops/reset.sh            # reset estándar
#   ./ops/reset.sh --purge    # ídem + borra imágenes Docker descargadas
#
# Flujo de dev recomendado:
#   ./ops/reset.sh
#   ./ops/bootstrap-with-restore.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

cd "$(dirname "$0")/.."

PURGE=0
for arg in "$@"; do
  case "$arg" in
    --purge) PURGE=1 ;;
    *) echo "Uso: $0 [--purge]" >&2; exit 1 ;;
  esac
done

echo "╔══════════════════════════════════════════════════════╗"
echo "║        Pimienta Negra — reset de entorno             ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "Se borrarán:"
echo "  • Contenedores y volúmenes Docker del stack"
echo "  • data/  (filebrowser, mediawiki, prosody, prosody-certs)"
echo "  • archivos/  (contenido servido por FileBrowser)"
if [[ "$PURGE" -eq 1 ]]; then
  echo "  • Imágenes Docker del stack  (--purge)"
fi
echo ""
echo "Se preservarán:"
echo "  • .env"
echo "  • config/"
echo "  • backups/"
echo ""
read -rp "¿Seguro? Escribí 'si' para continuar: " confirm
[[ "$confirm" == "si" ]] || { echo "Cancelado."; exit 0; }

echo ""
echo "--- Bajando stack y borrando volúmenes Docker ---"
if [[ "$PURGE" -eq 1 ]]; then
  docker compose down -v --rmi all 2>/dev/null || true
else
  docker compose down -v 2>/dev/null || true
fi

echo ""
echo "--- Borrando datos de bind mounts ---"
sudo rm -rf \
  data/filebrowser \
  data/mediawiki \
  data/prosody \
  data/prosody-certs \
  archivos

echo ""
echo "--- Recreando directorios con permisos del usuario actual ---"
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_GROUP="$(id -gn "$TARGET_USER")"
sudo mkdir -p data archivos
sudo chown -R "${TARGET_USER}:${TARGET_GROUP}" data archivos
chmod u+rwx data archivos

echo ""
echo "═══════════════════════════════════════════════════════"
echo " Reset completo. Para levantar de nuevo:"
echo "   ./ops/bootstrap-with-restore.sh"
echo "═══════════════════════════════════════════════════════"
