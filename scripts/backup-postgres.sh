#!/usr/bin/env bash
# Dump lógico de PostgreSQL (gzip). Uso: ./scripts/backup-postgres.sh [directorio_destino]
set -euo pipefail
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:-$DEPLOY_DIR/backups/$(date +%F_%H%M%S)}"
mkdir -p "$DEST/database"
cd "$DEPLOY_DIR"
docker compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner --clean --if-exists' \
  | gzip > "$DEST/database/postgres.sql.gz"
echo "[backup-postgres] $DEST/database/postgres.sql.gz"