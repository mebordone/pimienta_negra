# Pimienta Negra

Fork de [Proyecto Aguaribay (Pimienta Rosa)](https://github.com/mebordone/pimienta_negra) que extiende el nodo comunitario autohospedado con herramientas de operación, backup y un portal de archivos.

## Qué es Aguaribay (proyecto original)

Aguaribay es un nodo comunitario pensado para una Raspberry Pi con dos ejes: **wiki comunitaria** y **chat en la red local**. En este fork (Pimienta Negra) el chat se implementa con **Prosody + Converse.js** (XMPP liviano, invitadx sin contraseña).

- **Wiki Pimienta** (MediaWiki + MariaDB) — documentación y saberes compartidos.
- **Chat** (Prosody + Converse.js) — mensajería en la LAN; sin historial persistente en servidor.

El objetivo es que una comunidad pueda tener su propia infraestructura de comunicación y conocimiento, sin depender de plataformas externas ni de conectividad a Internet.

## Qué agrega Pimienta Negra

Este fork incorpora:

- **Backup y restauración de la Wiki** — scripts (`ops/backup-wiki.sh`, `ops/restore-wiki.sh`) que generan y restauran paquetes `.tar.gz` con la base de datos, `LocalSettings.php` y uploads/imágenes.
- **Chat XMPP** — Prosody + interfaz web Converse.js; script `ops/init-chat.sh` (certificados y permisos antes del primer `docker compose up`).
- **Gateway nginx** — un solo punto de entrada en el puerto **80** del host (o el que definas con `GATEWAY_HTTP_PORT`): wiki en `/`, chat en `/chat/`, archivos en `/archivos/`, WebSocket XMPP en `/xmpp-websocket`.
- **Portal de archivos compartidos** — [FileBrowser](https://filebrowser.org/) detrás del gateway en `/archivos/` (y opcionalmente directo en el puerto **8081** para depuración). Usuarios `admin` e `invitado` con contraseñas por variables de entorno.
- **Roadmap** — plan de trabajo (red AP/nodo, panel de admin, instalador, documentación amplia, etc.).

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
├── docker-compose.yml            # Stack: wiki + prosody + filebrowser + gateway (nginx)
├── .env.example                  # Variables (gateway, wiki, FileBrowser, Prosody)
├── archivos/                     # Carpeta compartida del portal (bind → FileBrowser /srv)
├── config/
│   ├── mediawiki/
│   │   ├── LocalSettings.php     # Configuración de MediaWiki
│   │   └── images/               # Logo y assets de branding
│   ├── filebrowser/
│   │   └── settings.json         # FileBrowser: baseURL /archivos + proxy nginx sin quitar prefijo
│   ├── prosody/
│   │   ├── prosody.cfg.lua       # Servidor XMPP
│   │   └── conf.d/               # Includes opcionales
│   ├── nginx/
│   │   └── default.conf          # Reverse proxy
│   └── converse/
│       ├── index.html            # Cliente Converse.js (ruta /chat/); assets en vendor/
│       └── vendor/               # converse.min.js/css, libsignal, locales es, emoji (sin CDN)
├── ops/
│   ├── init-chat.sh              # Certificados Prosody + permisos (antes del primer arranque)
│   ├── prosody-entrypoint.sh     # Registro admin + arranque Prosody
│   ├── backup-wiki.sh            # Genera backup .tar.gz de la wiki
│   ├── restore-wiki.sh           # Restaura wiki desde .tar.gz o .sql
│   ├── bootstrap-with-restore.sh # init-chat + compose up + restore-wiki (primer arranque con contenido)
│   ├── verify-stack.sh           # Comprueba wiki /chat /archivos vía gateway (curl + --resolve)
│   ├── up-gateway-port80.sh      # Tras liberar :80 en el host, levanta gateway y ejecuta verify-stack
│   ├── vendor-converse.sh        # Descarga Converse 12 + libsignal a config/converse/vendor/ (requiere red)
│   ├── setup-hosts.sh            # Agrega pimienta.local a /etc/hosts (una sola vez)
│   ├── bootstrap-filebrowser-users.sh
│   └── filebrowser-entrypoint.sh
├── backups/
│   └── wiki/                     # Dump SQL incluido para restauración inicial
└── data/                         # Runtime (ignorado por git): DBs, prosody, certs, filebrowser, imágenes
```

## Requisitos previos

### 1. Resolución de `pimienta.local`

Los servicios generan URLs con el hostname `pimienta.local`. Para que funcionen en tu máquina, ejecutá:

```bash
cd proyecto_pimienta
./ops/setup-hosts.sh
```

El script agrega `127.0.0.1  pimienta.local` a `/etc/hosts` (pide `sudo`). Si ya está configurado, no hace nada. Esto es necesario solo una vez por máquina.

> En un despliegue en Raspberry Pi con mDNS/Avahi (ver secciones 1 y 8 del Roadmap), este paso no sería necesario para los clientes de la red local.

### 2. Docker y Docker Compose

Necesitás Docker y Docker Compose instalados. En Linux:

```bash
docker --version && docker compose version
```

## Modos de inicio

### Variables de entorno (gateway, wiki, FileBrowser, Prosody)

- **`GATEWAY_HTTP_PORT`** (opcional): puerto del nginx en el host; por defecto **80**. Si el puerto 80 está ocupado, usá por ejemplo `8088` (`export GATEWAY_HTTP_PORT=8088` o en `.env`).
- **`MW_SERVER`**: URL base de la wiki tal como la ven los navegadores (por defecto `http://pimienta.local`). **Si el gateway no está en el puerto 80**, tenés que incluir el puerto en `MW_SERVER` (ej. `http://pimienta.local:8088`); si no, las redirecciones de MediaWiki apuntan al host equivocado. Ejemplo listo para copiar en [proyecto_pimienta/.env.example](proyecto_pimienta/.env.example).
- **FileBrowser**: `FILEBROWSER_ADMIN_PASSWORD` y `FILEBROWSER_INVITADO_PASSWORD` (mínimo **8 caracteres**). Sin definir, el compose usa valores **solo para pruebas**.
- **Prosody**: `PROSODY_ADMIN_PASSWORD` para la cuenta **`admin@accounts.pimienta.local`** (moderación / cliente XMPP). Por defecto de prueba: `pimienta_prosody_admin`.

Podés exportar las variables antes de `docker compose up` o copiar [proyecto_pimienta/.env.example](proyecto_pimienta/.env.example) a `proyecto_pimienta/.env`.

En cada arranque de FileBrowser se ejecuta un bootstrap que **crea o actualiza** los usuarios **`admin`** e **`invitado`**. Los datos de FileBrowser viven en `data/filebrowser/` (ignorado por git).

**Permisos en el host:** FileBrowser corre como UID **1000**. Si fallan escrituras en `./archivos` o `./data/filebrowser`, probá:  
`sudo chown -R 1000:1000 archivos data/filebrowser` (desde `proyecto_pimienta/`).

**Prosody:** antes del **primer** arranque ejecutá `./ops/init-chat.sh`: genera certificados en `data/prosody-certs/` y ajusta permisos de `data/prosody` (UID **100** del contenedor).

**Chat sin acceso a Internet:** el cliente en `/chat/` usa archivos bajo [`config/converse/vendor/`](proyecto_pimienta/config/converse/vendor/) (Converse 12, libsignal, locale `es`, `emoji.json`, logo). Ese directorio se genera o actualiza **una vez con red** con `./ops/vendor-converse.sh` (variable opcional `CONVERSE_VENDOR_VERSION` para fijar versión npm). Los binarios van versionados en el repo para clonar y operar solo en LAN.

### Operación 100 % LAN (revisión de dependencias)

| Componente | ¿Pide Internet en uso diario? | Notas |
|------------|-------------------------------|--------|
| **Nginx (gateway)** | No | Solo hace proxy a `wiki`, `filebrowser` y `prosody` en la red Docker. La directiva `proxy_pass https://prosody…` apunta al **contenedor** Prosody por TLS interno, no a Internet. |
| **Prosody + MariaDB** | No | Tráfico solo entre contenedores / volúmenes. |
| **FileBrowser** | No | La UI sale de la imagen Docker y de tu `config/`; no hay CDN en este repo. |
| **Chat (`/chat/`)** | No (con `vendor/` en el repo) | Recursos estáticos desde `pimienta.local/chat/vendor/`. Conexión XMPP vía `ws://`/`http://` al mismo host (gateway → Prosody). El JS de Converse incluye *textos* con URLs públicas (p. ej. ayuda OMEMO); no generan peticiones salientes salvo que uses esas funciones contra servidores remotos. |
| **Wiki (MediaWiki)** | En principio no | `InstantCommons` y `pingback` desactivados; [`LocalSettings.php`](proyecto_pimienta/config/mediawiki/LocalSettings.php) fija además `$wgAllowExternalImages = false`. Logo y subidas son locales. **Excepción posible:** el skin (Minerva/Vector) en algunas versiones puede pedir fuentes u otros assets a CDNs; suele degradar el diseño sin romper la wiki. **Contenido:** las páginas pueden tener *enlaces* a la web; el navegador solo los contacta si el usuario hace clic. |
| **Scripts en `ops/`** | Solo cuando los corrés vos | `vendor-converse.sh` y backups/restores con `curl` usan red **al ejecutarlos**, no mientras corre el stack. |
| **Instalación / actualización** | Sí, salvo mirror offline | `docker pull` y regenerar `vendor/` necesitan red (o imágenes `.tar` / repo con `vendor/` ya incluido). |

Para comprobar: apagá Internet, recargá `/`, `/chat/`, `/archivos/` y revisá la pestaña *Red* del navegador; no debería haber solicitudes fallidas a CDNs salvo el caso de fuentes del skin.

### Inicio limpio (todo desde cero)

Wiki vacía + Chat vacío. Útil para arrancar un nodo nuevo sin contenido previo.

```bash
cd proyecto_pimienta

# 0. Configurar pimienta.local (solo la primera vez)
./ops/setup-hosts.sh

# (opcional) contraseñas y puerto del gateway — ver sección anterior
# cp .env.example .env && nano .env

# 1. Certificados y permisos Prosody (solo la primera vez, o si borrás data/prosody-certs)
./ops/init-chat.sh

# 2. Levantar contenedores
docker compose up -d
```

La wiki queda detrás del gateway en `http://pimienta.local/` (o `http://pimienta.local:$GATEWAY_HTTP_PORT`), el chat en `/chat/` (entrada anónima con Converse), FileBrowser en `/archivos/` y, si lo necesitás, seguís pudiendo abrir la wiki en **8080** y FileBrowser en **8081** directamente.

### Inicio con contenido (wiki restaurada + chat limpio)

Levanta la wiki con contenido previo (base de datos, configuración, uploads/imágenes) y el chat arranca vacío.

```bash
cd proyecto_pimienta

# 0. Configurar pimienta.local (solo la primera vez)
./ops/setup-hosts.sh

# 1. Certificados Prosody (primera vez en esta máquina)
./ops/init-chat.sh

# 2. Levantar contenedores
docker compose up -d

# 3. Restaurar contenido de la Wiki
./ops/restore-wiki.sh
```

Por defecto restaura el dump incluido en el repositorio. Si tenés un backup propio generado con `./ops/backup-wiki.sh`, indicalo así:

```bash
./ops/restore-wiki.sh --backup ./backups/wiki/exports/wiki-backup-<fecha>.tar.gz
```

**Atajo (mismo flujo en un comando):** no toca `/etc/hosts`; el paso 0 sigue siendo necesario una vez por máquina.

```bash
cd proyecto_pimienta
./ops/setup-hosts.sh   # solo la primera vez
./ops/bootstrap-with-restore.sh
# o con backup propio:
# ./ops/bootstrap-with-restore.sh --backup ./backups/wiki/exports/wiki-backup-<fecha>.tar.gz
```

### Verificación

| URL (vía gateway) | Servicio |
|-------------------|----------|
| `http://pimienta.local/` (o `:PUERTO`) | MediaWiki |
| `http://pimienta.local/chat` o `.../chat/` | Converse.js (redirige sin barra final) |
| `http://pimienta.local/archivos` o `.../archivos/` | FileBrowser (redirige sin barra final) |

Comprobación automática (usa `pimienta.local` con `curl --resolve` hacia `127.0.0.1`, no exige que `/etc/hosts` esté bien en el momento del test):

```bash
cd proyecto_pimienta
./ops/verify-stack.sh
```

Lee `GATEWAY_HTTP_PORT` y el resto del `.env` si existe. Tras cambiar [config/nginx/default.conf](proyecto_pimienta/config/nginx/default.conf), recargá nginx: `docker compose exec gateway nginx -s reload`.

- **Entrada unificada (gateway):** `http://pimienta.local/` (wiki), `http://pimienta.local/chat/` (Converse), `http://pimienta.local/archivos/` (FileBrowser). Si usás otro puerto: `http://pimienta.local:PUERTO/...`
- **Atajo:** wiki en `http://pimienta.local:8080`, FileBrowser en `http://pimienta.local:8081/archivos/` (el `baseURL` es `/archivos`, no sirve la raíz del puerto 8081 sola)
- **Chat:** al abrir `/chat/` debería conectarse por WebSocket (en las herramientas de red del navegador, `101` en `/xmpp-websocket`). Cuenta admin XMPP: `admin@accounts.pimienta.local` (contraseña `PROSODY_ADMIN_PASSWORD`).

### Problema: página «Welcome to nginx!» al abrir pimienta.local

Ese texto suele ser el **nginx instalado en el sistema operativo** (sitio por defecto en el puerto **80**), no el contenedor **gateway** del proyecto. Ocurre si el stack no publica el 80 en el host, si Docker no está levantado, o si otro proceso ya usa el 80.

1. Verificá que los contenedores estén arriba: `cd proyecto_pimienta && docker compose ps`.
2. Mirá qué escucha el puerto que usás en el navegador (80 u otro): `ss -tlnp | grep ':80 '` (o el puerto de `GATEWAY_HTTP_PORT`).
3. **Opción A:** liberá el 80 (por ejemplo `sudo systemctl stop nginx` y, si no lo usás, `sudo systemctl disable nginx` en el host), poné en `.env` `GATEWAY_HTTP_PORT=80` y `MW_SERVER=http://pimienta.local`, ejecutá `docker compose up -d --force-recreate gateway wiki` o `./ops/up-gateway-port80.sh`.
4. **Opción B:** dejá el nginx del host en el 80 y publicá el gateway en otro puerto; copiá [`.env.example`](proyecto_pimienta/.env.example) a `.env` con `GATEWAY_HTTP_PORT=8088` y `MW_SERVER=http://pimienta.local:8088`, ejecutá `docker compose up -d` y entrá siempre con `http://pimienta.local:8088/`.

Después corré `./ops/verify-stack.sh` para confirmar que la wiki responde por el gateway y no la página genérica de nginx.

**Pendrive / otra ruta:** para servir archivos desde otro directorio del host, cambiá el bind `./archivos:/srv` por la ruta deseada en [proyecto_pimienta/docker-compose.yml](proyecto_pimienta/docker-compose.yml) y reiniciá el servicio `filebrowser`.

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
- Si restaurás con `--backup` y el `.tar.gz` trae `LocalSettings.php`, ese archivo reemplaza el del repo. El `LocalSettings.php` del repo usa `getenv('MW_SERVER')` para alinear la URL canónica con el puerto del gateway; si el backup fija `$wgServer` a otra URL, corregilo o ajustá `.env` y recreá el servicio `wiki` (`docker compose up -d --force-recreate wiki`).
- Para resetear datos del servidor XMPP, borrá `./data/prosody` y `./data/prosody-certs`, volvé a ejecutar `./ops/init-chat.sh` y `docker compose up -d`.
