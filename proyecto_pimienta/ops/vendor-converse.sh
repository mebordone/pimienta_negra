#!/usr/bin/env bash
# Descarga Converse.js + locales (es/en) + libsignal para uso sin Internet.
# Ejecutar desde la máquina con red: ./ops/vendor-converse.sh
# Versión alineada con el paquete npm (jsDelivr).
set -euo pipefail

cd "$(dirname "$0")/.."
VER="${CONVERSE_VENDOR_VERSION:-12.0.0}"
DIST="https://cdn.jsdelivr.net/npm/converse.js@${VER}/dist"
SIG="https://cdn.conversejs.org/3rdparty/libsignal-protocol.min.js"

V="config/converse/vendor"
mkdir -p "$V/3rdparty" "$V/images/logo" "$V/locales/dayjs"

echo "Descargando Converse ${VER}..."
curl -fsSL "$DIST/converse.min.js" -o "$V/converse.min.js"
curl -fsSL "$DIST/converse.min.css" -o "$V/converse.min.css"
curl -fsSL "$DIST/emoji.json" -o "$V/emoji.json"
curl -fsSL "$DIST/images/logo/conversejs-filled.svg" -o "$V/images/logo/conversejs-filled.svg"
# Inglés suele ir embebido en el bundle; para español hacen falta estos chunks.
curl -fsSL "$DIST/locales/es-LC_MESSAGES-converse-po.js" -o "$V/locales/es-LC_MESSAGES-converse-po.js"
curl -fsSL "$DIST/locales/dayjs/es-js.js" -o "$V/locales/dayjs/es-js.js"
curl -fsSL "$DIST/locales/dayjs/en-js.js" -o "$V/locales/dayjs/en-js.js"

echo "Descargando libsignal (3rdparty)..."
curl -fsSL "$SIG" -o "$V/3rdparty/libsignal-protocol.min.js"

echo "OK: archivos en $V"
ls -la "$V/converse.min.js" "$V/converse.min.css" "$V/3rdparty/libsignal-protocol.min.js"
