# Operación y resolución de problemas

## Verificación rápida

Desde `proyecto_pimienta/`:

```bash
./ops/verify-stack.sh
```

Para una pasada más amplia (compose, shellcheck en `tests/`, favicon e iconos FileBrowser): [`./tests/run-all.sh`](../proyecto_pimienta/tests/run-all.sh) — ver [`tests/README.md`](../proyecto_pimienta/tests/README.md).

Comprueba HTTP vía gateway (landing en `/`, wiki en `/wiki/`, `/archivos/`); **`/chat/` en HTTP** redirige a **HTTPS** y el script valida el **200** en `https://…/chat/`. No valida WebSocket en profundidad.

## Landing (`/`): credenciales de archivos y acceso al chat

- Bajo el botón **Archivos** la portada muestra el texto de acceso invitado a FileBrowser (por defecto **usuario y contraseña `pimienta`**). Los valores salen de [`config/landing/config.json`](../proyecto_pimienta/config/landing/config.json) si definís `guest_username` y `guest_password`; si no, coinciden con los defaults de `FILEBROWSER_INVITADO_*` en compose. Tras cambiar `.env`, recreá **filebrowser** y, si querés que la landing muestre otros textos sin tocar el HTML, ajustá esas claves en `config.json`.
- El botón **Chat** no enlaza directo: abre un **diálogo** (sin librerías externas) que explica el aviso del navegador por **certificado autofirmado** en HTTPS local; al confirmar, redirige a `https://<mismo hostname>/chat/` (puerto HTTPS por defecto del navegador, normalmente **443**). Si mapeás el gateway HTTPS a otro puerto en el host, abrí el chat con la URL completa que corresponda.

## Favicon (wiki, chat, archivos)

El gateway sirve **`/favicon.ico`** y **`/favicon.png`** en **puerto 80 y 443** desde el volumen montado [`config/nginx/favicon.png`](../proyecto_pimienta/config/nginx/favicon.png) (PNG; el navegador lo pide al mismo host que la landing, la wiki o `/archivos/`). Tras recrear el contenedor `gateway`, comprobar con `curl -sI http://pimienta.local/favicon.ico` (o tu host/puerto). Para regenerar el icono desde el logo burbuja: `convert config/mediawiki/images/wiki_burbuja_135x135.png -resize 48x48 -strip config/nginx/favicon.png` (desde `proyecto_pimienta/`).

**FileBrowser** no usa `/favicon.ico`: su HTML apunta a **`/archivos/static/img/icons/…`**. El repo incluye branding en [`config/filebrowser/branding/`](../proyecto_pimienta/config/filebrowser/branding) (`branding.files=/branding` vía bootstrap). El **gateway nginx** intercepta `^~ /archivos/static/img/icons/` y sirve esos archivos desde disco: el binario de FileBrowser solo acepta **GET** en `/static/` (muchas peticiones **HEAD** devolvían 404) y su CSP puede interferir con SVG servidos por el upstream. **`favicon.svg` debe llevar el PNG en base64 embebido** (no `href="/favicon.png"`): Chromium y otros ignoran recursos externos dentro de un favicon SVG. Tras cambiar `config/nginx/favicon.png`, regenerá `favicon.svg` (y el resto de iconos si querés) bajo `config/filebrowser/branding/img/icons/` y recreá **gateway** (y **filebrowser** si tocás la DB/branding).

## No entra desde el celular u otra PC (misma Wi‑Fi)

1. **En el nodo**, desde `proyecto_pimienta/`: **`./ops/diagnose-lan-access.sh`** — muestra IP LAN, si Docker escucha el puerto, HTTP local, firewall y pistas para el celular.
2. **Proba primero por IP**, no por nombre: en el celular abrí **`http://192.168.x.x/`** (la IP que imprime el diagnóstico; si usás otro puerto, **`http://IP:8088/`** según `GATEWAY_HTTP_PORT`).
   - Si **por IP entra** y **`pimienta.local` no** → mDNS o “DNS privado” en Android.
   - Si **por IP no entra** → casi seguro **firewall en el PC del nodo** (`sudo ufw allow 80/tcp` y `443/tcp` si aplica) o el router con **aislamiento de clientes / AP isolation** (impide que dos Wi‑Fi vean el puerto 80 entre sí). Revisá el panel del router (GALATEA u otro).
