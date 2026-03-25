# Registro de cambios

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/). Versiones sin número siguen el trabajo en `main`.

## [Sin publicar]

### Añadido

- **Favicon unificado** (wiki, chat y FileBrowser) bajo el mismo host: `config/nginx/favicon.png` (48×48 desde la burbuja), rutas `/favicon.ico` y `/favicon.png` en nginx (puertos 80 y 443), `<link rel="icon">` en `config/converse/index.html`, `$wgFavicon` en MediaWiki.
- **FileBrowser**: carpeta `config/filebrowser/branding/img/icons/` (ICO, PNG, SVG con PNG en base64 para Chromium), volumen `/branding`, `branding.files=/branding` en el bootstrap del contenedor.
- **Gateway**: interceptación `^~ /archivos/static/img/icons/` para servir esos iconos desde disco (corrige HEAD→404 del binario FileBrowser y evita CSP del upstream en el SVG).
- **Wiki**: fuentes versionadas `config/mediawiki/portada-principal.wikitext` y `config/mediawiki/MediaWiki-Sidebar.wikitext` (referencia; la barra lateral del dump sigue sin enlaces §5.3 a chat/archivos).
- **Ops**: `ops/ensure-portada-logo.sh` copia el logo a `data/mediawiki/images/1/1f/Logo_Wiki_Pimienta.png` si falta; invocado al final de `restore-wiki.sh`.

### Cambiado

- **MediaWiki `LocalSettings.php`**: logos Minerva sin `wordmark` duplicado; icono en pie (`$wgFooterIcons`); CSS inline (`BeforePageDisplay`) para limitar tamaño del logo en cabecera y pie.
- **Dump de referencia** `backups/wiki/copia_wiki_real.sql`: alineado con portada, logo importado y revisiones actuales.

### Documentación

- `Roadmap.md`: §5.2 portada entregada, §5.3 estado de la sidebar, §5.4 favicon entregado.
- `README.md`, `docs/contribucion.md`, `docs/operacion-y-troubleshooting.md` (favicon, FileBrowser, logo portada), `docs/arquitectura.md` (rutas de favicon e iconos).
