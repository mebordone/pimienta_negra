# Tests del stack Pimienta

Suite ligera para comprobar que el gateway y rutas críticas siguen respondiendo tras cambios en nginx, Compose o scripts.

## Requisitos

- **Integración:** Docker Compose **levantado** (`docker compose up -d`), certificados de chat generados (`./ops/init-chat.sh` la primera vez).
- **Herramientas:** `curl`, `docker` / `docker compose`.
- **Estáticos:** no requieren contenedores en ejecución (solo validan `docker compose config` y, si está instalado, `shellcheck` en scripts bajo `tests/`).

## Cómo ejecutar

Desde `proyecto_pimienta/`:

```bash
# Todo (estáticos + integración)
./tests/run-all.sh

# Solo validación de compose / shellcheck (sin stack arriba)
./tests/run-all.sh --static-only

# Solo HTTP (asume stack arriba; incluye ./ops/verify-stack.sh)
./tests/run-all.sh --integration-only
```

### Espera tras `docker compose up` (CI o scripts)

```bash
./tests/wait-for-gateway.sh
```

Variables opcionales: `PIMIENTA_WAIT_MAX_SEC` (default 180), `PIMIENTA_WAIT_INTERVAL` (default 3).

Lee `GATEWAY_HTTP_PORT` del `.env` igual que `verify-stack.sh`. El script espera **200 en `/wiki/`** (con redirects), no solo en `/`, para no dar por listo el stack si solo responde la landing.

**HTTPS (443):** el bloque TLS del gateway sigue redirigiendo casi todo a HTTP; la landing y la wiki se consumen en **HTTP** en el puerto del gateway (alineado con el stack actual). El chat sigue usando HTTPS explícito en `/chat/`.

## Qué cubre

| Pieza | Descripción |
|-------|-------------|
| `static/compose-config.sh` | `docker compose config` |
| `static/shellcheck.sh` | `shellcheck` sobre `tests/**/*.sh` (si no hay binario, hace skip) |
| `integration/10-verify-stack.sh` | Delega en [`ops/verify-stack.sh`](../ops/verify-stack.sh) |
| `integration/20-favicon.sh` | `HEAD`/`GET` `/favicon.ico` y `/favicon.png` |
| `integration/30-filebrowser-icons.sh` | `HEAD`/`GET` `/archivos/static/img/icons/favicon.svg` |
| `integration/40-landing-config.sh` | `GET` `/config.json` y validación mínima (`node_name`) |

## Qué no cubre

- Resolución **mDNS** real en la LAN (Avahi / `pimienta.local` desde otros equipos).
- Navegadores móviles ni aceptación manual del certificado HTTPS del chat.
- Contenido concreto de la wiki más allá de que `/wiki/` devuelva 200 y patrones del smoke existente.
- Enlaces antiguos a la wiki en la raíz (`/index.php?…`): no hay redirección automática; la wiki vive en `/wiki/` (ver `config/landing/README.md`).

## CI

En GitHub Actions, el workflow `.github/workflows/stack-tests.yml` ejecuta job **static** en cada push/PR y job **e2e** (Compose + wait + integración) en `push` a `main` para limitar minutos de runner.
