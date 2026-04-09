#!/usr/bin/env bash
# Instala en el host (Debian / Ubuntu / Linux Mint con apt) lo necesario antes de
# ./ops/bootstrap-with-restore.sh: git, openssl, Avahi (opcional), Docker Engine y Compose v2.
#
# Uso:
#   cd proyecto_pimienta
#   sudo ./ops/instalar_dependencias.sh
#
# Opciones:
#   --no-avahi   No instala avahi-daemon / avahi-utils (solo si no usarás LAN_MDNS=1).
#   -h, --help   Esta ayuda.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$(cd "$SCRIPT_DIR/.." && pwd)"

export DEBIAN_FRONTEND=noninteractive

WITH_AVAHI=1

usage() {
	cat <<'EOF'
Instala dependencias del host para Pimienta Negra (git, openssl, Docker + Compose v2, Avahi opcional).

Uso:
  cd proyecto_pimienta
  sudo ./ops/instalar_dependencias.sh

Opciones:
  --no-avahi   No instala avahi-daemon / avahi-utils.
  -h, --help   Esta ayuda.
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--no-avahi) WITH_AVAHI=0; shift ;;
		-h | --help) usage; exit 0 ;;
		*) echo "Opción desconocida: $1" >&2; usage >&2; exit 1 ;;
	esac
done

die() {
	echo "ERROR: $*" >&2
	exit 1
}

[[ "${EUID:-0}" -eq 0 ]] || die "Ejecutá con sudo o como root (p. ej. sudo $0)"

if ! command -v apt-get >/dev/null 2>&1; then
	die "Se requiere apt-get (Debian, Ubuntu, Linux Mint, etc.)."
fi

docker_compose_ok() {
	command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1
}

apt_install() {
	apt-get install -y --no-install-recommends "$@"
}

echo "=== apt update ==="
apt-get update -qq

echo "=== Paquetes base (git, openssl, curl, gnupg) ==="
BASE_PKGS=(git openssl ca-certificates curl gnupg)
if [[ "$WITH_AVAHI" -eq 1 ]]; then
	BASE_PKGS+=(avahi-daemon avahi-utils)
fi
apt_install "${BASE_PKGS[@]}"

if docker_compose_ok; then
	echo "Docker y «docker compose» ya funcionan. Nada más que hacer para el motor."
else
	echo "=== Docker Engine + Compose v2 ==="
	if apt-cache show docker-compose-plugin >/dev/null 2>&1; then
		echo "Instalando docker.io y docker-compose-plugin desde apt…"
		apt_install docker.io docker-compose-plugin || true
	fi
	if ! docker_compose_ok; then
		echo "Instalando Docker desde el repositorio oficial (recomendado en Linux Mint)…"
		# shellcheck source=/dev/null
		. /etc/os-release
		DOCKER_DISTRO=""
		DOCKER_CODENAME=""
		if [[ -n "${UBUNTU_CODENAME:-}" ]]; then
			DOCKER_DISTRO="ubuntu"
			DOCKER_CODENAME="$UBUNTU_CODENAME"
		elif [[ "${ID:-}" == "ubuntu" ]]; then
			DOCKER_DISTRO="ubuntu"
			DOCKER_CODENAME="${VERSION_CODENAME:-}"
		elif [[ -n "${DEBIAN_CODENAME:-}" ]] && [[ "${ID_LIKE:-}" == *debian* ]]; then
			DOCKER_DISTRO="debian"
			DOCKER_CODENAME="$DEBIAN_CODENAME"
		elif [[ "${ID:-}" == "debian" ]]; then
			DOCKER_DISTRO="debian"
			DOCKER_CODENAME="${VERSION_CODENAME:-}"
		fi
		[[ -n "$DOCKER_DISTRO" && -n "$DOCKER_CODENAME" ]] || die \
			"No se pudo deducir el repo Docker (UBUNTU_CODENAME / DEBIAN_CODENAME / VERSION_CODENAME). Instalá Docker a mano: https://docs.docker.com/engine/install/"

		# Quitar paquetes que suelen chocar con docker-ce (idempotente).
		apt-get remove -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc 2>/dev/null || true

		install -m 0755 -d /etc/apt/keyrings
		curl -fsSL "https://download.docker.com/linux/${DOCKER_DISTRO}/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
		chmod a+r /etc/apt/keyrings/docker.gpg
		echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DOCKER_DISTRO} ${DOCKER_CODENAME} stable" \
			>/etc/apt/sources.list.d/docker.list
		apt-get update -qq
		apt_install docker-ce docker-ce-cli containerd.io docker-compose-plugin
	fi
	docker_compose_ok || die "«docker compose» sigue sin funcionar. Revisá la salida de: docker compose version"
fi

echo "=== Servicio Docker ==="
systemctl enable --now docker

if [[ -n "${SUDO_USER:-}" ]] && id "$SUDO_USER" &>/dev/null; then
	if ! id -nG "$SUDO_USER" | grep -qw docker; then
		usermod -aG docker "$SUDO_USER"
		echo "Usuario $SUDO_USER agregado al grupo docker. Cerrá sesión y volvé a entrar (o reiniciá) para usar docker sin sudo."
	fi
fi

echo ""
echo "Listo. Comprobación:"
docker --version
docker compose version
echo ""
echo "Siguiente paso: cp .env.example .env && nano .env"
echo "Luego: ./ops/bootstrap-with-restore.sh"
