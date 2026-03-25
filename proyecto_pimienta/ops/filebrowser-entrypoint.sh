#!/usr/bin/env sh
set -eu

# Bootstrap idempotente antes de arrancar el servidor (misma imagen oficial).
/bin/sh /opt/pimienta/bootstrap-filebrowser-users.sh

exec /bin/tini -- /init.sh "$@"
