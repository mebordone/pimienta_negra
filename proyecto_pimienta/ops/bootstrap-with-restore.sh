#!/usr/bin/env bash
# Primera puesta en marcha con wiki restaurada: init-chat → compose up → restore-wiki.
# No modifica /etc/hosts; ejecutá antes ./ops/setup-hosts.sh si hace falta.
# Acceso desde otras máquinas en la LAN: ./ops/setup-lan-mdns.sh (Avahi) o ver LAN_MDNS en .env.example.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

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
if [[ "${LAN_MDNS:-0}" == "1" ]]; then
  echo "=== LAN_MDNS=1: anunciar pimienta*.local en la red (Avahi) ==="
  ./ops/setup-lan-mdns.sh --apply || echo "Aviso: setup-lan-mdns falló; ejecutalo a mano: ./ops/setup-lan-mdns.sh --apply" >&2
else
  echo "=== Acceso desde otros equipos en la misma Wi‑Fi/LAN ==="
  echo "Esta máquina suele resolver pimienta.local vía /etc/hosts (./ops/setup-hosts.sh)."
  echo "Otras PCs/celus: DNS del router, o en Linux con Avahi: ./ops/setup-lan-mdns.sh --apply"
  echo "Poné LAN_MDNS=1 en .env para ejecutar --apply automáticamente al terminar este script."
  echo "Pros/contras de cada opción: ./ops/setup-lan-mdns.sh --help"
fi

echo ""
echo "Listo. Verificá con: ./ops/verify-stack.sh"
