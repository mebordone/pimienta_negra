# Proyecto Pimienta Rosa
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
