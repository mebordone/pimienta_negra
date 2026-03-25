#!/usr/bin/env bash
# Primera puesta en marcha con wiki restaurada: init-chat → compose up → restore-wiki.
# No modifica /etc/hosts; ejecutá antes ./ops/setup-hosts.sh si hace falta.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== init-chat (certificados Prosody) ==="
./ops/init-chat.sh

echo "=== docker compose up -d ==="
docker compose up -d

echo "=== Esperando MariaDB ==="
for i in $(seq 1 90); do
  if docker compose exec -T db mysqladmin ping -h localhost -uroot -ppimienta_rosa --silent 2>/dev/null; then
    break
  fi
  if [[ "$i" -eq 90 ]]; then
    echo "Timeout esperando MariaDB." >&2
    exit 1
  fi
  sleep 1
done

echo "=== Esperando wiki (HTTP interno) ==="
for i in $(seq 1 60); do
  if docker compose exec -T wiki sh -c 'curl -sf http://127.0.0.1/ >/dev/null 2>&1'; then
    break
  fi
  if [[ "$i" -eq 60 ]]; then
    echo "Timeout esperando el contenedor wiki." >&2
    exit 1
  fi
  sleep 2
done

echo "=== restore-wiki ==="
./ops/restore-wiki.sh "$@"

echo ""
echo "Listo. Verificá con: ./ops/verify-stack.sh"
