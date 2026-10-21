#!/usr/bin/env bash
# Emite el certificado Let's Encrypt "ci" y activa la config TLS.
# Uso: CI_DOMAINS="ci.example.com www.ci.example.com" LE_EMAIL=admin@example.com ./scripts/issue-certificate.sh
set -euo pipefail
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${CI_DOMAINS:?lista de dominios separados por espacio}"
: "${LE_EMAIL:?correo para Let\'s Encrypt}"
cd "$DEPLOY_DIR"
COMPOSE=(docker compose -f docker-compose.yml -f docker-compose.edge.yml)
domain_args=(); for d in $CI_DOMAINS; do domain_args+=(-d "$d"); done
PROXY_CONF=default.bootstrap.conf "${COMPOSE[@]}" up -d reverse-proxy
"${COMPOSE[@]}" run --rm --entrypoint certbot certbot certonly --webroot -w /var/www/certbot \
  --cert-name ci --email "$LE_EMAIL" --agree-tos --no-eff-email "${domain_args[@]}"
PROXY_CONF=default.ssl.conf "${COMPOSE[@]}" up -d --force-recreate reverse-proxy certbot
echo "[issue-certificate] HTTPS activo. Define PROXY_CONF=default.ssl.conf y COMPOSE_FILE en .env."