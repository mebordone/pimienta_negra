# Pimienta Negra

Fork de [Proyecto Aguaribay (Pimienta Rosa)](https://github.com/mebordone/pimienta_negra) que extiende el nodo comunitario autohospedado con herramientas de operación, backup y un portal de archivos.

## En 30 segundos

Pimienta Negra es un nodo comunitario para eventos, barrios o espacios educativos que funciona en red local. La idea es que cualquier persona en la LAN pueda abrir `pimienta.local` y usar tres cosas desde un mismo punto:

- **Wiki** para documentar y dejar comentarios.
- **Chat** para anuncios y coordinación en tiempo real.
- **Archivos** para compartir material.

## Que puede hacer una persona al conectarse

- Entrar a la portada de la wiki y ver accesos directos a las herramientas.
- Participar en canales de chat del evento (anuncios, coordinacion, etc.).
- Subir y bajar archivos compartidos desde el portal.
- Usar todo desde celular o notebook en la misma Wi-Fi, sin depender de Internet para el uso diario.

## Que se implemento en este fork

- **Backup y restore de wiki** (base de datos + contenido) para recuperar rapido el nodo.
- **Bootstrap de inicio** para que alguien descargue el repo, ejecute un script y deje todo funcionando casi de una.
- **Migracion de chat liviana**: se reemplazo Synapse/Mattermost + Postgres por Prosody + Converse.
- **Acceso unificado** por rutas en `pimienta.local` (`/`, `/chat`, `/archivos`) en vez de depender de puertos.
- **FileBrowser** con usuarios configurables para compartir archivos en la red local.
- **mDNS persistente** para resolver `pimienta.local` desde otras compus/celulares en la LAN.
- **Portada y UX de wiki** ajustadas para que sea la entrada principal del sistema.
- **Identidad visual unificada** (favicon) entre wiki, chat y archivos.
- **Documentacion tecnica** ampliada (arquitectura, operacion, troubleshooting, roadmap y changelog).

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
- **Portal de archivos compartidos** — [FileBrowser](https://filebrowser.org/) detrás del gateway en `/archivos/` (y opcionalmente directo en el puerto **8081** para depuración). Usuario `admin` y usuario de acceso limitado (por defecto **`pimienta` / `pimienta`**), configurables por variables de entorno.
- **Roadmap** — plan de trabajo (red AP/nodo, panel de admin, instalador, documentación amplia, etc.).
- **Documentación técnica** — carpeta [`docs/`](docs/) (arquitectura, decisiones de diseño, operación/troubleshooting, guía para quienes desarrollan). Resumen de cambios recientes: [`CHANGELOG.md`](CHANGELOG.md).

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
.gitignore                        # Qué no versionar (data, .env, archivos/*, etc.)
docs/                             # Documentación técnica del proyecto (ver docs/README.md)
Roadmap.md
README.md
proyecto_pimienta/
├── docker-compose.yml            # Stack: wiki + prosody + filebrowser + gateway (nginx)
├── .env.example                  # Variables (gateway, wiki, FileBrowser, Prosody)
├── archivos/                     # Carpeta compartida del portal (bind → FileBrowser /srv)
├── config/
│   ├── mediawiki/
│   │   ├── LocalSettings.php     # Configuración de MediaWiki
│   │   ├── portada-principal.wikitext  # Fuente de «Página principal» (aplicar con maintenance/run.php edit)
│   │   ├── MediaWiki-Sidebar.wikitext  # Barra lateral por defecto (sin enlaces §5.3 a chat/archivos)
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
│   ├── setup-lan-mdns.sh         # mDNS (Avahi) para que la LAN resuelva pimienta*.local
│   ├── bootstrap-filebrowser-users.sh
│   └── filebrowser-entrypoint.sh
├── backups/
│   └── wiki/                     # Dump SQL incluido para restauración inicial
└── data/                         # Runtime (ignorado por git): DBs, prosody, certs, filebrowser, imágenes
```

## Inicio rápido (3 pasos)

> Requiere: **Docker + Docker Compose** y **git** instalados.  
> En Debian/Ubuntu: `sudo apt install docker.io docker-compose-plugin avahi-daemon avahi-utils git`

```bash
# 1. Clonar
git clone https://github.com/mebordone/pimienta_negra
cd pimienta_negra/proyecto_pimienta

# 2. Configurar contraseñas y acceso LAN
cp .env.example .env
nano .env          # Editá FILEBROWSER_*_PASSWORD y descomentá LAN_MDNS=1

# 3. Primer arranque (hace todo: certificados, Docker, wiki, mDNS LAN)
./ops/bootstrap-with-restore.sh
```

Con **`LAN_MDNS=1`** en `.env`, el paso 3 instala automáticamente un servicio **systemd persistente** que publica `pimienta.local` en la red via Avahi: funciona desde el arranque del sistema, sin correr nada extra. Desde cualquier celular u otra PC en la misma Wi‑Fi podés abrir directamente `http://pimienta.local/`.

---

## Requisitos previos

### Docker y Docker Compose

```bash
docker --version && docker compose version
```

En Debian/Ubuntu: `sudo apt install docker.io docker-compose-plugin`

### Acceso desde otros dispositivos (LAN_MDNS)

Con `LAN_MDNS=1` en `.env` el bootstrap instala un servicio systemd usando **Avahi** que anuncia `pimienta.local`, `accounts.pimienta.local` y `conference.pimienta.local` en la Wi‑Fi. Requisito: `avahi-daemon` y `avahi-utils` instalados (`sudo apt install avahi-daemon avahi-utils`).

Otras opciones: DNS en el router o solo IP; detalles en `./ops/setup-lan-mdns.sh --help`.

### Variables de entorno

Copiá [proyecto_pimienta/.env.example](proyecto_pimienta/.env.example) a `proyecto_pimienta/.env`:

| Variable | Default | Descripción |
|----------|---------|-------------|
| `GATEWAY_HTTP_PORT` | `80` | Puerto nginx en el host. Si el 80 está ocupado usá otro (ej `8088`) y, si fijás `MW_SERVER`, el mismo puerto ahí. |
| `GATEWAY_HTTPS_PORT` | `443` | Puerto TLS del gateway: solo responde con **301 a HTTP** (cert. autofirmado de `data/prosody-certs/`). Si el 443 del host está ocupado, cambiá ambos. |
| `MW_SERVER` | *(vacío)* | Si está vacío, la wiki usa el mismo host que escribís en el navegador (evita redirigir a `pimienta.local` cuando un celular no resuelve `.local`). Para forzar siempre el nombre: `http://pimienta.local` o con puerto `http://pimienta.local:8088`. |
| `FILEBROWSER_ADMIN_PASSWORD` | valor de prueba | Mínimo 8 caracteres. |
| `FILEBROWSER_INVITADO_USERNAME` | `pimienta` | Usuario de acceso limitado en FileBrowser. |
| `FILEBROWSER_INVITADO_PASSWORD` | `pimienta` | Mínimo 8 caracteres (mismo valor por defecto que el usuario). |
| `PROSODY_ADMIN_PASSWORD` | valor de prueba | Cuenta `admin@accounts.pimienta.local`. |
| `LAN_MDNS` | `0` | Poné `1` para instalar servicio Avahi persistente al final del bootstrap. |

**Permisos FileBrowser:** corre como UID 1000; si fallan escrituras en `archivos/` o `data/filebrowser/` ejecutá `sudo chown -R 1000:1000 archivos data/filebrowser` (desde `proyecto_pimienta/`).

**Chat sin Internet:** los assets de Converse ya están en el repo (`config/converse/vendor/`). Si necesitás actualizar a otra versión: `./ops/vendor-converse.sh` (requiere red solo esa vez).

### Operación 100 % LAN (revisión de dependencias)

| Componente | ¿Pide Internet en uso diario? | Notas |
|------------|-------------------------------|--------|
| **Nginx (gateway)** | No | Proxy HTTP a `wiki`, `filebrowser` y Prosody (HTTP interno). Opcionalmente escucha **443** y redirige a **HTTP** para clientes que fuerzan `https://` en la LAN. |
| **Prosody + MariaDB** | No | Tráfico solo entre contenedores / volúmenes. |
| **FileBrowser** | No | La UI sale de la imagen Docker y de tu `config/`; no hay CDN en este repo. |
| **Chat (`/chat/`)** | No (con `vendor/` en el repo) | Abrí el chat con **`https://pimienta.local/chat/`** (TLS en el puerto 443 del gateway): los navegadores solo exponen `crypto.subtle` en **HTTPS** o en `localhost`, no en `http://pimienta.local`. XMPP: `wss://` y BOSH por HTTPS hacia Prosody detrás del gateway. |
| **Wiki (MediaWiki)** | En principio no | `InstantCommons` y `pingback` desactivados; [`LocalSettings.php`](proyecto_pimienta/config/mediawiki/LocalSettings.php) fija además `$wgAllowExternalImages = false`. Logo y subidas son locales. **Excepción posible:** el skin (Minerva/Vector) en algunas versiones puede pedir fuentes u otros assets a CDNs; suele degradar el diseño sin romper la wiki. **Contenido:** las páginas pueden tener *enlaces* a la web; el navegador solo los contacta si el usuario hace clic. |
| **Scripts en `ops/`** | Solo cuando los corrés vos | `vendor-converse.sh` y backups/restores con `curl` usan red **al ejecutarlos**, no mientras corre el stack. |
| **Instalación / actualización** | Sí, salvo mirror offline | `docker pull` y regenerar `vendor/` necesitan red (o imágenes `.tar` / repo con `vendor/` ya incluido). |

Para comprobar: apagá Internet, recargá `/`, `/chat/`, `/archivos/` y revisá la pestaña *Red* del navegador; no debería haber solicitudes fallidas a CDNs salvo el caso de fuentes del skin.

### Inicio limpio (wiki vacía)

Wiki vacía + Chat vacío. Útil para arrancar un nodo nuevo sin contenido previo.

```bash
cd proyecto_pimienta
cp .env.example .env && nano .env   # contraseñas + LAN_MDNS=1
./ops/init-chat.sh
docker compose up -d
# Acceso LAN persistente (si no usaste bootstrap):
./ops/setup-lan-mdns.sh --install-service
```

### Inicio con contenido (wiki restaurada — recomendado)

```bash
cd proyecto_pimienta
cp .env.example .env && nano .env   # contraseñas + LAN_MDNS=1
./ops/bootstrap-with-restore.sh
# Con backup propio:
# ./ops/bootstrap-with-restore.sh --backup ./backups/wiki/exports/wiki-backup-<fecha>.tar.gz
```

`bootstrap-with-restore.sh` hace todo: certificados, `docker compose up`, espera servicios, restaura wiki e instala el servicio Avahi si `LAN_MDNS=1`.

### Verificación

| URL (vía gateway) | Servicio |
|-------------------|----------|
| `http://pimienta.local/` (o `:PUERTO`) | MediaWiki |
| `https://pimienta.local/chat/` | Converse.js (**HTTPS** por Web Crypto). `http://…/chat/` redirige con **301** a HTTPS en el gateway. |
| `http://pimienta.local/archivos` o `.../archivos/` | FileBrowser (redirige sin barra final) |

Comprobación automática (usa `pimienta.local` con `curl --resolve` hacia `127.0.0.1`, no exige que `/etc/hosts` esté bien en el momento del test):

```bash
cd proyecto_pimienta
./ops/verify-stack.sh
```

Lee `GATEWAY_HTTP_PORT` y el resto del `.env` si existe. Tras cambiar [config/nginx/default.conf](proyecto_pimienta/config/nginx/default.conf), recargá nginx: `docker compose exec gateway nginx -s reload`.

- **Entrada unificada (gateway):** `http://pimienta.local/` (wiki), **`https://pimienta.local/chat/`** (Converse; aceptá el certificado autofirmado una vez), `http://pimienta.local/archivos/` (FileBrowser). Si usás otro puerto, repetilo en HTTP/HTTPS según corresponda.
- **Atajo:** wiki en `http://pimienta.local:8080`, FileBrowser en `http://pimienta.local:8081/archivos/` (el `baseURL` es `/archivos`, no sirve la raíz del puerto 8081 sola)
- **Chat:** al abrir `/chat/` debería conectarse por WebSocket (en las herramientas de red del navegador, `101` en `/xmpp-websocket`). Cuenta admin XMPP: `admin@accounts.pimienta.local` (contraseña `PROSODY_ADMIN_PASSWORD`).

### Problema: página «Welcome to nginx!» al abrir pimienta.local

Ese texto suele ser el **nginx instalado en el sistema operativo** (sitio por defecto en el puerto **80**), no el contenedor **gateway** del proyecto. Ocurre si el stack no publica el 80 en el host, si Docker no está levantado, o si otro proceso ya usa el 80.

1. Verificá que los contenedores estén arriba: `cd proyecto_pimienta && docker compose ps`.
2. Mirá qué escucha el puerto que usás en el navegador (80 u otro): `ss -tlnp | grep ':80 '` (o el puerto de `GATEWAY_HTTP_PORT`).
3. **Opción A:** liberá el 80 (por ejemplo `sudo systemctl stop nginx` y, si no lo usás, `sudo systemctl disable nginx` en el host), poné en `.env` `GATEWAY_HTTP_PORT=80` (podés dejar `MW_SERVER` vacío o fijar `http://pimienta.local`), ejecutá `docker compose up -d --force-recreate gateway wiki` o `./ops/up-gateway-port80.sh`.
4. **Opción B:** dejá el nginx del host en el 80 y publicá el gateway en otro puerto; copiá [`.env.example`](proyecto_pimienta/.env.example) a `.env` con `GATEWAY_HTTP_PORT=8088` y `MW_SERVER=http://pimienta.local:8088` (o vacío y entrás siempre con el mismo host:puerto en la barra), ejecutá `docker compose up -d`.

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
- Si restaurás con `--backup` y el `.tar.gz` trae `LocalSettings.php`, ese archivo reemplaza el del repo. El `LocalSettings.php` del repo usa `MW_SERVER` si está definido, o el host de la petición; si el backup fija `$wgServer` a otra URL, corregilo o ajustá `.env` y recreá el servicio `wiki` (`docker compose up -d --force-recreate wiki`).
- Para resetear datos del servidor XMPP, borrá `./data/prosody` y `./data/prosody-certs`, volvé a ejecutar `./ops/init-chat.sh` y `docker compose up -d`.
