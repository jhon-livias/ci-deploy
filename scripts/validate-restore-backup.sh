#!/usr/bin/env bash
# Valida que un backup se puede restaurar SIN tocar producción (Postgres temporal).
# Uso: ./scripts/validate-restore-backup.sh [directorio_backup]
set -euo pipefail
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="${BACKUP_BASE:-$DEPLOY_DIR/backups}"
BACKUP_DIR="${1:-$(find "$BASE" -mindepth 1 -maxdepth 1 -type d | sort -r | head -1)}"
IMAGE="${POSTGRES_IMAGE:-postgres:17-alpine}"
NAME="ci_restore_validate_$$"
trap 'docker rm -f "$NAME" >/dev/null 2>&1 || true' EXIT
[ -d "$BACKUP_DIR" ] || { echo "No hay backups en $BASE" >&2; exit 1; }
(cd "$BACKUP_DIR" && sha256sum -c SHA256SUMS)
docker run -d --name "$NAME" -e POSTGRES_PASSWORD=validate_only "$IMAGE" >/dev/null
for _ in $(seq 1 30); do docker exec "$NAME" pg_isready -U postgres >/dev/null 2>&1 && break; sleep 1; done
gunzip -c "$BACKUP_DIR/database/postgres.sql.gz" | docker exec -i "$NAME" psql -U postgres -v ON_ERROR_STOP=1 -q >/dev/null
docker exec "$NAME" psql -U postgres -tAc "SELECT count(*) || ' tablas' FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog','information_schema')"
[ ! -f "$BACKUP_DIR/storage/minio.tar.gz" ] || tar -tzf "$BACKUP_DIR/storage/minio.tar.gz" >/dev/null
echo "[validate-restore] Backup válido: $BACKUP_DIR"