#!/usr/bin/env bash
# Delega en el smoke test existente del repo (sin duplicar lógica).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
exec ./ops/verify-stack.sh
