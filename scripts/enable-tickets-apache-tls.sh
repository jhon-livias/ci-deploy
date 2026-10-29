#!/usr/bin/env bash
set -Eeuo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/opt/ci/ci-deploy}"
SOURCE="$DEPLOY_DIR/host-apache/tickets.uprit.edu.pe-le-ssl.conf"
TARGET="/etc/apache2/sites-available/tickets.uprit.edu.pe-le-ssl.conf"

[ -r "$SOURCE" ] || { echo "No existe $SOURCE" >&2; exit 1; }
sudo test -r /etc/letsencrypt/live/tickets.uprit.edu.pe/fullchain.pem || { echo 'No existe el certificado de Tickets.' >&2; exit 1; }
sudo install -m 0644 "$SOURCE" "$TARGET"
sudo a2ensite tickets.uprit.edu.pe-le-ssl.conf >/dev/null
sudo apache2ctl configtest
sudo systemctl reload apache2
