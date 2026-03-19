# Proyecto Pimienta Rosa

## Modo C (Wiki con contenido + Chat limpio)
Este modo apunta a usuarios nuevos:
- la **Wiki** se levanta con contenido guardado (restore del dump incluido)
- el **Chat (Synapse)** arranca funcional pero **sin restaurar conversaciones** (solo genera config de inicio)

### Pasos
1. Entrar al directorio del stack:
   - `cd proyecto_pimienta`
2. Inicializar configuración de Synapse (genera `./data/synapse/homeserver.yaml`):
   - `./ops/init-synapse.sh`
3. Levantar contenedores:
   - `docker compose up -d`
4. Restaurar contenido de la Wiki:
   - `./ops/restore-wiki.sh`
   - (opcional) restaurar desde un backup `.tar.gz` generado por `./ops/backup-wiki.sh`:
     - `./ops/restore-wiki.sh --backup ./backups/wiki/exports/wiki-backup-<fecha>.tar.gz`
   - (opcional) indicar un dump alternativo (compatibilidad): `./ops/restore-wiki.sh --dump ./backups/wiki/copia_wiki_real.sql`

### Verificación rápida
- Wiki: `http://pimienta.local:8080/index.php/P%C3%A1gina_principal` (debería cargar con páginas existentes)
- Chat: `http://pimienta.local:8008/_matrix/client/versions` (debería devolver `200`)

### Notas
- El restore de la Wiki incluye un preprocesado del SQL (filtra `USE \`my_wiki\`;` y ajusta collations) para compatibilizar con la MariaDB usada en este stack.
- El backup de la Wiki (`./ops/backup-wiki.sh`) genera un `.tar.gz` que incluye `LocalSettings.php` y `images/` (uploads) para conservar estética y contenido.
- Si estás probando en una máquina que ya tenía el chat levantado antes y querés “volver a vacío”, borrá `./data/postgres` y `./data/synapse` antes de ejecutar el modo C.
Entorno autohospedado con Docker que combina una wiki colaborativa (MediaWiki) y un servidor de chat federado (Matrix Synapse). 
Componentes 
1. Wiki Pimienta (MediaWiki) 
Wiki basada en MediaWiki (el mismo software que Wikipedia).
Base de datos MariaDB.
Acceso por puerto 8080 (configurado en LocalSettings.php como http://192.168.0.170:8080). 
2. Chat soberano (Matrix Synapse) 
Servidor de mensajería Matrix Synapse (chat federado, compatible con clientes como Element).
Base de datos PostgreSQL.
Servicio en puerto 8008.
Nombre del servidor: AguaribayPI. 
Estructura del proyecto 
docker-compose.yml: define los servicios (wiki + db, synapse + db_matrix).
LocalSettings.php: configuración de MediaWiki (nombre del sitio “Wiki Pimienta”, BD, logo, etc.).
assets/backups: copias de seguridad (SQL de la wiki, etc.).
Archivos de backup (.tar.gz, .sql): datos de wiki, base de datos y respaldos históricos. 
Resumen 
Wiki colaborativa + servidor de chat Matrix montados con Docker bajo el nombre Pimient.

3. Objetivo: Sensibilizar a la comunidad sobre la importancia de la intranet, su rol en la respuesta ante crisis y el acceso a conocimientos compartidos.
   
Contenido:

Qué es una intranet comunitaria y cómo puede ayudar en momentos de crisis (climática, sanitaria, política).
El valor de una Wikipedia local para almacenar y difundir saberes locales.
Funciones de la radio como herramienta complementaria.
Método: Talleres participativos, charlas comunitarias, uso de ejemplos de otras comunidades que ya han implementado proyectos similares.

Fase: Fundamentos Técnicos

Objetivo: Enseñar los conceptos básicos de redes, servidores y conectividad, de manera accesible.
a. Guías y Manuales

Creación de manuales técnicos adaptados a distintos niveles de conocimiento (principiante, intermedio) para cada fase de la capacitación.

Videos tutoriales que expliquen paso a paso cómo instalar y configurar el servidor y la red de malla.

# Proyecto Pimienta Rosa
