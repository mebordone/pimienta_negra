#!/usr/bin/env bash
# Publicar NODE_DOMAIN y subdominios XMPP en la LAN via mDNS (Avahi).
# Con --install-service crea un servicio systemd persistente (sobrevive reinicios).
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck disable=SC1091
source ./ops/lib/domain-env.sh
pimienta_domain_init .env
NAMES=("$NODE_DOMAIN" "$XMPP_ACCOUNTS_DOMAIN" "$XMPP_CONFERENCE_DOMAIN")
SERVICE_NAME="pimienta-mdns"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
RUNNER="/usr/local/lib/pimienta-mdns-runner.sh"

usage() {
  cat <<EOF
Uso:
  ./ops/setup-lan-mdns.sh                  Mostrar estado (IP detectada, servicio, Avahi).
  ./ops/setup-lan-mdns.sh --install-service Instalar servicio systemd persistente (sudo).
  ./ops/setup-lan-mdns.sh --uninstall-service Eliminar el servicio (sudo).
  ./ops/setup-lan-mdns.sh --apply          Publicar ahora en primer plano (sin systemd, dev).
  ./ops/setup-lan-mdns.sh --stop           Detener procesos avahi-publish lanzados con --apply.

Variables (.env o entorno):
  LAN_IP   IP LAN fija (opcional). Al --install-service se escribe en /etc/default/pimienta-mdns.
           Si no la definís, el servicio detecta la IPv4 en cada arranque (recomendado con DHCP).

Requisitos:
  avahi-daemon + avahi-utils  →  sudo apt install avahi-daemon avahi-utils

Opciones de resolución de nombre en la LAN:
  1) Servicio systemd (este script --install-service) — RECOMENDADO para nodo fijo.
     Persiste reinicios; la máquina anuncia ${NODE_DOMAIN} y subdominios XMPP en Wi‑Fi.
  2) DNS en el router  — sin software extra; no lo automatiza este repo.
  3) /etc/hosts en cada equipo — no escala ni funciona en iOS.
  4) Solo IP (MW_SERVER=http://192.168.x.x) — sin nombre, sin XMPP coherente.
EOF
}

detect_lan_ip() {
  if [[ -n "${LAN_IP:-}" ]]; then echo "$LAN_IP"; return; fi
  local ip=""
  command -v ip >/dev/null 2>&1 && ip="$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1 || true)"
  [[ -z "$ip" ]] && ip="$(hostname -I 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i !~ /^127\./) {print $i; exit}}' || true)"
  if [[ -z "$ip" ]]; then echo "No pude detectar IPv4 LAN. Definí LAN_IP en .env." >&2; exit 1; fi
  echo "$ip"
}

check_avahi() {
  if ! command -v avahi-publish >/dev/null 2>&1; then
    echo "Falta avahi-utils. Instalá con:" >&2
    echo "  sudo apt install avahi-daemon avahi-utils && sudo systemctl enable --now avahi-daemon" >&2
    exit 1
  fi
}

cmd_status() {
  local ip; ip="$(detect_lan_ip)"
  echo "IP LAN detectada : $ip"
  if command -v avahi-publish >/dev/null 2>&1; then
    echo "avahi-publish    : disponible"
  else
    echo "avahi-publish    : NO instalado  (sudo apt install avahi-utils)"
  fi
  if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
    echo "Servicio systemd : ACTIVO  (${SERVICE_NAME}.service)"
  elif [[ -f "$SERVICE_FILE" ]]; then
    echo "Servicio systemd : instalado pero INACTIVO"
  else
    echo "Servicio systemd : no instalado  (./ops/setup-lan-mdns.sh --install-service)"
  fi
  echo ""
  echo "Para instalar servicio persistente:  ./ops/setup-lan-mdns.sh --install-service"
}

