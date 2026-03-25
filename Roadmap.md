## Roadmap Proyecto Pimienta Rosa

Este documento describe las funcionalidades planificadas para el nodo Pimienta Rosa: wiki, chat, portal de archivos y modos de despliegue pensados para personas con poco conocimiento técnico.

Las secciones están ordenadas según la prioridad de implementación acordada.

**Documentación técnica del repo:** carpeta [docs/](docs/) (arquitectura, decisiones, operación/troubleshooting, guía para quienes desarrollan).

---

## 0. Nodo funcional hoy — checklist y próximos pasos sugeridos

### 0.1. Checklist: de cero a “usable en LAN” (aprendizajes prácticos)

Orden recomendado para quien despliega:

1. **Clonar** el repo y entrar a `proyecto_pimienta/`.
2. **Copiar** `.env.example` → `.env`; definir contraseñas (`FILEBROWSER_*`, opcional `PROSODY_*`) y, si querés acceso por nombre desde otras máquinas, **`LAN_MDNS=1`**.
3. **Certificados** (una vez): `./ops/init-chat.sh` (genera `data/prosody-certs/`, necesarios para Prosody y para **HTTPS del chat** en el puerto 443).
4. **Primer arranque completo:** `./ops/bootstrap-with-restore.sh` (levanta stack, restaura wiki desde `backups/wiki/copia_wiki_real.sql`, instala servicio Avahi si `LAN_MDNS=1`).
5. **Verificación:** `./ops/verify-stack.sh`.
6. **En el navegador (PC):**  
   - Wiki y archivos: **`http://pimienta.local/`** y **`http://pimienta.local/archivos/`** (ajustar puerto si `GATEWAY_HTTP_PORT` ≠ 80).  
   - Chat: **`https://pimienta.local/chat/`** — aceptar certificado autofirmado; **obligatorio en muchos navegadores/celulares** por Web Crypto (`crypto.subtle`).
7. **Celular (misma Wi‑Fi):** si no resuelve el nombre, comprobar **mDNS** (`pimienta-mdns`) o entrar por **IP**; si el navegador fuerza HTTPS, el **443** del gateway atiende chat/XMPP y redirige el resto a HTTP.
8. **Si la IP del nodo cambia (DHCP):** `sudo systemctl restart pimienta-mdns` o `./ops/setup-lan-mdns.sh --install-service` con el script actualizado (redetección de IP al iniciar el servicio).

### 0.2. Próximos pasos del roadmap (prioridad sugerida)

Con el stack **ya operativo**, el esfuerzo incremental más valioso suele ser:

| Orden | Bloque | Por qué |
|-------|--------|--------|
| 1 | **§5 Mejoras de UX** (redirección chat HTTPS, portada, navegación, favicon, URLs cortas, MUC persistente) | Bajo esfuerzo, alto impacto: reduce frustración inmediata. |
| 2 | **§10 Documentación para personas no técnicas** + pegatinas/QR en el nodo | Reduce soporte y errores de URL/puerto. |
| 3 | **§4.3 Backups automáticos** (cron + retención) | Protege la wiki sin depender de que alguien acuerde ejecutar el script. |
| 4 | **§6 Panel de administración web** (mínimo: estado de contenedores, espacio en disco, “backup ahora”) | Menos terminal para cuidadoras del nodo. |
| 5 | **§7 Modos de despliegue** (AP vs nodo en red existente) + **§8 Instalador** | Reproducibilidad en Raspberry y otras máquinas. |
| 6 | **§9 Asistente web de primer arranque** | Encaja después de tener panel o scripts estables. |

Los detalles de cada bloque siguen en las secciones numeradas más abajo. Para **arquitectura y decisiones ya tomadas**, ver [docs/](docs/).

---

## 1. Portal de archivos compartidos (FileBrowser) — *entregado*

