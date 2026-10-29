#!/usr/bin/env bash
set -Eeuo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/opt/ci/ci-deploy}"
SOURCE="$DEPLOY_DIR/host-nginx/tickets.uprit.edu.pe.conf"
TARGET="/etc/nginx/sites-available/tickets.uprit.edu.pe.conf"

[ -r "$SOURCE" ] || { echo "No existe $SOURCE" >&2; exit 1; }
sudo install -m 0644 "$SOURCE" "$TARGET"
sudo ln -sfn "$TARGET" /etc/nginx/sites-enabled/tickets.uprit.edu.pe.conf
sudo nginx -t
sudo systemctl reload nginx
