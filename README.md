# Pimienta Negra

Fork de [Proyecto Aguaribay (Pimienta Rosa)](https://github.com/mebordone/pimienta_negra) que extiende el nodo comunitario autohospedado con herramientas de operación, backup y un portal de archivos.

## Qué es Aguaribay (proyecto original)

Aguaribay es un nodo comunitario que corre sobre una Raspberry Pi y ofrece dos servicios mediante Docker:

- **Wiki Pimienta** (MediaWiki + MariaDB) -- una Wikipedia local para documentar y compartir saberes de la comunidad.
- **Chat Soberano** (Matrix Synapse + PostgreSQL) -- un servidor de mensajería federado, compatible con clientes como Element.

El objetivo es que una comunidad pueda tener su propia infraestructura de comunicación y conocimiento, sin depender de plataformas externas ni de conectividad a Internet.

## Qué agrega Pimienta Negra

Este fork incorpora:

- **Backup y restauración de la Wiki** -- scripts (`ops/backup-wiki.sh`, `ops/restore-wiki.sh`) que generan y restauran paquetes `.tar.gz` con la base de datos, `LocalSettings.php` y uploads/imágenes.
- **Inicialización limpia del Chat** -- script (`ops/init-synapse.sh`) que genera la configuración de Synapse desde una plantilla, para arrancar el chat sin datos previos.
- **Portal de archivos compartidos** -- integración de [FileBrowser](https://filebrowser.org/) como servicio Docker para subir/bajar archivos en la red local (planificado, ver `Roadmap.md`).
- **Landing page** -- página de entrada en `http://pimienta.local` con acceso a Wiki, Chat y Archivos (planificado, ver `Roadmap.md`).
- **Roadmap** -- hoja de ruta con el plan completo de funcionalidades futuras: modos de red, panel de admin, instalador para Raspberry Pi, asistente de primer arranque.

## Objetivo del proyecto

Sensibilizar a la comunidad sobre la importancia de la intranet comunitaria, su rol en la respuesta ante crisis (climática, sanitaria, política) y el acceso a conocimientos compartidos. Concretamente:

- Ofrecer soberanía digital: comunicación y conocimiento sin depender de Internet ni de terceros.
- Preservar saberes locales en una wiki colaborativa accesible desde la red del barrio/escuela/organización.
- Facilitar la instalación, el uso y el mantenimiento del nodo a personas con poco o ningún conocimiento técnico.

## Público objetivo

- Comunidades barriales, escolares o rurales que quieran servicios digitales propios.
- Personas cuidadoras del nodo (admins no técnicas) que necesiten operar el sistema sin usar terminal.
- Facilitadoras y talleristas que trabajen con comunidades en soberanía tecnológica.

## Estructura del repositorio

```
proyecto_pimienta/
├── docker-compose.yml            # Stack: wiki + chat (+ filebrowser a futuro)
├── config/
│   ├── mediawiki/
│   │   ├── LocalSettings.php     # Configuración de MediaWiki
│   │   └── images/               # Logo y assets de branding
│   └── synapse/
│       └── homeserver.yaml.template  # Plantilla para generar config de Synapse
├── ops/
│   ├── backup-wiki.sh            # Genera backup .tar.gz de la wiki
│   ├── restore-wiki.sh           # Restaura wiki desde .tar.gz o .sql
│   └── init-synapse.sh           # Inicializa Synapse con config limpia
├── backups/
│   └── wiki/                     # Dump SQL incluido para restauración inicial
└── data/                         # Runtime (ignorado por git): DBs, uploads, keys
```

## Modos de inicio

### Inicio limpio (todo desde cero)

Wiki vacía + Chat vacío. Útil para arrancar un nodo nuevo sin contenido previo.

```bash
cd proyecto_pimienta

# 1. Inicializar configuración de Synapse
./ops/init-synapse.sh

# 2. Levantar contenedores
docker compose up -d
```

La wiki arranca con la página principal por defecto de MediaWiki y el chat queda listo para crear usuarios.

### Inicio con contenido (wiki restaurada + chat limpio)

Levanta la wiki con contenido previo (base de datos, configuración, uploads/imágenes) y el chat arranca vacío.

```bash
cd proyecto_pimienta

# 1. Inicializar configuración de Synapse
./ops/init-synapse.sh

# 2. Levantar contenedores
docker compose up -d

# 3. Restaurar contenido de la Wiki
./ops/restore-wiki.sh
```

Por defecto restaura el dump incluido en el repositorio. Si tenés un backup propio generado con `./ops/backup-wiki.sh`, indicalo así:

```bash
./ops/restore-wiki.sh --backup ./backups/wiki/exports/wiki-backup-<fecha>.tar.gz
```

### Verificación

- Wiki: `http://pimienta.local:8080` (debería cargar correctamente)
- Chat: `http://pimienta.local:8008/_matrix/client/versions` (debería devolver `200`)

## Backup y restauración

### Generar un backup de la Wiki

```bash
./ops/backup-wiki.sh
```

Genera un `.tar.gz` en `backups/wiki/exports/` que incluye la base de datos, `LocalSettings.php` y `images/` (uploads).

### Restaurar desde un backup

```bash
./ops/restore-wiki.sh --backup ./backups/wiki/exports/wiki-backup-<fecha>.tar.gz
```

### Notas

- El restore incluye preprocesado del SQL (filtra por base `my_wiki` y ajusta collations) para compatibilizar con MariaDB 10.5.
- Para "resetear" el chat, borrá `./data/postgres` y `./data/synapse` antes de correr `init-synapse.sh`.
