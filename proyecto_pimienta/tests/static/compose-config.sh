#!/usr/bin/env bash
# Valida docker-compose.yml (YAML e interpolación de variables).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
echo "docker compose config (validación)…"
docker compose config >/dev/null
echo "OK: docker compose config"