> **Decisión de diseño**: en lugar de desarrollar un portal de archivos propio, se adopta
> [FileBrowser](https://filebrowser.org/) como solución. Es un proyecto open-source, liviano
> (~50 MB RAM), con interfaz web amigable y permisos granulares por usuario. Se despliega como
> un contenedor Docker más dentro del stack existente, evitando esfuerzo de desarrollo y
> mantenimiento a largo plazo.

### 1.1. Carpeta dedicada y fuentes de almacenamiento

- **Objetivo**: ofrecer un espacio sencillo para compartir archivos en la red local, sin exponer archivos del sistema.
- **Implementación con FileBrowser**:
  - Se monta una carpeta del host como volumen `/srv` dentro del contenedor.
  - Ruta configurable según el despliegue:
    - Una carpeta del sistema (por ejemplo `./archivos`).
    - Un pendrive montado (por ejemplo `/media/pendrive1`), cambiando el bind mount en `docker-compose.yml`.
  - Los archivos compartidos **no** se incluyen en los backups del sistema.
- **Tareas** (estado en el repo):
  - Servicio `filebrowser` en `docker-compose.yml` (puerto **8081**).
  - Configuración versionada: `config/filebrowser/settings.json`; base SQLite en `data/filebrowser/` (ignorada por git).
  - Bootstrap en cada arranque: `ops/filebrowser-entrypoint.sh` + `ops/bootstrap-filebrowser-users.sh`.
  - Documentación en `README.md` y ejemplo de variables en `proyecto_pimienta/.env.example`.
  - Para usar un pendrive u otra ruta: cambiar el bind `./archivos:/srv` en `docker-compose.yml`.

### 1.2. Operaciones para personas usuarias

- **Resuelto mediante roles de FileBrowser**:
  - Usuario de acceso limitado (por defecto **`pimienta`** / **`pimienta`**): `FILEBROWSER_INVITADO_USERNAME` y `FILEBROWSER_INVITADO_PASSWORD` (mínimo 8 caracteres en la clave); el bootstrap la aplica en cada arranque. Permisos restringidos:
    - **Permitido**: subir archivos (upload), descargar archivos, crear carpetas.
    - **No permitido**: borrar, renombrar, mover o modificar archivos (sin `modify`/`rename`/`delete`).
  - FileBrowser incluye previsualización nativa de imágenes, video, audio, PDF y texto plano.
- **Alternativa sin login**: se puede arrancar FileBrowser con `--noauth` para acceso totalmente anónimo, pero se pierde la distinción admin/usuario. Evaluar según el contexto de cada nodo.

### 1.3. Límites y gestión de espacio

- **Tamaño máximo por archivo**: no es nativo de FileBrowser, pero se puede limitar mediante el reverse proxy (nginx) o a nivel de filesystem.
- **Espacio total máximo**: se resuelve a nivel de infraestructura (partición dedicada, quota de filesystem, o monitoreo desde el panel de admin de la sección 5).
- **Comportamiento al alcanzar el límite**: el filesystem rechaza la escritura y FileBrowser muestra un error al intentar subir.

### 1.4. Administración del portal de archivos

- **Resuelto con el usuario `admin` de FileBrowser**: contraseña definida por `FILEBROWSER_ADMIN_PASSWORD` (mínimo 8 caracteres); el bootstrap crea o actualiza `admin` en cada arranque con permisos completos.
  - Borrar archivos y carpetas (moderación, limpieza, liberar espacio).
  - Ver uso de espacio desde la propia interfaz.
  - Gestionar usuarios y permisos.
- **Cambio de ruta base de almacenamiento**: se modifica el volumen en `docker-compose.yml` y se reinicia el contenedor.

### 1.5. Interfaz de usuario

- FileBrowser ya provee una **interfaz web minimalista y responsive** que cumple todos los requisitos:
  - Lista de archivos y carpetas (nombre, tamaño, fecha).
  - Botones de subida y descarga.
  - Panel de administración integrado para el usuario admin.
  - Soporte de temas y branding básico (personalizable con el nombre del nodo).

---

## 2. Chat soberano (Prosody + Converse.js)

> **Decisión de diseño**: se reemplaza Matrix Synapse + PostgreSQL por **Prosody** (servidor XMPP) +
> **Converse.js** (cliente web). Motivación: Synapse requiere registro obligatorio, consume ~200 MB+ de RAM
> y necesita PostgreSQL dedicado. Prosody con login anónimo consume ~20 MB, permite que la gente chatee
> sin crear cuenta y se integra directamente en el navegador. El chat es **efímero** (sin historial
> persistente), alineado con los valores de privacidad del proyecto.

### 2.1. Chat (Prosody + Converse.js) — *entregado en el repo*

- **Prosody** (imagen `prosodyim/prosody:13.0`):
  - Dominio anónimo: `pimienta.local`; cuentas con contraseña y registro abierto en LAN: `accounts.pimienta.local` (admin `admin@accounts.pimienta.local`, contraseña `PROSODY_ADMIN_PASSWORD`).
  - MUC: `conference.pimienta.local`; salas sugeridas **general**, **maestranza**, **asamblea** (se crean al unirse; Converse usa `auto_join_rooms`).
  - Sin MAM (sin historial persistente en servidor).
  - WebSocket/BOSH en **HTTP 5280** en la red Docker; **nginx** hace de TLS terminal en **443** para el cliente (`wss://` / BOSH HTTPS) y proxy plano a Prosody (evita problemas de SNI/TLS entre contenedores). Prosody también puede exponer TLS en 5281 para clientes nativos; el chat web del repo usa el gateway.
  - Config: [proyecto_pimienta/config/prosody/prosody.cfg.lua](proyecto_pimienta/config/prosody/prosody.cfg.lua); datos: `data/prosody/`, certificados: `data/prosody-certs/` (generados por [proyecto_pimienta/ops/init-chat.sh](proyecto_pimienta/ops/init-chat.sh)).
- **Converse.js** (estático en el repo, `vendor/`): [proyecto_pimienta/config/converse/index.html](proyecto_pimienta/config/converse/index.html); uso recomendado en **`https://…/chat/`** por Web Crypto en navegadores.
- **Tareas** (estado):
  - Servicios `prosody` y `gateway` (nginx) en [docker-compose.yml](proyecto_pimienta/docker-compose.yml); eliminados Synapse y PostgreSQL del chat.
  - `ops/init-chat.sh` + `ops/prosody-entrypoint.sh` (registro idempotente del admin).
  - Cuenta opcional en `accounts.pimienta.local` vía cliente XMPP (no expuesto aún en la UI de Converse más allá del texto informativo).

---

## 3. Wiki como punto de entrada y reverse proxy

> **Decisión de diseño**: en lugar de crear una landing page separada, la **Página Principal de la wiki**
> actúa como punto de entrada del nodo. Un contenedor **nginx** (`gateway`) en el puerto publicado (por defecto **80**, configurable con `GATEWAY_HTTP_PORT`) actúa como reverse proxy.

### 3.1. Wiki Pimienta (MediaWiki)

- Política de acceso por defecto: **lectura y escritura abiertas** en la LAN (sin login requerido).
- URL canónica vía variable de entorno `MW_SERVER` (por defecto `http://pimienta.local`) en [LocalSettings.php](proyecto_pimienta/config/mediawiki/LocalSettings.php); si el gateway no está en el puerto 80, definí `MW_SERVER` (ej. `http://pimienta.local:8088`).
- Correo saliente desactivado (`$wgEnableEmail = false`).
- Skin mobile-friendly: `MinervaNeue` como skin por defecto.

### 3.2. Gateway y rutas — *entregado (infra + contenido wiki de referencia)*

- **Objetivo**: al abrir `http://pimienta.local/` (o el host y puerto que corresponda) se accede a la wiki; archivos en `/archivos/`; chat en **`https://pimienta.local/chat/`** (recomendado) o HTTP en entornos que no exijan contexto seguro.
- **Reverse proxy**: [proyecto_pimienta/config/nginx/default.conf](proyecto_pimienta/config/nginx/default.conf)
  - **Puerto 80:** `/` → MediaWiki; `/chat/` → Converse; `/archivos/` → FileBrowser (ruta completa `/archivos/` sin strip incorrecto; `baseURL=/archivos`); `/xmpp-websocket` y `/http-bind` → Prosody **:5280** (HTTP interno).
  - **Puerto 443 (TLS):** mismas rutas de **chat y XMPP** que en 80; el resto redirige a HTTP para no forzar certificado en toda la wiki.
- **Atajos de desarrollo**: la wiki sigue expuesta en **8080** y FileBrowser en **8081** en el host (opcional).
- **Wiki (dump `copia_wiki_real.sql`):** portada con enlaces a chat (HTTPS) y archivos; páginas Maestranza/Bitácora/Portal alineadas a MariaDB, `docker compose`, scripts de backup/restore y sin secretos en claro. Mantener coherencia al cambiar URLs o stack.

---

## 4. Backups y restauración del sistema

### 4.1. Backups manuales simples — *entregado*

- **Objetivo**: que cualquier persona pueda hacer una copia del nodo sin conocimientos técnicos avanzados.
- **Alcance del backup**:
  - Base de datos y archivos de MediaWiki.
  - Configuraciones críticas del nodo (modo AP/nodo, hostname, etc.).
  - **No** incluye la carpeta de archivos compartidos (ver sección 1).
  - **No** incluye el chat (es efímero por diseño, no hay datos que respaldar).
- **Tareas**:
  - Script de backup: `./proyecto_pimienta/ops/backup-wiki.sh`
  - Comportamiento esperado del backup:
    - Apaga `wiki` (si está corriendo) para que el snapshot sea consistente.
    - Genera un único `.tar.gz` con fecha/hora en un destino configurable.
    - Incluye:
      - `wiki/sql/dump.sql` (dump SQL de la base `my_wiki`)
      - `wiki/files/LocalSettings.php` (branding/config de la Wiki)
      - `wiki/files/images/` (uploads/imágenes para conservar estética y contenido)
      - `manifest.json` (metadatos del backup)
  - Integrar botón "Hacer backup ahora" en el panel web de administración (opcional, queda para iteraciones futuras).

### 4.2. Restauración sencilla (misma Pi u otra) — *entregado*

- **Objetivo**: poder volver a un estado anterior del nodo o clonar el nodo en otra Raspberry.
- **Comportamiento esperado**:
  - Flujo guiado: seleccionar archivo de backup → confirmar → restaurar → reiniciar la Pi.
- **Tareas**:
  - Script de restauración: `./proyecto_pimienta/ops/restore-wiki.sh`
  - Comportamiento esperado:
    - Acepta `--backup <tar.gz>` (backups creados por `backup-wiki.sh`)
    - Además mantiene compatibilidad con `--dump <ruta.sql>` (dump SQL incluido en el repo).
    - Detiene `wiki`, recrea `my_wiki` en MariaDB y restaura el SQL filtrado/preprocesado para MariaDB 10.5.
    - Restaura `LocalSettings.php` y copia `wiki/files/images/` hacia `./proyecto_pimienta/data/mediawiki/images/` para que los uploads persistan.
    - Vuelve a levantar `wiki` y corre `maintenance/update.php --quick` (caches/esquema).
  - Inicio con contenido (Wiki restaurada + Chat limpio):
    - El usuario ejecuta `./proyecto_pimienta/ops/init-chat.sh` (solo la primera vez) y luego `./proyecto_pimienta/ops/restore-wiki.sh`.
    - El chat arranca vacío automáticamente (efímero, sin datos previos).
  - Documentar el proceso paso a paso para personas no técnicas (ver `README.md`).

### 4.3. Backups automáticos (opcional)

- **Objetivo**: ofrecer la opción de copias periódicas sin intervención manual.
- **Tareas**:
  - Permitir activar/desactivar backups periódicos (por ejemplo, diarios o semanales).
  - Mostrar en la interfaz administrativa la fecha del último backup exitoso.

---

## 5. Mejoras de experiencia de usuario (UX)

> Prioridad alta: reducen fricción inmediata para las personas que usan el nodo. Se implementan **antes** del panel de administración porque mejoran la percepción de producto terminado con bajo esfuerzo de desarrollo.

### 5.1. Redirección automática HTTP → HTTPS en `/chat/` — *entregado*

- **Problema**: si alguien abre `http://pimienta.local/chat/` (sin HTTPS), `crypto.subtle` no existe y el chat se queda cargando sin ningún mensaje de error comprensible.
- **Solución**: en el bloque `server :80` de nginx, `/chat` y `/chat/` redirigen con **301** a `https://$http_host/…` ([`default.conf`](proyecto_pimienta/config/nginx/default.conf)). El bloque **443** sigue sirviendo Converse en `/chat/` y XMPP en `/http-bind` y `/xmpp-websocket`.
- **Verificación**: `./ops/verify-stack.sh` comprueba el redirect HTTP→HTTPS y un **200** en `https://…/chat/` (con `-k` por certificado autofirmado).

### 5.2. Portada de la wiki: bienvenida clara y botones de acceso — *entregado*

- **Problema**: la Página Principal arranca con *"MediaWiki se ha instalado."* (texto por defecto) y los enlaces a chat/archivos están al final. Una persona no técnica no sabe qué hacer. Además, el **logo del encabezado** (skin Minerva) se ve **demasiado grande**, se sale de la franja del header y **solapa el título** y el contenido en móvil y en escritorio.
- **Solución**: rediseñar la portada con enfoque mobile-first:
  - Eliminar el bloque de bienvenida de MediaWiki.
  - Tres **botones o tarjetas grandes**: Wiki · Chat · Archivos, cada uno con icono y descripción de una línea.
  - Credenciales de FileBrowser en una sección aparte ("Ayuda" o "Cómo acceder") para no exponer datos en la primera vista.
  - **Logo en la portada** (cuerpo de la página, no el del menú): imagen `[[Archivo:Logo_Wiki_Pimienta.png|…]]` centrada, importada al wiki con `maintenance/run.php importImages`.
  - **Logo del encabezado**: sin *wordmark* duplicado y CSS en [`LocalSettings.php`](proyecto_pimienta/config/mediawiki/LocalSettings.php) (`BeforePageDisplay`).
- **Entrega en el repo**:
  - Fuente wikitext versionada: [`config/mediawiki/portada-principal.wikitext`](proyecto_pimienta/config/mediawiki/portada-principal.wikitext).
  - Aplicar en una wiki viva: `docker compose exec -T wiki php maintenance/run.php edit -u Admin -s "…" "Página principal" < config/mediawiki/portada-principal.wikitext` (o [`ops/wiki-edit-via-api.sh`](proyecto_pimienta/ops/wiki-edit-via-api.sh)); **no** editar el dump SQL a mano — regenerar con `mysqldump` o [`ops/backup-wiki.sh`](proyecto_pimienta/ops/backup-wiki.sh).
  - Dump de referencia: [`backups/wiki/copia_wiki_real.sql`](proyecto_pimienta/backups/wiki/copia_wiki_real.sql) (incluye la imagen importada y la revisión de portada).

### 5.3. Navegación entre servicios (wiki ↔ chat ↔ archivos)

- **Estado**: enlaces directos en `MediaWiki:Sidebar` a chat/archivos **no** están activos en el dump de referencia; la barra lateral sigue el contenido estándar ([`MediaWiki-Sidebar.wikitext`](proyecto_pimienta/config/mediawiki/MediaWiki-Sidebar.wikitext)). La portada y el portal siguen enlazando a esas herramientas.
- **Problema**: hoy cada servicio es un mundo separado; no hay forma de ir de uno a otro sin saber la URL.
- **Solución**:
  - **Wiki**: agregar enlaces en la barra lateral (`MediaWiki:Sidebar`) a `/chat/` y `/archivos/`.
  - **Chat**: botón flotante o barra superior mínima con links a wiki y archivos (sin romper el modo fullscreen de Converse).
  - **FileBrowser**: evaluar branding con link de "volver a la wiki" (limitado por la UI de FileBrowser, pero posible con CSS/JS inyectado via proxy o header).
- **Tareas**:
  - Editar `MediaWiki:Sidebar` con enlaces.
  - Evaluar un header HTML mínimo antes del `<script>` de Converse (probado anteriormente; verificar que no rompa fullscreen en v12).
  - Documentar alternativa de custom branding en FileBrowser.

### 5.4. Favicon e identidad visual

- **Problema**: el chat no tenía favicon propio → riesgo de mixed content y poca coherencia visual entre servicios.
- **Solución (entregada)**:
  - PNG 48×48 generado desde `config/mediawiki/images/wiki_burbuja_135x135.png` → [`proyecto_pimienta/config/nginx/favicon.png`](proyecto_pimienta/config/nginx/favicon.png) (regenerar con ImageMagick: `convert … -resize 48x48 -strip`).
  - Gateway nginx: `location = /favicon.ico` y `location = /favicon.png` en **80 y 443** (mismo archivo; `default_type image/png` para `/favicon.ico`).
  - Chat: `<link rel="icon" href="/favicon.ico" type="image/png">` en [`config/converse/index.html`](proyecto_pimienta/config/converse/index.html).
  - Wiki: `$wgFavicon = '/favicon.ico'` en `LocalSettings.php`.
  - FileBrowser: `branding.files` → `/branding` (volumen [`config/filebrowser/branding`](proyecto_pimienta/config/filebrowser/branding) con `img/icons/*`), porque la UI enlaza a `/archivos/static/img/icons/…`, no a `/favicon.ico`.
- **Pendiente opcional**: `theme-color` en el `<head>` del chat.

### 5.5. URLs cortas en la wiki (Short URLs)

- **Problema**: MediaWiki muestra `/index.php/Página_principal` en la barra del navegador. Confuso para usuarias y feo para compartir.
- **Solución**: configurar `$wgArticlePath = "/$1"` en `LocalSettings.php` y una regla `try_files` o `rewrite` en nginx que dirija a `index.php`.
- **Tareas**:
  - Agregar `$wgArticlePath` y `$wgUsePathInfo` en `LocalSettings.php`.
  - Ajustar el bloque `location /` de nginx para wiki (verificar que no colisione con `/chat/` y `/archivos/`).
  - Probar links de edición, historial y páginas especiales.

### 5.6. Salas MUC persistentes y pre-creadas

- **Problema**: las salas se destruyen cuando sale el último participante (`muc_room_default_persistent = false`); errores `No identity or name found` al entrar porque la sala aún no existe.
- **Solución**:
  - Cambiar `muc_room_default_persistent = true` en `prosody.cfg.lua`.
  - Crear un script (o paso en `bootstrap-with-restore.sh`) que haga join como admin a las salas sugeridas (general, maestranza, asamblea) para que existan desde el primer arranque con nombre y descripción.
- **Tareas**:
  - Editar `config/prosody/prosody.cfg.lua`.
  - Script `ops/create-muc-rooms.sh` (o bloque en el entrypoint de Prosody) que use `prosodyctl shell` o stanzas XMPP para crear las salas.
  - Verificar que `auto_join_rooms` de Converse ya no genere los errores disco/identity.

### 5.7. Fuente Muli y MIME types

- **Problema**: Firefox rechaza la fuente Muli TTF (`downloadable font: rejected by sanitizer`), degradando la tipografía del chat.
- **Solución**: agregar el MIME type correcto para `.ttf` en la configuración de nginx de `/chat/`.
- **Tareas**:
  - Agregar `types { font/ttf ttf; font/woff woff; font/woff2 woff2; }` en el `location /chat/` de ambos bloques (80 y 443).
  - Alternativa: si la fuente sigue siendo problemática, reemplazar con `system-ui` en un override CSS.

### 5.8. Mejoras de robustez y calidad percibida

- **`$wgShowExceptionDetails = true`** → cambiar a **`false`** en producción (hoy muestra stack traces a cualquier visitante).
- **Fallback offline del chat**: si Prosody se cae, Converse muestra un error críptico. Evaluar un HTML estático de fallback con mensaje amigable ("el chat está reiniciándose, probá en unos segundos") que nginx sirva cuando el upstream no responde (`error_page 502`).
- **Colores y logo** en Converse: CSS override en `index.html` para que el chat se sienta visualmente parte del mismo nodo que la wiki (misma paleta, logo en el control box).

### 5.9. Mejoras de mediano plazo

| Mejora | Impacto |
|--------|---------|
| **Portal unificado / landing page** (HTML estático en `/`, wiki movida a `/wiki/`) | Entrada clara con botones grandes; no confunde con MediaWiki a quien solo quiere chatear. Requiere cambiar `MW_SERVER` y ajustar nginx. |
| **Código QR** impreso o en la wiki con la URL del nodo | Cero tipeo desde el celular; ideal para talleres y pegatinas. |
| **PWA mínima** (`manifest.json` + service worker básico en `/chat/`) | "Instalar" el chat como app en el celular; mejor UX y evita redirecciones HTTPS del navegador. |
| **Healthcheck / status page** (`/status` en nginx) | Para la cuidadora del nodo, sin terminal: muestra si wiki/chat/archivos responden. |

---

## 6. Panel de administración web — *pendiente*

- **Objetivo**: que las operaciones críticas no requieran usar la terminal.
- **Funciones deseables**:
  - Sección "Sistema":
    - Ver estado de servicios (Wiki, Chat Prosody, Portal de archivos).
    - Ver espacio libre aproximado en disco.
  - Sección "Backups":
    - Hacer backup ahora.
    - Ver fecha del último backup.
    - Iniciar flujo de restauración (con advertencias claras).
  - Sección "Red":
    - Mostrar modo actual (AP / Nodo de red).
    - Mostrar IP actual.
  - Sección "Archivos compartidos":
    - Ver y borrar archivos/carpeta.
    - Cambiar ruta base y límites de espacio.

---

## 7. Modos de despliegue de red

### 7.1. Modo Punto de Acceso (AP)

- **Descripción**: la Raspberry Pi crea su propia red WiFi y sirve los servicios del nodo de forma autónoma.
- **Objetivo**: que el nodo funcione en cualquier lugar (plaza, aula, taller) con solo enchufar la Pi.
- **Comportamiento esperado**:
  - La Pi levanta un SSID propio (por ejemplo `PimientaRosa`).
  - La Pi actúa como servidor DHCP para los dispositivos que se conecten.
  - `http://pimienta.local` resuelve siempre hacia el nodo.
- **Tareas**:
  - Script de instalación que configure modo AP (hostapd / NetworkManager + DHCP).
  - Documentar cómo cambiar el nombre de la red si se desea.

### 7.2. Modo Nodo de Red

- **Descripción**: la Raspberry Pi se conecta a una red existente (router de escuela, organización, etc.) y comparte los servicios en esa LAN.
- **Objetivo**: integrarse donde ya existe infraestructura de red WiFi/Ethernet.
- **Comportamiento esperado**:
  - La Pi obtiene IP por DHCP o se configura con IP fija.
  - Se intenta exponer `pimienta.local` mediante mDNS (Avahi).
  - Como fallback, se puede acceder por la IP, indicada en la documentación (pegatina en la Pi, etc.).
- **Tareas**:
  - Definir un mecanismo para elegir el modo (preguntas en el instalador o archivo de configuración).
  - Script que configure hostname, Avahi y, opcionalmente, IP fija.

---

## 8. Instalador para Raspberry Pi

- **Objetivo**: ofrecer dos caminos de instalación, uno pensado para personas más técnicas y otro para usuarias finales, ambos convergiendo en la configuración vía asistente web.

### 8.1. Camino "avanzado": script sobre Raspberry Pi OS

- **Flujo previsto**:
  - La persona graba una imagen oficial de **Raspberry Pi OS** en una SD.
  - Enciende la Raspberry Pi y accede por consola/SSH.
  - Ejecuta un script de instalación de Pimienta (por ejemplo `curl ... | bash`).
- **Tareas del script**:
  - Instalar Docker y Docker Compose.
  - Clonar o copiar el proyecto Pimienta Rosa.
  - Configurar hostname (por ejemplo `pimienta`).
  - Preguntar por el modo de red (AP o Nodo de red) y aplicar la configuración correspondiente.
  - Levantar los servicios con `docker compose`.
  - Dejar habilitado el asistente web de primer arranque en `http://pimienta.local` o en la IP correspondiente.

### 8.2. Camino "súper simple": imagen prearmada para SD

- **Flujo previsto**:
  - La persona descarga una **imagen de Pimienta** (Raspberry Pi OS + nodo ya instalado).
  - La graba en una SD con Raspberry Pi Imager o Balena Etcher.
  - Inserta la SD en la Raspberry y la enciende.
  - Sin usar consola, abre `http://pimienta.local` y completa el asistente web de primer arranque.
- **Cómo generar la imagen (visión inicial)**:
  - Preparar una Raspberry "maestra" con Raspberry Pi OS + script de instalación ejecutado.
  - Probar que Pimienta funciona correctamente.
  - Crear una imagen de esa SD ("golden image") para distribución.
  - A futuro, evaluar herramientas como `pi-gen` para automatizar la generación de imágenes reproducibles.

---

## 9. Asistente web de primer arranque

- **Objetivo**: que la configuración inicial del nodo (modo de red, idioma, etc.) se haga siempre desde una interfaz web mínima, sin necesidad de usar la terminal.
- **Flujo típico**:
  - Paso 1: selección de idioma.
  - Paso 2: elección de modo de red:
    - Modo Punto de Acceso (AP).
    - Modo Nodo de Red (con opciones para usar cable o WiFi existente).
  - Paso 3: configuración básica según el modo elegido (nombre de la red en modo AP, red WiFi a usar en modo nodo, etc.).
  - Paso 4: confirmación y aplicación de cambios, con mensaje final indicando cómo acceder al nodo.
- **Tareas**:
  - Implementar una pequeña aplicación web que:
    - Lea y escriba los archivos de configuración propios de Pimienta.
    - Llame a scripts de sistema para aplicar cambios de red cuando sea necesario.
  - Integrar este asistente para que:
    - Se muestre al primer arranque.
    - Pueda relanzarse desde el panel de administración si se quiere reconfigurar el nodo.

---

## 10. Documentación para personas no técnicas

- **Objetivo**: que el sistema pueda ser instalado, usado y cuidado por personas con muy poco conocimiento técnico.
- **Materiales**:
  - Manual en castellano, con capturas e instrucciones paso a paso:
    - Encender/apagar el nodo.
    - Conectarse al WiFi o a la red existente.
    - Entrar a `http://pimienta.local`.
    - Usar la wiki, el chat y el portal de archivos.
    - Hacer y guardar un backup (SD o pendrive).
    - Restaurar desde un backup.
  - Versión imprimible (PDF) y copia accesible desde la wiki.
