# Landing estática (`/`)

Sirve la página de entrada del gateway. Los textos y el logo opcional se cargan desde `config.json` vía `fetch('/config.json')`; si falla la red, se muestran los valores por defecto del HTML.

## Logo (`assets/logo.png`)

Copia local del ícono de Wiki Pimienta (mismo archivo que `config/mediawiki/images/wiki_burbuja_135x135.png` y base del favicon del gateway). Se sirve como **`/assets/logo.png`** desde nginx (`config/landing/assets/`), **sin depender de que la wiki esté levantada**. Si cambiás el branding, actualizá la copia, por ejemplo desde `proyecto_pimienta/`:

`cp config/mediawiki/images/wiki_burbuja_135x135.png config/landing/assets/logo.png`

En `config.json`, `node_logo` puede ser una ruta bajo `/assets/…`, una URL absoluta `http(s)://…`, o cadena vacía `""` para ocultar el logo en el hero tras cargar el JSON.

## Compatibilidad de URLs (wiki en `/wiki/`)

Los enlaces antiguos que apuntaban a la wiki en la raíz (por ejemplo `/index.php?title=...`) **no** redirigen automáticamente en esta fase. La wiki vive bajo **`/wiki/`**; conviene actualizar marcadores y enlaces.

Si restauras un backup con un `LocalSettings.php` que tenga `$wgScriptPath = ""`, alinéalo con la versión del repositorio (`$wgScriptPath = "/wiki"`) para que los assets y enlaces de MediaWiki coincidan con el prefijo del proxy.
