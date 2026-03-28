# Registro de cambios

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/). Las entradas siguen el historial de **Git** (`git log --date=short`), agrupadas por día. Orden **cronológico inverso** (lo más reciente arriba).

---

### 2026-03-28

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
