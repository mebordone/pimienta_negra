## Roadmap Proyecto Pimienta Rosa

Este documento describe las funcionalidades planificadas para el nodo Pimienta Rosa: wiki, chat, portal de archivos y modos de despliegue pensados para personas con poco conocimiento técnico.

---

## 1. Modos de despliegue de red

### 1.1. Modo Punto de Acceso (AP)

- **Descripción**: la Raspberry Pi crea su propia red WiFi y sirve los servicios del nodo de forma autónoma.
- **Objetivo**: que el nodo funcione en cualquier lugar (plaza, aula, taller) con solo enchufar la Pi.
- **Comportamiento esperado**:
  - La Pi levanta un SSID propio (por ejemplo `PimientaRosa`).
  - La Pi actúa como servidor DHCP para los dispositivos que se conecten.
  - `http://pimienta.local` resuelve siempre hacia el nodo.
- **Tareas**:
  - Script de instalación que configure modo AP (hostapd / NetworkManager + DHCP).
  - Documentar cómo cambiar el nombre de la red si se desea.

### 1.2. Modo Nodo de Red

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

## 2. Landing en `http://pimienta.local`

- **Descripción**: página inicial minimalista que aparece al abrir `http://pimienta.local` (sin puerto).
- **Objetivo**: ofrecer una entrada clara y simple a todos los servicios del nodo.
- **Elementos mínimos**:
  - Botón **"Entrar a la Wiki"**.
  - Botón **"Entrar al Chat"**.
  - Botón **"Archivos compartidos"**.
  - Enlaces secundarios: **Estado del nodo**, **Administración** (con contraseña).
  - Texto breve explicando qué es Pimienta Rosa y qué datos se almacenan.
- **Tareas**:
  - Crear servicio web en puerto 80 (Nginx/Caddy u otro) que sirva el landing.
  - Diseñar una interfaz muy simple, legible y en castellano.

---

## 3. Wiki Pimienta y Chat Soberano

(Servicios ya definidos a nivel técnico, pero se integran en el flujo del nodo.)

- **Wiki Pimienta (MediaWiki)**:
  - Ajustar `LocalSettings.php` para que use `http://pimienta.local` (con o sin puerto según el despliegue).
  - Definir política de acceso por defecto: lectura/escritura abierta en la LAN.

- **Chat Soberano (Matrix Synapse)**:
  - Alinear configuración de `server_name` y URLs públicas con el dominio local (`pimienta.local` o similar).
  - Documentar para personas usuarias cómo conectarse desde un cliente (por ejemplo Element).

---

## 4. Backups y restauración del sistema

### 4.1. Backups manuales simples

- **Objetivo**: que cualquier persona pueda hacer una copia del nodo sin conocimientos técnicos avanzados.
- **Alcance del backup**:
  - Base de datos y archivos de MediaWiki.
  - Base de datos y datos necesarios de Synapse.
  - Configuraciones críticas del nodo (modo AP/nodo, hostname, etc.).
  - **No** incluye la carpeta de archivos compartidos (ver sección 5).
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

### 4.2. Restauración sencilla (misma Pi u otra)

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
  - Modo C (Wiki con contenido + Chat limpio):
    - El usuario debe ejecutar `./proyecto_pimienta/ops/init-synapse.sh` y **no** restaurar conversaciones del chat.
  - Documentar el proceso paso a paso para personas no técnicas (ver sección de "Modo C" en `README.md`).

### 4.3. Backups automáticos (opcional)

- **Objetivo**: ofrecer la opción de copias periódicas sin intervención manual.
- **Tareas**:
  - Permitir activar/desactivar backups periódicos (por ejemplo, diarios o semanales).
  - Mostrar en la interfaz administrativa la fecha del último backup exitoso.

---

## 5. Portal de archivos compartidos