cmd_install_service() {
  check_avahi
  local ip; ip="$(detect_lan_ip)"
  echo "Instalando servicio systemd persistente (IP actual: $ip; el runner re-detecta la IP cada 60s)."

  # IP fija opcional para systemd (si no existe o está vacío, el runner detecta en cada inicio).
  if [[ -n "${LAN_IP:-}" ]]; then
    echo "LAN_IP en .env → /etc/default/pimienta-mdns (IP fija)."
    sudo bash -c "printf '%s\n' 'LAN_IP=${LAN_IP}' > /etc/default/pimienta-mdns"
  else
    sudo bash -c "printf '%s\n' '# Opcional: LAN_IP=192.168.x.x para no depender de DHCP' > /etc/default/pimienta-mdns"
  fi

  # Runner: NO embebe la IP del día de la instalación (DHCP la cambia y el celular deja de entrar).
  sudo bash -c "cat > ${RUNNER}" <<'RUNNER_EOF'
#!/usr/bin/env bash
# Runner del servicio pimienta-mdns: publica NODE_DOMAIN y subdominios XMPP en la LAN.
# LAN_IP puede venir de EnvironmentFile=/etc/default/pimienta-mdns (opcional).
# Re-detecta la IPv4 cada 60s: si DHCP cambió la IP del nodo, se vuelve a publicar
# (sin esto, los celulares seguían resolviendo un dominio viejo a una IP anterior).
set -euo pipefail
detect_ip_at_start() {
  if [[ -n "${LAN_IP:-}" ]]; then echo "$LAN_IP"; return; fi
  local a=""
  command -v ip >/dev/null 2>&1 && a="$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1 || true)"
  [[ -z "$a" ]] && a="$(hostname -I 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i !~ /^127\./) {print $i; exit}}' || true)"
  if [[ -z "$a" ]]; then echo "pimienta-mdns: no pude detectar IPv4 LAN (definí LAN_IP en /etc/default/pimienta-mdns)" >&2; exit 1; fi
  echo "$a"
}
NAMES=(__NODE_DOMAIN__ __XMPP_ACCOUNTS_DOMAIN__ __XMPP_CONFERENCE_DOMAIN__)
pids=()
stop_publishers() {
  [[ ${#pids[@]} -eq 0 ]] && return 0
  kill "${pids[@]}" 2>/dev/null || true
  wait "${pids[@]}" 2>/dev/null || true
  pids=()
}
on_signal() {
  stop_publishers
  exit 0
}
trap on_signal INT TERM
trap stop_publishers EXIT

last_ip=""
while true; do
  IP="$(detect_ip_at_start)"
  if [[ "$IP" != "$last_ip" ]]; then
    stop_publishers
    echo "pimienta-mdns: publicando __NODE_DOMAIN__ (+ subdominios XMPP) → ${IP}"
    for name in "${NAMES[@]}"; do
      avahi-publish -a -R "$name" "$IP" &
      pids+=($!)
    done
    last_ip="$IP"
  fi
  sleep 60
done
RUNNER_EOF
  sudo sed -i \
    -e "s|__NODE_DOMAIN__|${NODE_DOMAIN}|g" \
    -e "s|__XMPP_ACCOUNTS_DOMAIN__|${XMPP_ACCOUNTS_DOMAIN}|g" \
    -e "s|__XMPP_CONFERENCE_DOMAIN__|${XMPP_CONFERENCE_DOMAIN}|g" \
    "$RUNNER"
  sudo chmod +x "$RUNNER"

  sudo bash -c "cat > ${SERVICE_FILE}" <<SVC_EOF
[Unit]
Description=Pimienta mDNS — publica ${NODE_DOMAIN} en la LAN
After=network-online.target avahi-daemon.service
Wants=network-online.target avahi-daemon.service

[Service]
Type=simple
EnvironmentFile=-/etc/default/pimienta-mdns
ExecStart=/bin/bash ${RUNNER}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
SVC_EOF

  sudo systemctl daemon-reload
  sudo systemctl enable "${SERVICE_NAME}"
  sudo systemctl restart "${SERVICE_NAME}"
  echo ""
  echo "Servicio ${SERVICE_NAME} activo. La IP se re-detecta cada 60s (DHCP / cambio de red)."
  echo "Desde cualquier equipo en la misma Wi‑Fi: http://${NODE_DOMAIN}/"
  echo "Forzar republish ya:  sudo systemctl restart ${SERVICE_NAME}"
  echo ""
  echo "Estado:  sudo systemctl status ${SERVICE_NAME}"
  echo "Logs:    sudo journalctl -u ${SERVICE_NAME} -f"
}

cmd_uninstall_service() {
  if [[ ! -f "$SERVICE_FILE" ]]; then
    echo "El servicio ${SERVICE_NAME} no está instalado."
    return 0
  fi
  sudo systemctl disable --now "${SERVICE_NAME}" 2>/dev/null || true
  sudo rm -f "$SERVICE_FILE" "$RUNNER" /etc/default/pimienta-mdns
  sudo systemctl daemon-reload
  echo "Servicio ${SERVICE_NAME} eliminado."
}

# --- modo --apply (dev/temporal, sin systemd) ---
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/.pimienta-lan-mdns.pids"

cmd_apply() {
  check_avahi
  local ip; ip="$(detect_lan_ip)"
  echo "IP LAN: $ip — publicando en mDNS (modo temporal, sin systemd)"
  cmd_stop 2>/dev/null || true
  : > "$PIDFILE"
  for name in "${NAMES[@]}"; do
    avahi-publish -a -R "$name" "$ip" &
    echo $! >> "$PIDFILE"
  done
  sleep 3
  echo "Listo. Desde otro equipo: http://${NODE_DOMAIN}/  (PIDs en $PIDFILE)"
  echo "Detener: ./ops/setup-lan-mdns.sh --stop"
  echo "Para persistencia real: ./ops/setup-lan-mdns.sh --install-service"
}

cmd_stop() {
  [[ ! -f "$PIDFILE" ]] && { echo "Nada que detener."; return 0; }
  while read -r pid; do
    [[ -z "$pid" ]] && continue
    kill -0 "$pid" 2>/dev/null && kill "$pid" 2>/dev/null && echo "Detenido pid=$pid"
  done < "$PIDFILE"
  rm -f "$PIDFILE"
}

case "${1:-}" in
  --install-service)   cmd_install_service ;;
  --uninstall-service) cmd_uninstall_service ;;
  --apply)             cmd_apply ;;
  --stop)              cmd_stop ;;
  --help|-h)           usage ;;
  *)                   cmd_status ;;
esac
