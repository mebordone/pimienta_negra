#!/usr/bin/env bash
set -euo pipefail

dump_path="./backups/wiki/copia_wiki_real.sql"
backup_tar=""
tmp_dir=""
mysql_root_pass="${MYSQL_ROOT_PASS:-pimienta_rosa}"
mysql_root_user="root"
no_update_wiki="false"

ensure_images_dir() {
  # Usamos un contenedor efímero como root para evitar problemas de ownership en el host.
  docker run --rm -u 0 -v "$(pwd)/data:/data" alpine sh -lc 'mkdir -p /data/mediawiki/images && chmod -R 777 /data/mediawiki/images'
}

usage() {
  cat <<'EOF'
Uso:
  ./ops/restore-wiki.sh [--dump <ruta>] [--backup <tar.gz>] [--mysql-root-pass <pass>] [--no-update]

Opciones:
  --dump <ruta>           Ruta al dump SQL de la wiki (default: ./backups/wiki/copia_wiki_real.sql)
  --backup <tar.gz>      Backup wiki en .tar.gz (estructura wiki/sql/dump.sql + wiki/files/*)
  --mysql-root-pass <p>   Password de root en MariaDB (default: $MYSQL_ROOT_PASS o pimienta_rosa)
  --no-update             No ejecutar maintenance/update.php luego del restore

Nota: con --backup, si el tar incluye LocalSettings.php, se copia sobre
config/mediawiki/LocalSettings.php. El repo usa $wgServer = getenv('MW_SERVER')
para que coincida con el puerto del gateway; si el backup tiene $wgServer fijo,
ajustalo o alineá MW_SERVER en .env y recreá el contenedor wiki.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dump)
      dump_path="${2:-}"
      shift 2
      ;;
    --backup)
      backup_tar="${2:-}"
      shift 2
      ;;
    --mysql-root-pass)
      mysql_root_pass="${2:-}"
      shift 2
      ;;
    --no-update)
      no_update_wiki="true"
      shift 1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Opcion desconocida: $1" >&2
      usage
      exit 2
      ;;
  esac
done

cd "$(dirname "$0")/.."  # proyecto_pimienta/

if [[ -n "$backup_tar" ]]; then
  if [[ ! -f "$backup_tar" ]]; then
    echo "No existe el backup: $backup_tar" >&2
    exit 1
  fi

  tmp_dir="$(mktemp -d -t pimienta_wiki_restore.XXXXXX)"
  trap 'rm -rf "$tmp_dir"' EXIT

  echo "Extrayendo backup: $backup_tar"
  tar -xzf "$backup_tar" -C "$tmp_dir"

  # Convención esperada del tar:
  # wiki/sql/dump.sql
  # wiki/files/LocalSettings.php
  # wiki/files/images/...
  dump_path="$tmp_dir/wiki/sql/dump.sql"
  local_settings_src="$tmp_dir/wiki/files/LocalSettings.php"
  images_src="$tmp_dir/wiki/files/images"

  if [[ ! -f "$dump_path" ]]; then
    echo "No existe el dump dentro del backup (esperado: $dump_path)" >&2
    exit 1
  fi

  if [[ -f "$local_settings_src" ]]; then
    echo "Restaurando LocalSettings.php..."
    cp -f "$local_settings_src" ./config/mediawiki/LocalSettings.php
  fi

  ensure_images_dir
  if [[ -d "$images_src" ]]; then
    echo "Restaurando uploads/imágenes..."
    rm -rf ./data/mediawiki/images/*
    # Evitamos `cp -a` porque en algunos FS no se permiten preservar timestamps/metadata.
    cp -r "$images_src"/. ./data/mediawiki/images/
  fi
else
  if [[ ! -f "$dump_path" ]]; then
    echo "No existe el dump: $dump_path" >&2
    exit 1
  fi

  # Aseguramos que al menos el logo esperado exista en el directorio persistente.
  ensure_images_dir
  rm -rf ./data/mediawiki/images/* 2>/dev/null || true
  cp -f ./config/mediawiki/images/wiki_burbuja_135x135.png ./data/mediawiki/images/wiki_burbuja_135x135.png 2>/dev/null || true
fi

echo "Deteniendo wiki..."
docker compose stop wiki >/dev/null 2>&1 || true

echo "Preparando restauracion (filtrado del dump compatible con MariaDB 10.5)..."
tmp_sql="$(mktemp -t pimienta_wiki_only.XXXXXX.sql)"
tmp_pre="$(mktemp -t pimienta_wiki_pre.XXXXXX.sql)"
trap 'rm -f "$tmp_sql" "$tmp_pre"; [[ -n "${tmp_dir:-}" ]] && rm -rf "$tmp_dir"' EXIT

echo "Reiniciando base de datos my_wiki..."
docker compose exec -T db mysql -u"${mysql_root_user}" -p"${mysql_root_pass}" \
  -e "DROP DATABASE IF EXISTS my_wiki; CREATE DATABASE my_wiki DEFAULT CHARACTER SET utf8mb4 DEFAULT COLLATE utf8mb4_unicode_ci;"

echo "Preprocesando collation UCA (si existe) y filtrando bloque my_wiki..."
sed 's/utf8mb4_uca1400_ai_ci/utf8mb4_general_ci/g' "$dump_path" > "$tmp_pre"

# 1) Nos quedamos solo con las sentencias ejecutadas bajo `USE `my_wiki`;`
# 2) Evitamos importar tablas del esquema `mysql` que rompen en MariaDB 10.5
awk '
  BEGIN { keep=0 }
  $0 ~ /^USE `my_wiki`;/ { keep=1 }
  $0 ~ /^USE my_wiki;/ { keep=1 }
  $0 ~ /^USE `mysql`;/ { keep=0 }
  { if (keep) print }
' "$tmp_pre" > "$tmp_sql"

if [[ ! -s "$tmp_sql" ]]; then
  echo "Warning: el filtrado por USE my_wiki dejó el SQL vacío. Usando el SQL preprocesado completo." >&2
  cp "$tmp_pre" "$tmp_sql"
fi

cat "$tmp_sql" | docker compose exec -T db mysql -u"${mysql_root_user}" -p"${mysql_root_pass}" my_wiki

echo "Restauracion completada. Reiniciando wiki..."
docker compose up -d wiki >/dev/null

echo "Verificando contenido restaurado..."
pages_count="$(
  docker compose exec -T db mysql -u"${mysql_root_user}" -p"${mysql_root_pass}" -N -B \
    -e "USE my_wiki; SELECT COUNT(*) FROM page;"
)"

if [[ "$pages_count" -lt 1 ]]; then
  echo "Error: pagina count invalido ($pages_count). La restauracion no parece exitosa." >&2
  exit 1
fi

if [[ "$no_update_wiki" == "true" ]]; then
  echo "No se ejecuta update (flag --no-update)."
  exit 0
fi

echo "Ejecutando maintenance/update.php (quick) para caches/esquema..."
docker compose exec -T wiki php maintenance/run.php update.php --quick >/dev/null

echo "OK: wiki restaurada. Total de paginas: $pages_count"

