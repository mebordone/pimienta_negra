# Registro de cambios

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/). Las entradas siguen el historial de **Git** (`git log --date=short`), agrupadas por día. Orden **cronológico inverso** (lo más reciente arriba).

---

### 2026-04-09

- feat(ops): `bootstrap-filebrowser-users.sh` — locale `es` por defecto en FileBrowser
- fix(ops): robustez arranque en frío — variables, certs y skip graceful:
  - `docker-compose.yml`: `MYSQL_ROOT_PASSWORD` y `FILEBROWSER_ADMIN_USERNAME` leen desde `.env`
  - `LocalSettings.php`: `$wgDBpassword` lee `MYSQL_ROOT_PASSWORD` del entorno del contenedor (ya no hardcodeada)
  - `bootstrap-filebrowser-users.sh`: username admin configurable via `FILEBROWSER_ADMIN_USERNAME`
  - `restore-wiki.sh`: sin dump SQL → aviso + `exit 0` (wiki vacía funcional) en lugar de `exit 1`
  - `init-chat.sh`: verifica existencia de `.crt`/`.key` tras `openssl`; falla con mensaje claro si faltan
  - `instalar_dependencias.sh`: aviso explícito de reabrir sesión después de agregar al grupo `docker`
  - `.env.example`: documenta `MYSQL_ROOT_PASS` y `FILEBROWSER_ADMIN_USERNAME`
- fix(ops): `restore-wiki.sh` — forzar TCP (`-h 127.0.0.1`) en llamadas `mysql` dentro del contenedor `db` (evita error de socket Unix en arranque en frío)
- feat(ops): `reset.sh` — limpia contenedores, volúmenes Docker y bind mounts para ciclo de desarrollo (`--purge` borra también imágenes)
- fix(ops): `bootstrap-with-restore.sh` — `mkdir -p` + `chown 1000:1000` sobre `data/filebrowser` y `archivos` antes de `docker compose up` (FileBrowser UID 1000 no puede escribir en dirs creados como root)
- fix(ops): `bootstrap-with-restore.sh` — `restore-wiki` tras MariaDB y **antes** del check HTTP (arranque en frío con BD vacía)
- docs: operación y contribución — orden bootstrap / wiki 500 hasta importar SQL

### 2026-03-30

- fix(ops): `instalar_dependencias.sh` — reintentar `apt update` con `--allow-releaseinfo-change` si un repo cambia prioridad InRelease (p. ej. Mint / jammy-backports)
- feat(ops): `instalar_dependencias.sh` — apt + Docker/Compose v2 + Avahi; repo Docker oficial si falta `docker-compose-plugin` (p. ej. Linux Mint)
- docs: README inicio rápido en 4 pasos, árbol del repo y `docs/contribucion.md` con el script

### 2026-03-28

- docs(roadmap): §5.10 dominio `.local` configurable desde `.env` (rebrand tipo `flisol.local`); §5.9 y §0.2
- feat(landing): credenciales invitado bajo Archivos (`guest_username` / `guest_password` en `config.json`) y modal nativo antes de abrir el chat (certificado HTTPS local)
- docs: README, arquitectura, operación, decisiones, contribución, índice `docs/README`, Roadmap §5 y `proyecto_pimienta/tests/README` alineados a la UX de la landing
- fix(ops): `diagnose-lan-access.sh` — pista de Android con «tu red» en lugar de un SSID de ejemplo
- feat(ops): `diagnose-lan-access.sh` para cuando no entra por LAN (IP, Docker, ufw, mDNS)
- fix(ops): mDNS — runner `pimienta-mdns` re-detecta IP cada 60s; `install-service` hace `restart` para aplicar el runner actualizado
- docs: operación (sección mDNS) y `.env.example` alineado a `--install-service`
- feat(landing): página en `/` con `config.json`, logo en `/assets/logo.png`, footer (nodo, Aguaribay, principios)
- feat(stack): wiki pública en `/wiki/`, nginx con URI completa hacia el contenedor y `Alias /wiki` en Apache (ResourceLoader / `load.php`)
- feat(tests): `tests/run-all.sh`, `wait-for-gateway.sh` sobre `/wiki/`, integración `config.json` y smoke ampliado
- ci: workflow GitHub Actions para tests estáticos y e2e del stack
- docs: README, Roadmap §3, arquitectura, decisiones, operación y contribución alineados a landing y rutas
- docs(ops): mensaje final de `bootstrap-with-restore.sh` con landing (`/`) y wiki (`/wiki/`)

### 2026-03-25

- docs: CHANGELOG, Roadmap §5.2–5.4, favicon y portada
- feat(ops): ensure-portada-logo tras restore de la wiki
- chore(wiki): actualizar copia_wiki_real.sql de referencia
- feat(wiki): fuentes wikitext de portada y MediaWiki-Sidebar
- feat(wiki): favicon, logos Minerva sin wordmark y pie con burbuja
- feat(stack): favicon unificado vía nginx, branding FileBrowser y chat
- feat(gateway): redirigir HTTP /chat a HTTPS; chore: .gitignore en raíz
- chore(wiki): actualizar dump copia_wiki_real con contenido de referencia
- docs(roadmap): checklist nodo LAN, prioridades y sección de mejoras UX
- docs(readme): MW_SERVER opcional, troubleshooting y enlaces a docs/
- docs: arquitectura, decisiones de diseño, operación y guía de contribución
- chore(gitignore): ignorar venv, archivos de FileBrowser y mantener .gitkeep
- feat(stack): HTTPS en gateway para chat, MW_SERVER opcional y Converse con wss dinámico
- feat(ops): bootstrap con URLs según MW_SERVER y usuario invitado FileBrowser configurable
- feat(ops): script para editar páginas de la wiki vía Action API
- fix(ops): servicio mDNS con IP detectada en cada arranque y /etc/default opcional
- fix(ops): restore wiki compatible con dumps sin USE y variables @OLD_*

### 2026-03-24

- fix(chat+archivos): use local Converse vendor assets and fix FileBrowser baseURL
- fix(restore): strip SET var=@OLD_* lines to avoid NULL error in MariaDB 10.5
- feat(lan): persistent Avahi systemd service for pimienta*.local
- feat(lan): mDNS Avahi to publish pimienta*.local to the LAN
- docs: refresh README for gateway, XMPP chat and FileBrowser
- fix(wiki): MW_SERVER from env, disable email and external images
- feat(stack): nginx gateway, Prosody, Converse.js and FileBrowser
- refactor!: remove Synapse/Matrix configuration and init script
- chore: remove tracked Python venv from repository
- chore: ignore venv, .env and FileBrowser uploads; add .env.example
- wiki: Roadmap §3.2 — contenido alineado al gateway y dump SQL
- README: documentar fork Pimienta Negra vs Aguaribay y modos de inicio.
- Roadmap: adoptar FileBrowser para el portal de archivos.

### 2026-03-19

- Mover backups históricos de nodo a carpeta dedicada.
- Documentar flujo de backup/restauración para usuarios nuevos.
- Agregar scripts operativos para modo C y persistencia de uploads.
- Reorganizar assets de Wiki en backups y config.

### 2026-03-10

- Update README.md

### 2026-03-03

- Wiki configurada y Git optimizado para ignorar datos sensibles

### 2026-02-16

- Fix: IP fija 192.168.0.170 y compatibilidad Mongo 4.4 para Raspberry Pi

### 2026-01-16

- Mis avances de hoy en la Wiki

### 2026-01-04

- Resguardo de base de datos y estructura de carpetas finalizada

### 2025-12-08

- Primer commit: estructura inicial del proyecto
