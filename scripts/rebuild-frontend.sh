#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

cd "$REPOSITORY_ROOT"

if [[ ! -f .env ]]; then
  echo 'Falta ci-deploy/.env. Cópialo desde .env.example y configura sus valores antes de ejecutar este comando.' >&2
  exit 1
fi

docker compose --env-file .env -f docker-compose.yml up -d --build --no-deps frontend

echo 'Frontend reconstruido. Abre o recarga http://localhost:8080/.'
