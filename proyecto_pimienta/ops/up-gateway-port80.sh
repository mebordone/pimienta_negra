#!/usr/bin/env bash
# Tras liberar el puerto 80 (nginx del sistema), levanta el gateway y corre verify-stack.sh.
set -euo pipefail

cd "$(dirname "$0")/.."

out="$(docker compose up -d gateway 2>&1)" || {
  echo "$out"
  if echo "$out" | grep -qE 'address already in use|failed to bind'; then
    echo "" >&2
    echo "El puerto 80 está ocupado (suele ser nginx instalado en el host)." >&2
    echo "Ejecutá en tu terminal:" >&2
    echo "  sudo systemctl stop nginx" >&2
    echo "  sudo systemctl disable nginx" >&2
    echo "Luego volvé a ejecutar: ./ops/up-gateway-port80.sh" >&2
  fi
  exit 1
}
echo "$out"
sleep 1
exec ./ops/verify-stack.sh
