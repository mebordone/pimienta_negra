#!/usr/bin/env bash
# Diagnóstico cuando no entrás al nodo desde celular u otra PC en la misma Wi‑Fi.
# Ejecutar EN LA MÁQUINA DEL NODO, desde proyecto_pimienta/.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

PORT="${GATEWAY_HTTP_PORT:-80}"
HTTPS_PORT="${GATEWAY_HTTPS_PORT:-443}"

detect_lan_ip() {
  local ip=""
  if [[ -n "${LAN_IP:-}" ]]; then
    echo "$LAN_IP"
    return
  fi
  command -v ip >/dev/null 2>&1 && ip="$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1 || true)"
  [[ -z "$ip" ]] && ip="$(hostname -I 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i !~ /^127\./) {print $i; exit}}' || true)"
  echo "$ip"
}

LAN_IP="$(detect_lan_ip)"

echo "═══════════════════════════════════════════════════════════"
echo " Pimienta — diagnóstico acceso LAN (misma Wi‑Fi que el nodo)"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "1) IP IPv4 detectada en este equipo (usala en el celular si .local falla):"
if [[ -n "$LAN_IP" ]]; then
  echo "   →  $LAN_IP"
  echo "   →  Prueba en el navegador del celular:  http://${LAN_IP}:${PORT}/"
else
  echo "   →  (no detectada — conectá cable/Wi‑Fi o definí LAN_IP en .env)"
fi
echo ""
echo "2) Puerto del gateway (GATEWAY_HTTP_PORT): ${PORT}"
echo "   ¿Docker escucha en todas las interfaces? (debe aparecer 0.0.0.0 o *:${PORT})"
if command -v ss >/dev/null 2>&1; then
  ss -tlnp 2>/dev/null | grep -E ":${PORT}\\s" || echo "   (ss no mostró el puerto ${PORT} — ¿stack abajo?)"
else
  echo "   (instalá iproute2 para usar ss)"
fi
echo ""
echo "3) Respuesta HTTP desde este mismo equipo:"
for url in "http://127.0.0.1:${PORT}/" "http://127.0.0.1:${PORT}/wiki/"; do
  code="$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 3 "$url" || echo "ERR")"
  echo "   $url → $code"
done
if [[ -n "$LAN_IP" ]]; then
  code="$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://${LAN_IP}:${PORT}/" || echo "ERR")"
  echo "   http://${LAN_IP}:${PORT}/ → $code  (vía IP LAN, mismo PC)"
fi
echo ""
echo "4) Firewall en ESTE equipo (suele bloquear el 80 si está activo):"
if command -v ufw >/dev/null 2>&1; then
  ufw status verbose 2>/dev/null || sudo ufw status verbose 2>/dev/null || echo "   (no se pudo leer ufw sin sudo)"
else
  echo "   (ufw no instalado — puede haber iptables/nftables a mano)"
fi
echo ""
echo "5) mDNS (nombre pimienta.local):"
if systemctl is-active --quiet pimienta-mdns 2>/dev/null; then
  echo "   pimienta-mdns: activo"
else
  echo "   pimienta-mdns: INACTIVO — LAN_MDNS=1 + bootstrap o: ./ops/setup-lan-mdns.sh --install-service"
fi
if systemctl is-active --quiet avahi-daemon 2>/dev/null; then
  echo "   avahi-daemon: activo"
else
  echo "   avahi-daemon: INACTIVO — sudo systemctl enable --now avahi-daemon"
fi
echo ""
echo "6) Contenedor gateway:"
docker compose ps gateway 2>/dev/null || echo "   (docker compose ps falló — ¿estás en proyecto_pimienta/?)"
echo ""
echo "─── Qué probar en la OTRA computadora o celular (misma red Wi‑Fi) ───"
echo "A) Navegador:  http://${LAN_IP:-SU_IP}:${PORT}/"
echo "B) Si A funciona pero http://pimienta.local/ no → es mDNS (Android: desactivá «DNS privado»)."
echo "C) Si A tampoco funciona → router con «aislamiento de clientes / AP isolation» o firewall en el nodo."
echo "   En el nodo:  sudo ufw allow ${PORT}/tcp   y   sudo ufw allow ${HTTPS_PORT}/tcp"
echo "D) Si el router tiene 2,4 GHz y 5 GHz (ej. GALATEAWIFI vs GALATEAWIFI5G): a veces solo una banda"
echo "   tiene aislamiento de clientes — probá la otra banda con PC y celular en la misma SSID."
echo ""
echo "Comando útil desde OTRA PC (Linux/Mac):  ping ${LAN_IP:-IP_DEL_NODO}"
echo ""
echo "══ Si ni http://${LAN_IP}:${PORT}/ entra desde el CELULAR ══"
echo "   (no es mDNS: o no llega el tráfico al PC o el firewall lo corta)"
echo ""
echo "7) ¿El celular está en la MISMA subred? (primeros 3 números de la IP que el nodo)"
if [[ -n "$LAN_IP" ]] && [[ "$LAN_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\. ]]; then
  prefix="${LAN_IP%.*}"
  echo "   El nodo es ${LAN_IP} → el celular debería ser algo como ${prefix}.XXX"
  echo "   En Android: Ajustes → Wi‑Fi → GALATEAWIFI5G → Detalles / IP (debe ser ${prefix}.*)"
fi
echo ""
echo "8) Firewall (ejecutá con sudo en el nodo):"
echo "   sudo ufw status verbose"
echo "   Si Status: active y no hay ALLOW al ${PORT}:"
echo "   sudo ufw allow ${PORT}/tcp comment 'Pimienta gateway'"
echo "   sudo ufw allow ${HTTPS_PORT}/tcp comment 'Pimienta HTTPS chat'"
echo "   sudo ufw reload"
echo ""
echo "9) Ver si el paquete del celular LLEGA al nodo (con el celular en la misma Wi‑Fi):"
echo "   En el nodo:  sudo timeout 25 tcpdump -n -i any \"tcp port ${PORT}\""
echo "   Recargá en el celular http://${LAN_IP}:${PORT}/"
echo "   · Sin líneas con la IP del celular → router con aislamiento o el celular no está en la misma red L2."
echo "   · Ves SYN hacia ${LAN_IP} pero nada más → firewall en este PC."
echo ""
echo "10) VPN / DNS en el celular: desactivá VPN y «DNS privado» (Android)."
echo "═══════════════════════════════════════════════════════════"