3. **Las tres en la misma SSID no alcanza** si el AP separa clientes: algunos routers tienen “Wi‑Fi para invitados” o VLAN distinta; todas deben estar en la **misma red L2** sin aislamiento.
4. **Mismo router, dos bandas (2,4 GHz y 5 GHz):** a veces solo una banda tiene **aislamiento de clientes** activo o reglas distintas. Si `pimienta.local` o la IP del nodo **no responden en la red 5G** pero **sí en la 2,4 GHz** (`GALATEAWIFI` vs `GALATEAWIFI5G` u otros nombres), unificá PC y celulares en la banda que funcione o desactivá el aislamiento en el panel del router para la SSID de 5 GHz.

## mDNS (`pimienta.local` desde otras máquinas)

- **`LAN_MDNS=1`** en `.env` y volver a correr **`./ops/bootstrap-with-restore.sh`** (o solo `./ops/setup-lan-mdns.sh --install-service`) instala el servicio **`pimienta-mdns`**. Sin eso, `pimienta.local` suele resolver solo en la PC del nodo.
- El runner del servicio **re-detecta la IPv4 cada 60s** (versiones recientes del script): si el router cambió la IP por DHCP, en hasta ~1 minuto se vuelve a publicar la nueva. Tras **actualizar** el repo, conviene **`sudo systemctl restart pimienta-mdns`** o re-ejecutar **`--install-service`** para escribir el runner nuevo en `/usr/local/lib/`.
- **`avahi-daemon`** debe estar activo: `systemctl is-active avahi-daemon`. Paquetes: `avahi-daemon` y `avahi-utils`.
- Diagnóstico: `./ops/setup-lan-mdns.sh` (sin argumentos) muestra IP detectada y si el servicio está activo.

## Checklist: “¿por qué no entra desde el celular?”

1. **Misma Wi‑Fi** que la máquina del nodo (no datos móviles).  
2. **Resolución de nombre:** `pimienta.local` requiere mDNS en muchos móviles.  
   - En la PC: `systemctl status pimienta-mdns`, `journalctl -u pimienta-mdns -n 30`.  
   - Si la IP del nodo cambió por DHCP: `sudo systemctl restart pimienta-mdns` o `./ops/setup-lan-mdns.sh --install-service` (reinstala runner y reinicia el servicio).  
3. **Probar por IP:** `http://192.168.x.x/` (mismo puerto que el gateway). Si por IP funciona y por nombre no → **mDNS**.  
   - Si **al abrir por IP** la barra cambia a `pimienta.local` y aparece **NXDOMAIN**: la wiki redirigía al host fijo de `MW_SERVER`. Dejá **`MW_SERVER` vacío** en `.env` (o borrá la línea), `docker compose up -d --force-recreate wiki`, y volvé a probar por IP.  
4. **DNS privado (Android):** con “DNS privado” activo, `pimienta.local` a veces no resuelve por mDNS. Probar **Desactivado** o seguir usando **IP** con `MW_SERVER` vacío.  
5. **Router con aislamiento de clientes (AP isolation):** impide tráfico entre dispositivos; desactivar en el AP si es posible.  
6. **Puerto 80 u otro:** si usás `GATEWAY_HTTP_PORT=8088`, la URL es `http://pimienta.local:8088` (o `http://<IP>:8088`). Si definís `MW_SERVER`, debe coincidir con host y puerto; si lo dejás vacío, la wiki sigue el host que escribe el navegador.

## Chat (Converse)

