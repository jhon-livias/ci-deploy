#!/usr/bin/env bash
set -Eeuo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/opt/ci/ci-deploy}"
SOURCE="$DEPLOY_DIR/host-apache/tickets.uprit.edu.pe.conf"
TARGET="/etc/apache2/sites-available/tickets.uprit.edu.pe.conf"

[ -r "$SOURCE" ] || { echo "No existe $SOURCE" >&2; exit 1; }
sudo install -m 0644 "$SOURCE" "$TARGET"
sudo a2ensite tickets.uprit.edu.pe.conf >/dev/null
sudo apache2ctl configtest
sudo systemctl reload apache2
