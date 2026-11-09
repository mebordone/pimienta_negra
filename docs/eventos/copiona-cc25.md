# Copiona CC25 — checklist de puesto

Evento: Festival Creative Commons 25 años (LibreBase)  
Espacio: Copiona / Burn Station  
Dominio: `copiona.local`  
Wi‑Fi del puesto: `COPIONA-CC2` (notebook por Ethernet al router)

## Antes del día (esta PC o notebook)

1. Branch `event/copiona-cc25` (o el commit de este evento).
2. En `proyecto_pimienta/`:

```bash
cp .env.example .env
```

Editá al menos:

```env
NODE_DOMAIN=copiona.local
LAN_MDNS=1
```

3. Montaje de contenidos del disco Elements:

```bash
cp docker-compose.override.example.yml docker-compose.override.yml
```

Ajustá la ruta del override si el disco monta distinto en la notebook.

4. Si la notebook tenía **otro** `NODE_DOMAIN` con datos ya inicializados: instalación limpia (`./ops/reset.sh`) y después bootstrap. No se soporta cambio de dominio en caliente.

5. Primer arranque:

```bash
./ops/bootstrap-with-restore.sh
# o, si ya hay stack: docker compose up -d
./ops/setup-lan-mdns.sh --install-service   # si LAN_MDNS no lo hizo
./ops/verify-stack.sh
```

6. Confirmá en el navegador:

- `http://copiona.local/`
- `http://copiona.local/archivos/` (carpetas Audios, Libros, etc. + `00-EMPEZA-ACA`)
- `http://copiona.local/wiki/`
- `https://copiona.local/chat/` (aceptar certificado autofirmado)

## Día del evento

1. Encender notebook + fuente.
2. Encender router; SSID `COPIONA-CC2`.
3. Conectar notebook por **Ethernet** al router.
4. Confirmar Docker arriba: `docker compose ps`
5. Confirmar mDNS: `systemctl is-active pimienta-mdns`
6. Anotar IP LAN (`ip -4 addr` o `./ops/diagnose-lan-access.sh`) y escribirla en el cartel.
7. Pegar cartel/QR con el texto de `00-EMPEZA-ACA/CARTEL.txt`.

### Texto canónico del cartel

1. Conectate a `COPIONA-CC2`
2. Abrí `http://copiona.local`
3. Entrá a Archivos y llevate (o subí) lo que quieras
4. Si falla el nombre: `http://<IP>/`

Credenciales FileBrowser (invitado): `pimienta` / `pimienta`

## Cierre

```bash
cd proyecto_pimienta
docker compose down
# opcional: sudo systemctl stop pimienta-mdns
```

Apagar router y notebook.

## Notas

- Landing y assets del evento: `proyecto_pimienta/config/landing/`
- Flyer de referencia: `docs/eventos/cc25/flyers-25cc-general-ig.jpeg`
- `docker-compose.override.yml` no se versiona (está en `.gitignore`); usá el `.example`.
