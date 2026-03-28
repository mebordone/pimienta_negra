# Guía para quienes desarrollan o mantienen el proyecto

## Estructura relevante

```
pimienta_negra/
├── .gitignore                # Reglas globales (data, .env, archivos/*, venv…)
├── README.md                 # Inicio rápido y uso
├── Roadmap.md                # Funcionalidades planificadas
├── docs/                     # Esta documentación técnica
└── proyecto_pimienta/
    ├── docker-compose.yml
    ├── .env.example
    ├── archivos/             # Árbol compartido FileBrowser (contenido local)
    ├── config/               # nginx, prosody, mediawiki, converse, filebrowser
    │   └── mediawiki/
    │       ├── portada-principal.wikitext  # «Página principal» (maintenance/run.php edit)
    │       └── MediaWiki-Sidebar.wikitext   # Barra lateral por defecto (sin chat/archivos en sidebar)
    ├── data/                 # Persistencia (ignorada; ver .gitignore en la raíz)
    ├── ops/                  # Scripts operativos (bash/sh)
    ├── tests/                # Suite estática + integración HTTP (ver tests/README.md)
    └── backups/wiki/         # Dump SQL de referencia (copia_wiki_real.sql)
```

## Scripts en `ops/` (resumen)

| Script | Uso |
|--------|-----|
| `bootstrap-with-restore.sh` | Primer arranque: certificados, compose, restore wiki, opcional mDNS. |
| `init-chat.sh` | Genera certificados en `data/prosody-certs/`. |
| `restore-wiki.sh` / `backup-wiki.sh` | Restaurar / empaquetar wiki. |
| `verify-stack.sh` | Smoke test HTTP del gateway. |
| `tests/run-all.sh` | Orquestador: `docker compose config`, shellcheck opcional (`tests/`), integración HTTP (incluye `verify-stack`). |
| `setup-lan-mdns.sh` | Avahi persistente o modo efímero. |
| `wiki-edit-via-api.sh` | Editar página vía Action API (requiere contraseña Admin wiki). |
| `ensure-portada-logo.sh` | Copia el logo a `data/.../1/1f/Logo_Wiki_Pimienta.png` si falta (portada). |
| `bootstrap-filebrowser-users.sh` | Invocado por el contenedor FileBrowser; usuarios admin + invitado. |

## Convenciones

- **No commitear** secretos: `proyecto_pimienta/.env`, `proyecto_pimienta/data/`, volúmenes con contraseñas (ver `.gitignore` en la raíz del repo).  
- **Docker Compose v2:** comando `docker compose` (no el binario antiguo `docker-compose` en documentación nueva).  
- **Cambios en la wiki “de fábrica”:** editar la instancia o `maintenance/run.php edit`, luego **regenerar** `backups/wiki/copia_wiki_real.sql` si ese dump es la fuente de verdad del repo.  
- **Commits:** mensajes claros en español o inglés coherente con el historial (tipo *conventional* si el equipo lo usa).

## Converse / vendor

- Assets en `config/converse/vendor/`; actualización opcional con `ops/vendor-converse.sh` (requiere red en ese momento).  
- `index.html`: `jid` para anónimo + `wss`/`ws` según `location.protocol`.

## Nginx

- Un solo archivo principal: `config/nginx/default.conf`.  
- Cualquier cambio de rutas debe alinearse con FileBrowser (`baseURL`) y con Converse (`assets_path`, WebSocket).

## Pruebas manuales mínimas tras un cambio de infra

1. `http://pimienta.local/` (wiki).  
2. `https://pimienta.local/chat/` (chat usable).  
3. `http://pimienta.local/archivos/` (login FileBrowser).  
4. Opcional: `./tests/run-all.sh` o `./ops/verify-stack.sh`.

## Dónde pedir ayuda

Issues o canal acordado por el colectivo que mantenga el fork. Para decisiones de producto amplias, preferir actualizar **Roadmap.md** y enlazar desde aquí si hace falta.