> **Decisión de diseño**: en lugar de desarrollar un portal de archivos propio, se adopta
> [FileBrowser](https://filebrowser.org/) como solución. Es un proyecto open-source, liviano
> (~50 MB RAM), con interfaz web amigable y permisos granulares por usuario. Se despliega como
> un contenedor Docker más dentro del stack existente, evitando esfuerzo de desarrollo y
> mantenimiento a largo plazo.

### 5.1. Carpeta dedicada y fuentes de almacenamiento

- **Objetivo**: ofrecer un espacio sencillo para compartir archivos en la red local, sin exponer archivos del sistema.
- **Implementación con FileBrowser**:
  - Se monta una carpeta del host como volumen `/srv` dentro del contenedor.
  - Ruta configurable según el despliegue:
    - Una carpeta del sistema (por ejemplo `./archivos`).
    - Un pendrive montado (por ejemplo `/media/pendrive1`), cambiando el bind mount en `docker-compose.yml`.
  - Los archivos compartidos **no** se incluyen en los backups del sistema.
- **Tareas**:
  - Agregar servicio `filebrowser` al `docker-compose.yml` (puerto 8081).
  - Crear archivo de configuración inicial (`filebrowser/settings.json`).
  - Documentar cómo cambiar la carpeta compartida (SD vs. pendrive).

### 5.2. Operaciones para personas usuarias

- **Resuelto mediante roles de FileBrowser**:
  - Crear un usuario `invitado` (contraseña pública, ej. `invitado`/`invitado`) con permisos restringidos:
    - **Permitido**: subir archivos (upload), descargar archivos, crear carpetas.
    - **No permitido**: borrar, renombrar, mover archivos o carpetas.
  - FileBrowser incluye previsualización nativa de imágenes, video, audio, PDF y texto plano.
- **Alternativa sin login**: se puede arrancar FileBrowser con `--noauth` para acceso totalmente anónimo, pero se pierde la distinción admin/usuario. Evaluar según el contexto de cada nodo.

### 5.3. Límites y gestión de espacio

- **Tamaño máximo por archivo**: no es nativo de FileBrowser, pero se puede limitar mediante un reverse proxy (nginx) o a nivel de filesystem.
- **Espacio total máximo**: se resuelve a nivel de infraestructura (partición dedicada, quota de filesystem, o monitoreo desde el panel de admin de la sección 6).
- **Comportamiento al alcanzar el límite**: el filesystem rechaza la escritura y FileBrowser muestra un error al intentar subir.

### 5.4. Administración del portal de archivos

- **Resuelto con el usuario `admin` de FileBrowser** (credenciales por defecto: `admin`/`admin`, cambiar en el primer ingreso):
  - Borrar archivos y carpetas (moderación, limpieza, liberar espacio).
  - Ver uso de espacio desde la propia interfaz.
  - Gestionar usuarios y permisos.
- **Cambio de ruta base de almacenamiento**: se modifica el volumen en `docker-compose.yml` y se reinicia el contenedor.

### 5.5. Interfaz de usuario

- FileBrowser ya provee una **interfaz web minimalista y responsive** que cumple todos los requisitos:
  - Lista de archivos y carpetas (nombre, tamaño, fecha).
  - Botones de subida y descarga.
  - Panel de administración integrado para el usuario admin.
  - Soporte de temas y branding básico (personalizable con el nombre del nodo).

---

## 6. Panel de administración web

- **Objetivo**: que las operaciones críticas no requieran usar la terminal.
- **Funciones deseables**:
  - Sección "Sistema":
    - Ver estado de servicios (Wiki, Chat, Portal de archivos).
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

## 7. Documentación para personas no técnicas

- **Objetivo**: que el sistema pueda ser instalado, usado y cuidado por personas con muy poco conocimiento técnico.
- **Materiales**:
  - Manual en castellano, con capturas e instrucciones paso a paso:
    - Encender/apagar el nodo.
    - Conectarse al WiFi o a la red existente.
    - Entrar a `http://pimienta.local`.
    - Usar la wiki, el chat y el portal de archivos.
    - Hacer y guardar un backup (SD o pendrive).
    - Restaurar desde un backup.
  - Versión imprimible (PDF) y copia accesible desde la landing.

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
