# Decisiones de diseño

Resumen de elecciones que condicionan el código y el despliegue. Detalle histórico adicional en [Roadmap.md](../Roadmap.md).

## Stack y sustituciones

| Decisión | Motivo breve |
|----------|----------------|
| **Landing estática en `/` + MediaWiki en `/wiki/`** | Entrada clara (HTML + `config.json`); la wiki sigue siendo el contenido colaborativo; `$wgScriptPath = "/wiki"` alineado al gateway. |
| **`Alias /wiki` en Apache** (contenedor wiki) | Los PHP viven en la raíz de DocumentRoot; sin alias, `/wiki/load.php` cae en `index.php` y rompe ResourceLoader (CSS/JS). |
| **Synapse + PostgreSQL → Prosody** (chat) | Menor RAM, sin DB dedicada pesada; login **anónimo** posible; chat **sin MAM** (efímero en servidor), alineado a privacidad. |
| **Converse.js** en el navegador | Cliente web estándar XMPP; assets servidos **desde el repo** (`vendor/`) para uso 100 % LAN sin CDN. |
| **FileBrowser** para archivos | Evita desarrollar portal propio; permisos por usuario; UI usable en móvil. |

## Gateway único (nginx)

| Decisión | Motivo |
|----------|--------|
| Un solo **puerto 80** (y 443 donde aplica) hacia el host | Firewall y enlaces simples para usuarias (`http://pimienta.local/...`). |
| **No** exponer Prosody 5222/528x al host por defecto | Menos superficie de ataque; el chat web sale por el mismo host que la wiki. |

## Prosody ↔ nginx (HTTP interno)

| Decisión | Motivo |
|----------|--------|
| Proxy de nginx a Prosody en **5280 HTTP** (no TLS 5281) | El TLS entre nginx y Prosody por nombre/SNI generaba errores (`unrecognized name`) en Docker; el tráfico es **red privada** entre contenedores. |
| `consider_websocket_secure = true` en Prosody | El cliente usa `wss://` terminado en nginx; Prosody ve conexión WebSocket “segura” hacia el modelo lógico XMPP. |

## HTTP vs HTTPS en la LAN

| Decisión | Motivo |
|----------|--------|
| Wiki y FileBrowser principalmente en **HTTP** | Evita pedir certificado en cada visita a la portada y archivos. |
| **Chat en `https://…/chat/`** | Los navegadores solo exponen **`crypto.subtle`** (Web Crypto) en contextos **seguros** (HTTPS o localhost). En `http://pimienta.local` Converse falla al unirse a MUC / presencia. |
| **443** con certificado autofirmado **solo** para `/chat/`, `/http-bind`, `/xmpp-websocket` | Compromiso: TLS donde hace falta; el resto de rutas HTTPS redirigen a HTTP. |
| Mismo certificado que Prosody (`data/prosody-certs/`) | Una sola generación (`init-chat.sh`); operación simple en el nodo. |

## FileBrowser

| Decisión | Motivo |
|----------|--------|
| `baseURL=/archivos` + nginx **sin** reescritura que quite el prefijo | Evita URLs rotas y “loading infinito” cuando el proxy y la DB de FileBrowser no coinciden. |
| Usuario limitado por defecto **`pimienta` / `pimienta`** | Mnemónico; configurable por entorno; bootstrap idempotente en cada arranque. |

## Wiki y backups

| Decisión | Motivo |
|----------|--------|
| Ediciones de contenido preferentemente vía **MediaWiki** (`maintenance/run.php edit` o API con credenciales), no editando SQL a mano | Menos errores y coherencia con el motor. |
| `restore-wiki.sh` filtra dumps y **compatibilidad MariaDB 10.5** | Evita imports rotos (`TIME_ZONE` NULL, collations UCA, etc.). |
| Dumps sin línea `USE my_wiki` | `mysqldump my_wiki` moderno puede omitirla; el restore trata el archivo completo como ya acotado a `my_wiki`. |

## mDNS (Avahi)

| Decisión | Motivo |
|----------|--------|
| Servicio systemd que **vuelve a detectar la IP** al arrancar | DHCP puede cambiar la IP; anunciar una IP vieja deja de funcionar el celular aunque la PC siga bien. |
| Publicar `accounts.*` y `conference.*` además de `pimienta.local` | Clientes XMPP y enlaces consistentes en la LAN. |

## Contenido y red

| Decisión | Motivo |
|----------|--------|
| `$wgAllowExternalImages = false`, sin InstantCommons | Operación **sin** depender de CDNs para renderizar páginas. |
| Email wiki desactivado | Nodo LAN sin SMTP obligatorio. |
