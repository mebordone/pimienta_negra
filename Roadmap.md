## Roadmap Proyecto Pimienta Rosa

Este documento describe las funcionalidades planificadas para el nodo Pimienta Rosa: wiki, chat, portal de archivos y modos de despliegue pensados para personas con poco conocimiento técnico.

Las secciones están ordenadas según la prioridad de implementación acordada.

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
  - Usuario **`invitado`**: contraseña definida por variable de entorno `FILEBROWSER_INVITADO_PASSWORD` (mínimo 8 caracteres); el bootstrap la aplica en cada arranque. Permisos restringidos:
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

> **Decisión de diseño**: el chat del nodo es **XMPP** con **Prosody** y **Converse.js** en el navegador: bajo consumo de RAM, sesión anónima en LAN opcional, integración detrás del mismo gateway, chat **efímero** en servidor (sin MAM / historial persistente), alineado con privacidad comunitaria.

### 2.1. Chat (Prosody + Converse.js) — *entregado en el repo*

- **Prosody** (imagen `prosodyim/prosody:13.0`):
  - Dominio anónimo: `pimienta.local`; cuentas con contraseña y registro abierto en LAN: `accounts.pimienta.local` (admin `admin@accounts.pimienta.local`, contraseña `PROSODY_ADMIN_PASSWORD`).
  - MUC: `conference.pimienta.local`; salas sugeridas **general**, **maestranza**, **asamblea** (se crean al unirse; Converse usa `auto_join_rooms`).
  - Sin MAM (sin historial persistente en servidor).
  - WebSocket/BOSH TLS en el puerto **5281** interno; el gateway nginx termina `ws://`/`http://` hacia el cliente y habla TLS con Prosody.
  - Config: [proyecto_pimienta/config/prosody/prosody.cfg.lua](proyecto_pimienta/config/prosody/prosody.cfg.lua); datos: `data/prosody/`, certificados: `data/prosody-certs/` (generados por [proyecto_pimienta/ops/init-chat.sh](proyecto_pimienta/ops/init-chat.sh)).
- **Converse.js** (estático + assets en `config/converse/vendor/`, sin CDN en operación): [proyecto_pimienta/config/converse/index.html](proyecto_pimienta/config/converse/index.html), servido bajo `/chat/` por nginx. Actualización de vendor con red: `./ops/vendor-converse.sh`.
- **Tareas** (estado):
  - Servicios `prosody` y `gateway` (nginx) en [docker-compose.yml](proyecto_pimienta/docker-compose.yml).
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

### 3.2. Gateway y rutas — *entregado (infra + contenido wiki)*

- **Objetivo**: al abrir `http://pimienta.local/` (o el host y puerto que corresponda) se accede a la wiki; enlaces relativos a `/chat/` y `/archivos/`.
- **Reverse proxy**: [proyecto_pimienta/config/nginx/default.conf](proyecto_pimienta/config/nginx/default.conf)
  - `/` → MediaWiki
  - `/chat/` → Converse.js estático
  - `/archivos/` → FileBrowser (`baseURL` `/archivos`; nginx reenvía la ruta con prefijo al contenedor)
  - `/xmpp-websocket` y `/http-bind` → Prosody:5281 (TLS interno)
- **Atajos de desarrollo**: la wiki sigue expuesta en **8080** y FileBrowser en **8081** en el host (opcional).
- **Contenido de la wiki y dump**: la Página principal enlaza a `http://pimienta.local/chat/` y `http://pimienta.local/archivos/` (ajustable con `MW_SERVER`); el **Portal de la comunidad** (`Wiki_Pimienta:Portal_de_la_comunidad`) ya no enlaza a `localhost:3000` y apunta al chat vía gateway; **Maestranza** y **Bitácora de Maestranza** documentan `docker compose`, MariaDB (`db`), gateway, scripts [proyecto_pimienta/ops/backup-wiki.sh](proyecto_pimienta/ops/backup-wiki.sh) / [restore-wiki.sh](proyecto_pimienta/ops/restore-wiki.sh) y la estructura `archivos/`, `data/`, `config/`, `backups/wiki/`, sin pegar secretos. El estado reflejado en el repo está en [proyecto_pimienta/backups/wiki/copia_wiki_real.sql](proyecto_pimienta/backups/wiki/copia_wiki_real.sql) (regenerado desde la wiki viva).

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

## 5. Panel de administración web

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

## 6. Modos de despliegue de red

### 6.1. Modo Punto de Acceso (AP)

- **Descripción**: la Raspberry Pi crea su propia red WiFi y sirve los servicios del nodo de forma autónoma.
- **Objetivo**: que el nodo funcione en cualquier lugar (plaza, aula, taller) con solo enchufar la Pi.
- **Comportamiento esperado**:
  - La Pi levanta un SSID propio (por ejemplo `PimientaRosa`).
  - La Pi actúa como servidor DHCP para los dispositivos que se conecten.
  - `http://pimienta.local` resuelve siempre hacia el nodo.
- **Tareas**:
  - Script de instalación que configure modo AP (hostapd / NetworkManager + DHCP).
  - Documentar cómo cambiar el nombre de la red si se desea.

### 6.2. Modo Nodo de Red

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

## 7. Instalador para Raspberry Pi

- **Objetivo**: ofrecer dos caminos de instalación, uno pensado para personas más técnicas y otro para usuarias finales, ambos convergiendo en la configuración vía asistente web.

### 7.1. Camino "avanzado": script sobre Raspberry Pi OS

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

### 7.2. Camino "súper simple": imagen prearmada para SD

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

## 8. Asistente web de primer arranque

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

## 9. Documentación para personas no técnicas

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
