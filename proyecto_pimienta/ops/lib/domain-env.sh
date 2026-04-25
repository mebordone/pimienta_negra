#!/usr/bin/env bash

# Carga y valida el dominio principal del nodo.
# Variables derivadas exportadas:
# - NODE_DOMAIN
# - XMPP_ACCOUNTS_DOMAIN
# - XMPP_CONFERENCE_DOMAIN
# - XMPP_ADMIN_JID

pimienta_load_env() {
  local env_file="${1:-.env}"
  if [[ -f "$env_file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi
}

pimienta_validate_domain() {
  local domain="${1:-}"
  if [[ -z "$domain" ]]; then
    echo "NODE_DOMAIN no puede estar vacío." >&2
    return 1
  fi
  if [[ ! "$domain" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$ ]]; then
    echo "NODE_DOMAIN inválido: '$domain'." >&2
    return 1
  fi
  if [[ "$domain" != *.local ]]; then
    echo "NODE_DOMAIN debe terminar en .local para este despliegue LAN: '$domain'." >&2
    return 1
  fi
}

pimienta_domain_init() {
  pimienta_load_env "${1:-.env}"
  export NODE_DOMAIN="${NODE_DOMAIN:-pimienta.local}"
  pimienta_validate_domain "$NODE_DOMAIN"
  export XMPP_ACCOUNTS_DOMAIN="accounts.${NODE_DOMAIN}"
  export XMPP_CONFERENCE_DOMAIN="conference.${NODE_DOMAIN}"
  export XMPP_ADMIN_JID="admin@${XMPP_ACCOUNTS_DOMAIN}"
}

pimienta_dir_has_content() {
  local dir="$1"
  [[ -d "$dir" ]] || return 1
  shopt -s nullglob dotglob
  local entries=("$dir"/*)
  shopt -u nullglob dotglob
  [[ ${#entries[@]} -gt 0 ]]
}

pimienta_write_domain_state() {
  local state_file="$1"
  mkdir -p "$(dirname "$state_file")"
  printf '%s\n' "$NODE_DOMAIN" >"$state_file"
}

pimienta_enforce_domain_state() {
  local state_file="$1"
  shift
  local dirs=("$@")

  if [[ -f "$state_file" ]]; then
    local existing
    existing="$(tr -d '[:space:]' <"$state_file")"
    if [[ -n "$existing" && "$existing" != "$NODE_DOMAIN" ]]; then
      echo "Error: instalación inicializada con NODE_DOMAIN=$existing." >&2
      echo "Este proyecto no soporta cambio de dominio en caliente." >&2
      echo "Hacé instalación limpia (por ejemplo ./ops/reset.sh) y volvé a ejecutar bootstrap." >&2
      return 1
    fi
    return 0
  fi

  local has_data=0
  local dir
  for dir in "${dirs[@]}"; do
    if pimienta_dir_has_content "$dir"; then
      has_data=1
      break
    fi
  done

  # Compatibilidad con instalaciones previas sin archivo de estado.
  if [[ "$has_data" -eq 1 && "$NODE_DOMAIN" != "pimienta.local" ]]; then
    echo "Error: hay datos existentes pero no hay estado de dominio inicial." >&2
    echo "Para cambiar a NODE_DOMAIN=$NODE_DOMAIN se requiere instalación limpia." >&2
    return 1
  fi

  return 0
}
