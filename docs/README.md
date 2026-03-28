# Documentación técnica — Pimienta Negra

Material para quienes **despliegan, mantienen o desarrollan** el nodo. El inicio rápido para usuarias sigue en el [README principal](../README.md) del repositorio.

| Documento | Contenido |
|-----------|-----------|
| [Arquitectura](arquitectura.md) | Componentes, puertos, flujos de datos, red Docker vs host. |
| [Decisiones de diseño](decisiones-de-diseno.md) | Por qué Prosody, FileBrowser, gateway único, HTTP/HTTPS, mDNS, etc. |
| [Operación y resolución de problemas](operacion-y-troubleshooting.md) | Checklist de verificación, errores frecuentes (celular, chat, restore SQL). |
| [Guía para quienes desarrollan](contribucion.md) | Estructura del repo, convenciones, scripts `ops/`, backups de wiki. |
| [Tests del stack](../proyecto_pimienta/tests/README.md) | `tests/run-all.sh`: compose, shellcheck opcional, smoke HTTP ampliado. |

El [Roadmap](../Roadmap.md) sigue siendo el lugar de **funcionalidades planificadas** (panel admin, instalador, modo AP, etc.).

El [CHANGELOG](../CHANGELOG.md) en la raíz del repo resume **cambios entregados** por versión o por bloque de trabajo.
