#!/usr/bin/env bash
# Publicar pimienta*.local en la LAN via mDNS (Avahi).
# Con --install-service crea un servicio systemd persistente (sobrevive reinicios).
set -euo pipefail

cd "$(dirname "$0")/.."

NAMES=(pimienta.local accounts.pimienta.local conference.pimienta.local)
SERVICE_NAME="pimienta-mdns"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
RUNNER="/usr/local/lib/pimienta-mdns-runner.sh"

# Cargar .env si existe
if [[ -f .env ]]; then
  set -a; source .env; set +a
fi

usage() {
  cat <<'EOF'
Uso:
  ./ops/setup-lan-mdns.sh                  Mostrar estado (IP detectada, servicio, Avahi).
  ./ops/setup-lan-mdns.sh --install-service Instalar servicio systemd persistente (sudo).
  ./ops/setup-lan-mdns.sh --uninstall-service Eliminar el servicio (sudo).
  ./ops/setup-lan-mdns.sh --apply          Publicar ahora en primer plano (sin systemd, dev).
  ./ops/setup-lan-mdns.sh --stop           Detener procesos avahi-publish lanzados con --apply.

Variables (.env o entorno):
  LAN_IP   Forzar IP LAN (por defecto: primera IPv4 global detectada).

Requisitos:
  avahi-daemon + avahi-utils  →  sudo apt install avahi-daemon avahi-utils

Opciones de resolución de nombre en la LAN:
  1) Servicio systemd (este script --install-service) — RECOMENDADO para nodo fijo.
     Persiste reinicios; la máquina anuncia pimienta*.local en Wi‑Fi.
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
  echo "Instalando servicio systemd persistente → $ip"

  # Script runner (se copia a /usr/local/lib para ser independiente de la ruta del repo)
  sudo bash -c "cat > ${RUNNER}" <<RUNNER_EOF
#!/usr/bin/env bash
# Runner del servicio pimienta-mdns: publica pimienta*.local en la LAN.
IP="${ip}"
NAMES=(pimienta.local accounts.pimienta.local conference.pimienta.local)
pids=()
trap 'kill "\${pids[@]}" 2>/dev/null; wait' EXIT INT TERM
for name in "\${NAMES[@]}"; do
  avahi-publish -a -R "\$name" "\$IP" &
  pids+=(\$!)
done
wait
RUNNER_EOF
  sudo chmod +x "$RUNNER"

  sudo bash -c "cat > ${SERVICE_FILE}" <<SVC_EOF
[Unit]
Description=Pimienta mDNS — publica pimienta*.local en la LAN
After=network-online.target avahi-daemon.service
Wants=network-online.target avahi-daemon.service

[Service]
Type=simple
ExecStart=/bin/bash ${RUNNER}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
SVC_EOF

  sudo systemctl daemon-reload
  sudo systemctl enable --now "${SERVICE_NAME}"
  echo ""
  echo "Servicio ${SERVICE_NAME} activo y configurado para iniciar con el sistema."
  echo "Desde cualquier equipo en la misma Wi‑Fi: http://pimienta.local/"
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
  sudo rm -f "$SERVICE_FILE" "$RUNNER"
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
  echo "Listo. Desde otro equipo: http://pimienta.local/  (PIDs en $PIDFILE)"
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
