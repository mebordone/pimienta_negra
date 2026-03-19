#!/usr/bin/env bash
set -euo pipefail

mysql_root_user="root"
mysql_root_pass="${MYSQL_ROOT_PASS:-pimienta_rosa}"
dest_dir="./backups/wiki/exports"
stop_wiki="true"

usage() {
  cat <<'EOF'
Uso:
  ./ops/backup-wiki.sh [--dest <dir>] [--mysql-root-pass <pass>] [--no-stop-wiki]

Opciones:
  --dest <dir>               Destino del .tar.gz (default: ./backups/wiki/exports)
  --mysql-root-pass <pass>  Password de root en MariaDB (default: $MYSQL_ROOT_PASS o pimienta_rosa)
  --no-stop-wiki             No detener el contenedor wiki antes del dump
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest)
      dest_dir="${2:-}"
      shift 2
      ;;
    --mysql-root-pass)
      mysql_root_pass="${2:-}"
      shift 2
      ;;
    --no-stop-wiki)
      stop_wiki="false"
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

mkdir -p "$dest_dir"

ensure_images_dir() {
  docker run --rm -u 0 -v "$(pwd)/data:/data" alpine sh -lc 'mkdir -p /data/mediawiki/images && chmod -R 777 /data/mediawiki/images'
}

ensure_images_dir

if [[ "$stop_wiki" == "true" ]]; then
  echo "Deteniendo wiki..."
  docker compose stop wiki >/dev/null 2>&1 || true
fi

db_cid="$(docker compose ps -q db)"
if [[ -z "$db_cid" ]]; then
  echo "No pude obtener el contenedor de MariaDB (servicio: db)." >&2
  exit 1
fi

network_name="$(docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' "$db_cid" 2>/dev/null || true)"
if [[ -z "$network_name" ]]; then
  echo "No pude detectar la red de Docker Compose." >&2
  exit 1
fi

tmp_dir="$(mktemp -d -t pimienta_wiki_backup.XXXXXX)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

mkdir -p "$tmp_dir/wiki/sql" "$tmp_dir/wiki/files/images"

out_ts="$(date +%Y%m%d-%H%M%S)"
out_file="${dest_dir}/wiki-backup-${out_ts}.tar.gz"

echo "Generando dump SQL (my_wiki)..."
docker run --rm \
  --network "$network_name" \
  -e MYSQL_PWD="$mysql_root_pass" \
  -v "$tmp_dir/wiki/sql:/out" \
  mariadb:10.5 \
  sh -lc "mysqldump -h db -u${mysql_root_user} --single-transaction --default-character-set=utf8mb4 my_wiki > /out/dump.sql"

echo "Copiando LocalSettings.php + imágenes..."
cp -f ./config/mediawiki/LocalSettings.php "$tmp_dir/wiki/files/LocalSettings.php"

# Si hay uploads persistentes, los incluimos sí o sí (para estética/contenido "exacto").
if [[ -d ./data/mediawiki/images ]] && [[ -n "$(ls -A ./data/mediawiki/images 2>/dev/null || true)" ]]; then
  cp -a ./data/mediawiki/images/. "$tmp_dir/wiki/files/images/"
else
  cp -a ./config/mediawiki/images/. "$tmp_dir/wiki/files/images/" 2>/dev/null || true
fi

cat > "$tmp_dir/manifest.json" <<EOF_MANIFEST
{
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "wiki": {
    "database": "my_wiki"
  }
}
EOF_MANIFEST

echo "Empaquetando backup: $out_file"
tar -C "$tmp_dir" -czf "$out_file" manifest.json wiki

echo "OK: backup wiki generado."
echo "$out_file"

# (La wiki queda detenida si el usuario lo pidió; levantala luego con docker compose up -d wiki)

