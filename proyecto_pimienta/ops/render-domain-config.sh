#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck disable=SC1091
source ./ops/lib/domain-env.sh
pimienta_domain_init .env

render_from_template() {
  local template="$1"
  local output="$2"
  local tmp
  tmp="$(mktemp)"
  sed \
    -e "s|__NODE_DOMAIN__|${NODE_DOMAIN}|g" \
    -e "s|__XMPP_ACCOUNTS_DOMAIN__|${XMPP_ACCOUNTS_DOMAIN}|g" \
    -e "s|__XMPP_CONFERENCE_DOMAIN__|${XMPP_CONFERENCE_DOMAIN}|g" \
    -e "s|__XMPP_ADMIN_JID__|${XMPP_ADMIN_JID}|g" \
    "$template" >"$tmp"

  if [[ ! -f "$output" ]] || ! cmp -s "$tmp" "$output"; then
    mv "$tmp" "$output"
    chmod 644 "$output"
    echo "Renderizado: $output"
  else
    rm -f "$tmp"
  fi
}

render_from_template ./config/nginx/default.conf.template ./config/nginx/default.conf
render_from_template ./config/prosody/prosody.cfg.lua.template ./config/prosody/prosody.cfg.lua
render_from_template ./config/converse/index.html.template ./config/converse/index.html
