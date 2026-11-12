#!/usr/bin/env bash
set -Eeuo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/opt/ci/ci-deploy}"
HTTP_SOURCE="$DEPLOY_DIR/host-apache/planes.uprit.edu.pe.conf"
SSL_SOURCE="$DEPLOY_DIR/host-apache/planes.uprit.edu.pe-le-ssl.conf"
CERT="/etc/letsencrypt/live/planes.uprit.edu.pe/fullchain.pem"

[ -r "$HTTP_SOURCE" ] || { echo "No existe $HTTP_SOURCE" >&2; exit 1; }
sudo install -m 0644 "$HTTP_SOURCE" /etc/apache2/sites-available/planes.uprit.edu.pe.conf
sudo a2ensite planes.uprit.edu.pe.conf >/dev/null
sudo mkdir -p /var/www/letsencrypt/.well-known/acme-challenge
sudo apache2ctl configtest
sudo systemctl reload apache2

if ! sudo test -r "$CERT"; then
  if ! command -v certbot >/dev/null 2>&1; then
    sudo apt-get update -y
    sudo apt-get install -y certbot
  fi
  sudo certbot certonly --webroot -w /var/www/letsencrypt \
    -d planes.uprit.edu.pe \
    --cert-name planes.uprit.edu.pe \
    --email admin@uprit.edu.pe --agree-tos --non-interactive --no-eff-email
fi

if sudo test -r "$CERT" && [ -r "$SSL_SOURCE" ]; then
  sudo install -m 0644 "$SSL_SOURCE" /etc/apache2/sites-available/planes.uprit.edu.pe-le-ssl.conf
  sudo a2ensite planes.uprit.edu.pe-le-ssl.conf >/dev/null
else
  echo "Aún no hay certificado para planes.uprit.edu.pe. El puerto 80 quedó listo para emitirlo." >&2
fi

sudo apache2ctl configtest
sudo systemctl reload apache2
