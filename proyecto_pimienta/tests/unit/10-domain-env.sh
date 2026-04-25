#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source ./ops/lib/domain-env.sh

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

assert_eq() {
  local got="$1"
  local expected="$2"
  local msg="$3"
  [[ "$got" == "$expected" ]] || fail "$msg (got='$got', expected='$expected')"
}

if pimienta_validate_domain "invalido"; then
  fail "pimienta_validate_domain debería fallar con dominio inválido"
fi

if pimienta_validate_domain "flisol.test"; then
  fail "pimienta_validate_domain debería exigir dominio .local"
fi

pimienta_validate_domain "flisol.local"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
env_file="$tmp_dir/.env"
printf '%s\n' "NODE_DOMAIN=flisol.local" >"$env_file"
pimienta_domain_init "$env_file"
assert_eq "$NODE_DOMAIN" "flisol.local" "NODE_DOMAIN no cargó desde .env"
assert_eq "$XMPP_ACCOUNTS_DOMAIN" "accounts.flisol.local" "Dominio accounts incorrecto"
assert_eq "$XMPP_CONFERENCE_DOMAIN" "conference.flisol.local" "Dominio conference incorrecto"
assert_eq "$XMPP_ADMIN_JID" "admin@accounts.flisol.local" "JID admin incorrecto"

state_file="$tmp_dir/state"
mkdir -p "$tmp_dir/prosody" "$tmp_dir/certs"
pimienta_write_domain_state "$state_file"
printf 'otro.local\n' >"$state_file"
if pimienta_enforce_domain_state "$state_file" "$tmp_dir/prosody" "$tmp_dir/certs"; then
  fail "pimienta_enforce_domain_state debería fallar cuando cambia el dominio"
fi

printf 'pimienta.local\n' >"$state_file"
NODE_DOMAIN="pimienta.local"
pimienta_enforce_domain_state "$state_file" "$tmp_dir/prosody" "$tmp_dir/certs"

echo "OK: unit domain-env"