| Síntoma | Causa probable | Qué hacer |
|---------|----------------|-----------|
| Pantalla en blanco / no carga tras el cartel | JS o assets 404 | Revisar que `/chat/vendor/` exista y nginx sirva estáticos. |
| Entra pero al poner apodo se queda cargando | **`crypto.subtle` undefined** | Abrir **`https://pimienta.local/chat/`** (o `https://host:puerto/chat/`), aceptar certificado autofirmado. No usar solo `http://` salvo `localhost`. Desde la **landing**, usá el botón Chat (muestra antes el aviso sobre el certificado). |
| WebSocket cierra enseguida | Proxy o Prosody | Logs: `docker compose logs prosody gateway`; comprobar `wss://` cuando la página es HTTPS. |

Avisos habituales en consola (si el chat **funciona**): mapas de fuente faltantes, notificaciones sin gesto de usuario, carbons no soportados, fuentes TTF rechazadas por el navegador — en general **no bloquean** el uso.

## FileBrowser

- Credenciales por defecto en compose: usuario **`pimienta`**, contraseña **`pimienta`** (sobrescribibles con `FILEBROWSER_INVITADO_*`).  
- Tras cambiar `.env`: `docker compose up -d --force-recreate filebrowser`.  
- Si la UI queda en “loading”: coherencia entre `baseURL`, nginx (sin strip incorrecto) y bootstrap que fija `baseURL` en la DB.

## Wiki: sin estilos (HTML “pelado”) o logo roto en CSS

Si la wiki carga como lista de enlaces sin diseño Minerva/Vector:

- **Causa habitual:** peticiones a **`/wiki/load.php`** no llegan al script real: Apache del contenedor `wiki` reescribe rutas inexistentes a `index.php` (`short-url.conf`). Sin el **`Alias /wiki /var/www/html`** ([`apache-wiki-path.conf`](../proyecto_pimienta/config/mediawiki/apache-wiki-path.conf) montado en compose), `load.php` devuelve HTML de página en lugar de **CSS** (`Content-Type: text/css`).
- **Qué hacer:** comprobar que `docker-compose.yml` monta `config/mediawiki/apache-wiki-path.conf` en el servicio `wiki` y recrear el contenedor: `docker compose up -d --force-recreate wiki`.
- **Comprobación rápida:** `curl -sI 'http://127.0.0.1:8080/wiki/load.php?modules=site.styles&only=styles&skin=minerva'` debe incluir `Content-Type: text/css`.

## Wiki: restore y dumps

- Si aparece *“filtrado por USE my_wiki dejó el SQL vacío”* en versiones viejas del script, actualizar `restore-wiki.sh` desde el repo (lógica para dumps sin `USE`).  
- Restaurar siempre con el dump **`copia_wiki_real.sql`** versionado o con un `.tar.gz` generado por `backup-wiki.sh`.
- **Logo en la portada invisible / imagen rota** (`Archivo:Logo_Wiki_Pimienta.png`): el SQL trae el registro del archivo, pero el PNG vive en `data/mediawiki/images/1/1f/`. Si restauraste solo la base o vaciaste `data/mediawiki/images/`, ejecutá desde `proyecto_pimienta/`: `./ops/ensure-portada-logo.sh` (copia desde `config/mediawiki/images/wiki_burbuja_135x135.png`). Alternativa: `docker compose exec wiki php maintenance/run.php importImages /ruta/con/un/solo/png` como al importar la primera vez.

## HTTPS en el celular

Muchos navegadores **fuerzan HTTPS** en ciertos contextos. El gateway ofrece **443** con redirección a HTTP para rutas que no son de chat; para **chat**, el uso estable es **HTTPS explícito** a `/chat/` como se documenta en el README.

## Firewall (host)

Si desde otro equipo no hay respuesta pero en localhost sí: comprobar `ufw`/iptables y que los puertos publicados en `docker-compose` estén permitidos hacia la LAN.
