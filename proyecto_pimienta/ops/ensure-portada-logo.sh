#!/usr/bin/env bash
# Si la portada usa [[Archivo:Logo_Wiki_Pimienta.png]] pero solo restauraste el SQL,
# el registro en la base existe pero el PNG puede faltar en el árbol con hash de MediaWiki.
# Este script copia el logo versionado (misma burbuja que el encabezado) a la ruta esperada.
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="config/mediawiki/images/wiki_burbuja_135x135.png"
# Layout MD5(Logo_Wiki_Pimienta.png) → images/1/1f/ (MediaWiki file store)
DST_DIR="data/mediawiki/images/1/1f"
DST="$DST_DIR/Logo_Wiki_Pimienta.png"
if [[ ! -f "$SRC" ]]; then
  echo "ERROR: no existe $SRC" >&2
  exit 1
fi
mkdir -p "$DST_DIR"
if [[ ! -f "$DST" ]] || ! cmp -s "$SRC" "$DST"; then
  cp -f "$SRC" "$DST"
  echo "OK: logo portada en $DST (desde $SRC)"
else
  echo "OK: ya estaba $DST"
fi
