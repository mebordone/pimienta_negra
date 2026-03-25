#!/usr/bin/env bash
# Publicar pimienta*.local en la LAN (mDNS / Avahi). Ver texto de ayuda con --help.
set -euo pipefail

cd "$(dirname "$0")/.."

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/.pimienta-lan-mdns.pids"
NAMES=(pimienta.local accounts.pimienta.local conference.pimienta.local)

usage() {
  cat <<'EOF'
Opciones para que otros equipos en la LAN resuelvan pimienta*.local hacia esta máquina:

1) mDNS con Avahi (este script, --apply)
   + No tocás el router ni cada celular; muchos clientes resuelven *.local en la Wi‑Fi.
   + Coherente con MW_SERVER=http://pimienta.local y con Prosody (accounts/conference).
   - Requiere Linux con avahi-daemon + avahi-utils; hay que mantener el proceso (o un servicio).
   - Si la IP LAN cambia (DHCP), hay que volver a ejecutar --apply (o automatizar con systemd).
   - Algunos routers filtran multidifusión y rompen mDNS.

2) DNS local en el router (entrada estática pimienta.local → IP del servidor)
   + Funciona en toda la LAN sin software extra en el servidor.
   + Suele ser estable si reservás DHCP por MAC para el servidor.
   - Depende del modelo del router y de que permita DNS estático / “DNS local”.
   - No lo automatiza este repo (cada router es distinto).

3) /etc/hosts en cada dispositivo
   + Simple y determinístico.
   - En cada PC hay que editar con sudo; en iOS casi imposible sin perfiles MDM.
   - Si la IP del servidor cambia, actualizar en todos lados.

4) Usar solo la IP (MW_SERVER=http://192.168.x.x)
   + Sin DNS ni mDNS.
   - Feo para enlaces; si DHCP cambia la IP, hay que reconfigurar y recrear contenedor wiki.
   - XMPP/Converse siguen esperando dominio pimienta.local en muchos sitios.

Recomendación: nodo fijo (Raspberry) → Avahi o DNS del router; portátil de prueba → Avahi --apply.

Uso:
  ./ops/setup-lan-mdns.sh              Mostrar esta ayuda, IP detectada y si Avahi está listo.
  ./ops/setup-lan-mdns.sh --apply      Publicar los nombres en la LAN (Avahi), en segundo plano.
  ./ops/setup-lan-mdns.sh --stop       Detener los avahi-publish que registramos antes.
  ./ops/setup-lan-mdns.sh --help       Esta ayuda.

Variables:
  LAN_IP   Forzar IP (por defecto: primera IPv4 global del host).

Requisitos para --apply:
  - Paquetes: avahi-daemon (activo) y avahi-utils (comando avahi-publish).
  - Firewall del host: permitir el puerto del gateway (80 u otro) desde la LAN.
EOF
}

detect_lan_ip() {
  if [[ -n "${LAN_IP:-}" ]]; then
    echo "$LAN_IP"
    return
  fi
  local ip=""
  if command -v ip >/dev/null 2>&1; then
    ip="$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1 || true)"
  fi
  if [[ -z "$ip" ]] && hostname -I >/dev/null 2>&1; then
    ip="$(hostname -I 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i !~ /^127\./) {print $i; exit}}')"
  fi
  if [[ -z "$ip" ]] && [[ "$(uname -s)" == "Darwin" ]]; then
    for ifc in en0 en1; do
      ip="$(ipconfig getifaddr "$ifc" 2>/dev/null || true)"
      [[ -n "$ip" ]] && break
    done
  fi
  if [[ -z "$ip" ]]; then
    echo "No pude detectar una IPv4 de la LAN. Definí LAN_IP manualmente." >&2
    exit 1
  fi
  echo "$ip"
}

cmd_stop() {
  if [[ ! -f "$PIDFILE" ]]; then
    echo "No hay registro de procesos ($PIDFILE). Nada que detener."
    return 0
  fi
  while read -r pid; do
    [[ -z "$pid" ]] && continue
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      echo "Detenido avahi-publish pid=$pid"
    fi
  done <"$PIDFILE"
  rm -f "$PIDFILE"
}

cmd_apply() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    echo "--apply solo está soportado en Linux (Avahi). En otros sistemas usá DNS del router o /etc/hosts." >&2
    exit 1
  fi
  if ! command -v avahi-publish >/dev/null 2>&1; then
    echo "Falta el comando avahi-publish (paquete avahi-utils en Debian/Ubuntu)." >&2
    echo "Instalación típica: sudo apt install avahi-daemon avahi-utils && sudo systemctl enable --now avahi-daemon" >&2
    exit 1
  fi
  if ! pgrep -x avahi-daemon >/dev/null 2>&1 && ! systemctl is-active --quiet avahi-daemon 2>/dev/null; then
    echo "Aviso: avahi-daemon no parece estar corriendo. Probá: sudo systemctl start avahi-daemon" >&2
  fi

  local ip
  ip="$(detect_lan_ip)"
  echo "IP LAN detectada: $ip"
  echo "Publicando en mDNS: ${NAMES[*]}"

  cmd_stop 2>/dev/null || true
  : >"$PIDFILE"

  for name in "${NAMES[@]}"; do
    avahi-publish -a -R "$name" "$ip" &
    echo $! >>"$PIDFILE"
  done

  echo ""
  echo "Listo. Desde otro equipo en la misma Wi‑Fi probá: http://${NAMES[0]}/"
  echo "PIDs en $PIDFILE (./ops/setup-lan-mdns.sh --stop para detener)."
}

case "${1:-}" in
  --help|-h)
    usage
    ;;
  --apply)
    cmd_apply
    ;;
  --stop)
    cmd_stop
    ;;
  *)
    usage
    echo "---"
    ip="$(detect_lan_ip)"
    echo "IPv4 sugerida para esta máquina: $ip"
    if command -v avahi-publish >/dev/null 2>&1; then
      echo "avahi-publish: disponible"
    else
      echo "avahi-publish: no instalado (necesario para --apply)"
    fi
    echo ""
    echo "Para anunciar pimienta*.local en la LAN:  ./ops/setup-lan-mdns.sh --apply"
    ;;
esac
