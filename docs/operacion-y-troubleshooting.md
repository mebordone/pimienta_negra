# Operación y resolución de problemas

## Verificación rápida

Desde `proyecto_pimienta/`:

```bash
./ops/verify-stack.sh
```

Comprueba HTTP vía gateway (wiki, `/archivos/`); **`/chat/` en HTTP** redirige a **HTTPS** y el script valida el **200** en `https://…/chat/`. No valida WebSocket en profundidad.

## Checklist: “¿por qué no entra desde el celular?”

1. **Misma Wi‑Fi** que la máquina del nodo (no datos móviles).  
2. **Resolución de nombre:** `pimienta.local` requiere mDNS en muchos móviles.  
   - En la PC: `systemctl status pimienta-mdns`, `journalctl -u pimienta-mdns -n 30`.  
   - Si la IP del nodo cambió por DHCP: `sudo systemctl restart pimienta-mdns` o reinstalar servicio con `./ops/setup-lan-mdns.sh --install-service`.  
3. **Probar por IP:** `http://192.168.x.x/` (mismo puerto que el gateway). Si por IP funciona y por nombre no → **mDNS**.  
   - Si **al abrir por IP** la barra cambia a `pimienta.local` y aparece **NXDOMAIN**: la wiki redirigía al host fijo de `MW_SERVER`. Dejá **`MW_SERVER` vacío** en `.env` (o borrá la línea), `docker compose up -d --force-recreate wiki`, y volvé a probar por IP.  
4. **DNS privado (Android):** con “DNS privado” activo, `pimienta.local` a veces no resuelve por mDNS. Probar **Desactivado** o seguir usando **IP** con `MW_SERVER` vacío.  
5. **Router con aislamiento de clientes (AP isolation):** impide tráfico entre dispositivos; desactivar en el AP si es posible.  
6. **Puerto 80 u otro:** si usás `GATEWAY_HTTP_PORT=8088`, la URL es `http://pimienta.local:8088` (o `http://<IP>:8088`). Si definís `MW_SERVER`, debe coincidir con host y puerto; si lo dejás vacío, la wiki sigue el host que escribe el navegador.

## Chat (Converse)

| Síntoma | Causa probable | Qué hacer |
|---------|----------------|-----------|
| Pantalla en blanco / no carga tras el cartel | JS o assets 404 | Revisar que `/chat/vendor/` exista y nginx sirva estáticos. |
| Entra pero al poner apodo se queda cargando | **`crypto.subtle` undefined** | Abrir **`https://pimienta.local/chat/`** (o `https://host:puerto/chat/`), aceptar certificado autofirmado. No usar solo `http://` salvo `localhost`. |
| WebSocket cierra enseguida | Proxy o Prosody | Logs: `docker compose logs prosody gateway`; comprobar `wss://` cuando la página es HTTPS. |

Avisos habituales en consola (si el chat **funciona**): mapas de fuente faltantes, notificaciones sin gesto de usuario, carbons no soportados, fuentes TTF rechazadas por el navegador — en general **no bloquean** el uso.

## FileBrowser

- Credenciales por defecto en compose: usuario **`pimienta`**, contraseña **`pimienta`** (sobrescribibles con `FILEBROWSER_INVITADO_*`).  
- Tras cambiar `.env`: `docker compose up -d --force-recreate filebrowser`.  
- Si la UI queda en “loading”: coherencia entre `baseURL`, nginx (sin strip incorrecto) y bootstrap que fija `baseURL` en la DB.

## Wiki: restore y dumps

- Si aparece *“filtrado por USE my_wiki dejó el SQL vacío”* en versiones viejas del script, actualizar `restore-wiki.sh` desde el repo (lógica para dumps sin `USE`).  
- Restaurar siempre con el dump **`copia_wiki_real.sql`** versionado o con un `.tar.gz` generado por `backup-wiki.sh`.

## HTTPS en el celular

Muchos navegadores **fuerzan HTTPS** en ciertos contextos. El gateway ofrece **443** con redirección a HTTP para rutas que no son de chat; para **chat**, el uso estable es **HTTPS explícito** a `/chat/` como se documenta en el README.

## Firewall (host)

Si desde otro equipo no hay respuesta pero en localhost sí: comprobar `ufw`/iptables y que los puertos publicados en `docker-compose` estén permitidos hacia la LAN.
